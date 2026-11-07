-- =====================================================================
-- SahiReport: Critical security remediation (2026-11-07)
--
-- Repairs the two defects in 20261102_security_hardening.sql that made
-- the previous hardening ineffective:
--
--   C1  The subscription-protection trigger returned early for every
--       caller, because it tested current_user = 'postgres' inside a
--       SECURITY DEFINER function (current_user is the function owner,
--       not the caller). Net effect: the trigger never blocked anything.
--
--   C5  The rate-limit helpers were created but never called, and
--       record_failed_attempt used ON CONFLICT against a non-unique
--       index. Co-owner codes had no expiry.
--
-- This file is idempotent and safe to run after 20261102 (or on its own).
-- Run it in the Supabase SQL Editor, staging first.
-- =====================================================================

-- ---------------------------------------------------------------------
-- C1: block client-side writes to billing columns
-- ---------------------------------------------------------------------

-- Audit trail + idempotency keys used by verify-payment.
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS last_payment_id TEXT;
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS last_payment_at TIMESTAMPTZ;

-- Defensive: the protection trigger and verify-payment both read these.
-- They were introduced in 20261102, but that file may have aborted partway.
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS plan_type TEXT;
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS pro_project_slots INT;
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS extra_projects_count INT;
ALTER TABLE public.owners ADD COLUMN IF NOT EXISTS pro_expires_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.protect_owner_subscription_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT := current_setting('role', true);
BEGIN
  -- Administrative contexts: migrations, the SQL editor, service_role.
  -- PostgREST sets the `role` GUC per request via SET LOCAL ROLE, so this
  -- reflects the real caller even inside a SECURITY DEFINER function.
  IF v_role IS NULL OR v_role IN ('none', 'postgres', 'supabase_admin', 'service_role') THEN
    RETURN NEW;
  END IF;

  IF (OLD.plan_type            IS DISTINCT FROM NEW.plan_type) OR
     (OLD.pro_project_slots    IS DISTINCT FROM NEW.pro_project_slots) OR
     (OLD.extra_projects_count IS DISTINCT FROM NEW.extra_projects_count) OR
     (OLD.pro_expires_at       IS DISTINCT FROM NEW.pro_expires_at) THEN
    RAISE EXCEPTION
      'Unauthorized: plan and slot changes are restricted to verified payments'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_owner_subscription_fields ON public.owners;
CREATE TRIGGER trg_protect_owner_subscription_fields
  BEFORE UPDATE ON public.owners
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_owner_subscription_fields();


-- ---------------------------------------------------------------------
-- C5: rate limiting that is actually wired into the login RPC
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier      TEXT NOT NULL,
  attempt_type    TEXT NOT NULL,
  failed_attempts INT DEFAULT 1,
  first_failed_at TIMESTAMPTZ DEFAULT NOW(),
  last_failed_at  TIMESTAMPTZ DEFAULT NOW(),
  is_locked_until TIMESTAMPTZ
);

-- Remove any duplicates before enforcing uniqueness.
DELETE FROM public.auth_rate_limits a
USING public.auth_rate_limits b
WHERE a.ctid < b.ctid
  AND a.identifier = b.identifier
  AND a.attempt_type = b.attempt_type;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'auth_rate_limits_identifier_attempt_type_key'
  ) THEN
    ALTER TABLE public.auth_rate_limits
      ADD CONSTRAINT auth_rate_limits_identifier_attempt_type_key
      UNIQUE (identifier, attempt_type);
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_rate_limits_ident
  ON public.auth_rate_limits(identifier, attempt_type);

CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_identifier TEXT,
  p_type TEXT,
  p_max_attempts INT DEFAULT 5,
  p_lockout_minutes INT DEFAULT 15
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_record RECORD;
BEGIN
  SELECT * INTO v_record
  FROM public.auth_rate_limits
  WHERE identifier = p_identifier AND attempt_type = p_type;

  IF FOUND THEN
    IF v_record.is_locked_until IS NOT NULL AND v_record.is_locked_until > NOW() THEN
      RETURN FALSE;
    END IF;

    IF v_record.first_failed_at < NOW() - (p_lockout_minutes || ' minutes')::INTERVAL THEN
      DELETE FROM public.auth_rate_limits WHERE id = v_record.id;
    END IF;
  END IF;

  RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_failed_attempt(
  p_identifier TEXT,
  p_type TEXT,
  p_max_attempts INT DEFAULT 5,
  p_lockout_minutes INT DEFAULT 15
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.auth_rate_limits
    (identifier, attempt_type, failed_attempts, first_failed_at, last_failed_at)
  VALUES
    (p_identifier, p_type, 1, NOW(), NOW())
  ON CONFLICT (identifier, attempt_type) DO UPDATE
  SET failed_attempts = public.auth_rate_limits.failed_attempts + 1,
      last_failed_at  = NOW(),
      is_locked_until = CASE
        WHEN public.auth_rate_limits.failed_attempts + 1 >= p_max_attempts
        THEN NOW() + (p_lockout_minutes || ' minutes')::INTERVAL
        ELSE NULL
      END;
END;
$$;

CREATE OR REPLACE FUNCTION public.clear_rate_limit(
  p_identifier TEXT,
  p_type TEXT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.auth_rate_limits
  WHERE identifier = p_identifier AND attempt_type = p_type;
END;
$$;

-- Expiry for co-owner codes. Existing active codes get a 180-day window;
-- NULL means "no expiry" so nothing breaks if this migration is deferred.
ALTER TABLE public.owner_admins
  ADD COLUMN IF NOT EXISTS access_code_expires_at TIMESTAMPTZ;

UPDATE public.owner_admins
SET access_code_expires_at = NOW() + INTERVAL '180 days'
WHERE access_code_expires_at IS NULL
  AND is_active = TRUE;

-- ---------------------------------------------------------------------
-- C5: co-owner login with rate limiting + expiry
-- Return shape is unchanged: {co_owner_id, co_owner_name, owner}
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.login_co_owner_with_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin      RECORD;
  v_owner      RECORD;
  v_normalized TEXT;
  v_identifier TEXT;
  v_role       TEXT := current_setting('role', true);
BEGIN
  v_normalized := UPPER(TRIM(p_code));

  -- Best-effort client identifier; falls back to a shared bucket.
  BEGIN
    v_identifier := COALESCE(
      NULLIF(
        (current_setting('request.headers', true)::jsonb ->> 'x-forwarded-for'),
        ''
      ),
      NULLIF(
        (current_setting('request.headers', true)::jsonb ->> 'cf-connecting-ip'),
        ''
      ),
      NULLIF(
        (current_setting('request.headers', true)::jsonb ->> 'x-real-ip'),
        ''
      ),
      'unknown'
    );
    -- x-forwarded-for may be a list; keep only the first hop.
    v_identifier := TRIM(split_part(v_identifier, ',', 1));
    IF v_identifier = '' THEN
      v_identifier := 'unknown';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_identifier := 'unknown';
  END;

  -- Apply to every non-administrative caller, including authenticated ones.
  IF v_role IS NOT NULL
     AND v_role NOT IN ('none', 'postgres', 'supabase_admin', 'service_role') THEN
    IF NOT public.check_rate_limit(v_identifier, 'co_owner') THEN
      RAISE EXCEPTION 'Too many attempts. Please try again later.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  SELECT * INTO v_admin
  FROM public.owner_admins
  WHERE access_code = v_normalized
    AND is_active = TRUE
    AND (access_code_expires_at IS NULL OR access_code_expires_at > NOW());

  IF NOT FOUND THEN
    IF v_role IS NOT NULL
       AND v_role NOT IN ('none', 'postgres', 'supabase_admin', 'service_role') THEN
      PERFORM public.record_failed_attempt(v_identifier, 'co_owner');
    END IF;
    RETURN NULL;
  END IF;

  SELECT * INTO v_owner
  FROM public.owners
  WHERE id = v_admin.owner_id
    AND (is_deleted IS NOT TRUE);

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  PERFORM public.clear_rate_limit(v_identifier, 'co_owner');

  UPDATE public.owner_admins
  SET last_login_at = NOW()
  WHERE id = v_admin.id;

  RETURN jsonb_build_object(
    'co_owner_id',   v_admin.id,
    'co_owner_name', v_admin.name,
    'owner',         to_jsonb(v_owner)
  );
END;
$$;

-- Lock the new column and functions down to the intended callers.
REVOKE ALL ON FUNCTION public.check_rate_limit(TEXT, TEXT, INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_failed_attempt(TEXT, TEXT, INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.clear_rate_limit(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.login_co_owner_with_code(TEXT) TO anon, authenticated;
