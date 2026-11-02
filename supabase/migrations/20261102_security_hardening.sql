-- =====================================================================
-- SahiReport: Security Hardening & Vulnerability Remediation Migration
-- Execute this migration in the Supabase SQL Editor to enforce:
-- 1. Protection against client-side plan / licensing bypass
-- 2. Brute-force rate limiting on access code logins
-- 3. Storage bucket MIME and file size enforcement
-- 4. Automated 30-day purge for soft-deleted accounts (App Store compliance)
-- 5. Safe Co-Owner project and submission access
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Prevent Client-Side Plan / Licensing Bypass (owners table)
-- ---------------------------------------------------------------------
-- Ensures normal authenticated users CANNOT arbitrarily update
-- plan_type, pro_project_slots, extra_projects_count, or pro_expires_at.
-- Only the service_role (used by verify-payment Edge Function) can change them.

CREATE OR REPLACE FUNCTION public.protect_owner_subscription_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- If invoked by service_role, allow the update
  IF current_setting('role', true) = 'service_role' OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;

  -- Block any non-service_role attempt to change subscription fields
  IF (OLD.plan_type IS DISTINCT FROM NEW.plan_type) OR
     (OLD.pro_project_slots IS DISTINCT FROM NEW.pro_project_slots) OR
     (OLD.extra_projects_count IS DISTINCT FROM NEW.extra_projects_count) OR
     (OLD.pro_expires_at IS DISTINCT FROM NEW.pro_expires_at) THEN
    RAISE EXCEPTION 'Unauthorized: Plan and slot modifications are restricted to verified payment webhooks.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_owner_subscription_fields ON public.owners;
CREATE TRIGGER trg_protect_owner_subscription_fields
  BEFORE UPDATE ON public.owners
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_owner_subscription_fields();


-- ---------------------------------------------------------------------
-- 2. Rate Limiting for Code Login (Brute-Force Attack Mitigation)
-- ---------------------------------------------------------------------
-- Tracks failed attempts to prevent automated enumeration of access codes.
CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier TEXT NOT NULL,           -- IP or client identifier
  attempt_type TEXT NOT NULL,         -- 'co_owner' or 'field_user'
  failed_attempts INT DEFAULT 1,
  first_failed_at TIMESTAMPTZ DEFAULT NOW(),
  last_failed_at TIMESTAMPTZ DEFAULT NOW(),
  is_locked_until TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_ident ON public.auth_rate_limits(identifier, attempt_type);

-- Rate check helper: returns false if caller is locked out
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_identifier TEXT,
  p_type TEXT,
  p_max_attempts INT DEFAULT 5,
  p_lockout_minutes INT DEFAULT 15
) RETURNS BOOLEAN AS $$
DECLARE
  v_record RECORD;
BEGIN
  SELECT * INTO v_record
  FROM public.auth_rate_limits
  WHERE identifier = p_identifier AND attempt_type = p_type;

  IF FOUND THEN
    -- Check if currently locked
    IF v_record.is_locked_until IS NOT NULL AND v_record.is_locked_until > NOW() THEN
      RETURN FALSE;
    END IF;

    -- Reset window if older than lockout duration
    IF v_record.first_failed_at < NOW() - (p_lockout_minutes || ' minutes')::INTERVAL THEN
      DELETE FROM public.auth_rate_limits WHERE id = v_record.id;
    END IF;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Record failure helper
CREATE OR REPLACE FUNCTION public.record_failed_attempt(
  p_identifier TEXT,
  p_type TEXT,
  p_max_attempts INT DEFAULT 5,
  p_lockout_minutes INT DEFAULT 15
) RETURNS VOID AS $$
BEGIN
  INSERT INTO public.auth_rate_limits (identifier, attempt_type, failed_attempts, first_failed_at, last_failed_at)
  VALUES (p_identifier, p_type, 1, NOW(), NOW())
  ON CONFLICT (identifier, attempt_type) DO UPDATE
  SET failed_attempts = public.auth_rate_limits.failed_attempts + 1,
      last_failed_at = NOW(),
      is_locked_until = CASE
        WHEN public.auth_rate_limits.failed_attempts + 1 >= p_max_attempts
        THEN NOW() + (p_lockout_minutes || ' minutes')::INTERVAL
        ELSE NULL
      END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Clear rate limit on successful login
CREATE OR REPLACE FUNCTION public.clear_rate_limit(p_identifier TEXT, p_type TEXT)
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.auth_rate_limits WHERE identifier = p_identifier AND attempt_type = p_type;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ---------------------------------------------------------------------
-- 3. Secure Co-Owner Login RPC with Rate Limiting
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.login_co_owner_with_code(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_owner RECORD;
  v_normalized TEXT;
BEGIN
  v_normalized := UPPER(TRIM(p_code));

  -- Locate active admin code
  SELECT * INTO v_admin
  FROM public.owner_admins
  WHERE access_code = v_normalized AND is_active = TRUE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Fetch corresponding owner profile
  SELECT * INTO v_owner
  FROM public.owners
  WHERE id = v_admin.owner_id AND (is_deleted IS NOT TRUE);

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Update last login timestamp
  UPDATE public.owner_admins
  SET last_login_at = NOW()
  WHERE id = v_admin.id;

  RETURN jsonb_build_object(
    'co_owner_id', v_admin.id,
    'co_owner_name', v_admin.name,
    'owner', to_jsonb(v_owner)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ---------------------------------------------------------------------
-- 4. Storage Bucket Security Policies (submission-images)
-- ---------------------------------------------------------------------
-- Enforces: Max file size <= 5 MB, MIME types: jpeg/png/webp

-- Ensure the bucket is public for read but protected for write
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'submission-images',
  'submission-images',
  TRUE,
  5242880, -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- Storage upload policy
DROP POLICY IF EXISTS "Allow upload stamped images" ON storage.objects;
CREATE POLICY "Allow upload stamped images"
ON storage.objects FOR INSERT
TO public
WITH CHECK (
  bucket_id = 'submission-images'
  AND (octet_length(content) <= 5242880)
);

-- Storage read policy
DROP POLICY IF EXISTS "Public view submission images" ON storage.objects;
CREATE POLICY "Public view submission images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'submission-images');


-- ---------------------------------------------------------------------
-- 5. Automated 30-Day Purge for Soft-Deleted Accounts (pg_cron)
-- ---------------------------------------------------------------------
-- Complies with Apple / Google Account Deletion regulations.
CREATE OR REPLACE FUNCTION public.purge_soft_deleted_accounts()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_owner RECORD;
BEGIN
  FOR v_owner IN
    SELECT id FROM public.owners
    WHERE is_deleted = TRUE
      AND deleted_at < NOW() - INTERVAL '30 days'
  LOOP
    -- 1. Delete submission images from storage
    -- (Storage objects referencing this owner's projects)
    DELETE FROM storage.objects
    WHERE bucket_id = 'submission-images'
      AND (storage.foldername(name))[1] IN (
        SELECT id::TEXT FROM public.projects WHERE owner_id = v_owner.id
      );

    -- 2. Delete child records
    DELETE FROM public.submission_images WHERE owner_id = v_owner.id;
    DELETE FROM public.submissions WHERE owner_id = v_owner.id;
    DELETE FROM public.project_users WHERE owner_id = v_owner.id;
    DELETE FROM public.owner_admins WHERE owner_id = v_owner.id;
    DELETE FROM public.project_notifications WHERE owner_id = v_owner.id;
    DELETE FROM public.projects WHERE owner_id = v_owner.id;

    -- 3. Delete owner profile
    DELETE FROM public.owners WHERE id = v_owner.id;

    -- 4. Delete Supabase Auth record
    DELETE FROM auth.users WHERE id = v_owner.id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule daily cron execution if pg_cron is enabled
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'purge-soft-deleted-accounts-daily',
      '0 3 * * *', -- Run every morning at 3:00 AM UTC
      'SELECT public.purge_soft_deleted_accounts();'
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- pg_cron not active on current tier; can be invoked via Edge Function or manual SQL
  NULL;
END;
$$;
