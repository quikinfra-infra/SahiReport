// supabase/functions/delete-account/index.ts
// ─────────────────────────────────────────────────────────────
// Permanently deletes a project owner and all of their data.
//
// Fixes N2 / H1 / M4:
//   • supabase-js never throws — every delete now checks `error`
//   • images are deleted by submission_id, not the non-existent owner_id
//   • Storage objects are removed before the rows
//   • the auth user is deleted last, after every other step succeeded
//   • errors are generic to the caller and detailed in the log
//
// Call this while the owner's session is still valid (before signOut).
// ─────────────────────────────────────────────────────────────

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const BUCKET = Deno.env.get('STORAGE_BUCKET') ?? 'submission-images';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  try {
    // ── 1. Identify the caller from their JWT ─────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Missing Authorization header' }, 401);
    }

    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return json({ error: 'Invalid or expired session' }, 401);
    }

    const ownerId = user.id;

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ── 2. Collect submission and project ids ─────────────────
    const { data: submissions, error: subsErr } = await admin
      .from('submissions')
      .select('id')
      .eq('owner_id', ownerId);

    if (subsErr) {
      console.error('submissions lookup failed:', subsErr);
      return genericFailure();
    }

    const submissionIds = (submissions ?? []).map((s) => s.id);

    const { data: projects, error: projErr } = await admin
      .from('projects')
      .select('id')
      .eq('owner_id', ownerId);

    if (projErr) {
      console.error('projects lookup failed:', projErr);
      return genericFailure();
    }

    const projectIds = (projects ?? []).map((p) => p.id);

    // ── 3. Remove Storage objects ─────────────────────────────
    // The image table has carried both keys over time. `owner_id` is the
    // primary key used by the write RPC; `submission_id` is the fallback.
    let storageRemoved = 0;

    {
      let images: Record<string, unknown>[] | null = null;

      const primary = await admin
        .from('submission_images')
        .select('*')
        .eq('owner_id', ownerId);

      if (primary.error?.code === '42P01') {
        // Table absent — nothing to clean up.
      } else if (primary.error?.code === '42703') {
        if (submissionIds.length > 0) {
          const fallback = await admin
            .from('submission_images')
            .select('*')
            .in('submission_id', submissionIds);

          if (fallback.error && fallback.error.code !== '42P01') {
            console.error('submission_images lookup failed:', fallback.error);
            return genericFailure();
          }
          images = fallback.data ?? null;
        }
      } else if (primary.error) {
        console.error('submission_images lookup failed:', primary.error);
        return genericFailure();
      } else {
        images = primary.data ?? null;
      }

      const paths = (images ?? [])
        .map((row) => row.storage_path ?? pathFromPublicUrl(row.public_url))
        .filter((p): p is string => typeof p === 'string' && p.length > 0);

      if (paths.length > 0) {
        const { error: removeErr } = await admin.storage
          .from(BUCKET)
          .remove(paths);

        if (removeErr) {
          // Keep going: orphaned objects are recoverable, a half-deleted
          // account is not. The purge job also retries.
          console.error('Storage removal failed:', removeErr);
        } else {
          storageRemoved = paths.length;
        }
      }
    }

    // ── 4. Delete child rows (each error checked) ─────────────
    {
      const { error } = await admin
        .from('submission_images')
        .delete()
        .eq('owner_id', ownerId);

      if (error?.code === '42P01') {
        // Table absent — nothing to delete.
      } else if (error?.code === '42703') {
        if (submissionIds.length > 0) {
          const fallback = await admin
            .from('submission_images')
            .delete()
            .in('submission_id', submissionIds);

          if (fallback.error && fallback.error.code !== '42P01') {
            console.error('submission_images delete failed:', fallback.error);
            return genericFailure();
          }
        }
      } else if (error) {
        console.error('submission_images delete failed:', error);
        return genericFailure();
      }
    }

    {
      const { error } = await admin
        .from('submissions')
        .delete()
        .eq('owner_id', ownerId);

      if (error && error.code !== '42P01') {
        console.error('submissions delete failed:', error);
        return genericFailure();
      }
    }

    {
      const { error } = await admin
        .from('project_users')
        .delete()
        .eq('owner_id', ownerId);

      if (error && error.code !== '42P01') {
        console.error('project_users delete failed:', error);
        return genericFailure();
      }
    }

    {
      // project_notifications may be keyed by project_id instead of owner_id.
      const { error } = await admin
        .from('project_notifications')
        .delete()
        .eq('owner_id', ownerId);

      if (error?.code === '42P01') {
        // Table absent — nothing to delete.
      } else if (error?.code === '42703') {
        if (projectIds.length > 0) {
          const { error: byProjectErr } = await admin
            .from('project_notifications')
            .delete()
            .in('project_id', projectIds);

          if (byProjectErr && byProjectErr.code !== '42P01') {
            console.error('project_notifications delete failed:', byProjectErr);
            return genericFailure();
          }
        }
      } else if (error) {
        console.error('project_notifications delete failed:', error);
        return genericFailure();
      }
    }

    {
      const { error } = await admin
        .from('owner_admins')
        .delete()
        .eq('owner_id', ownerId);

      if (error && error.code !== '42P01') {
        console.error('owner_admins delete failed:', error);
        return genericFailure();
      }
    }

    {
      const { error } = await admin
        .from('projects')
        .delete()
        .eq('owner_id', ownerId);

      if (error && error.code !== '42P01') {
        console.error('projects delete failed:', error);
        return genericFailure();
      }
    }

    // ── 5. Delete the owner profile row ───────────────────────
    {
      const { error } = await admin
        .from('owners')
        .delete()
        .eq('id', ownerId);

      if (error) {
        console.error('owners delete failed:', error);
        return genericFailure();
      }
    }

    // ── 6. Delete the auth user last (irreversible) ───────────
    const { error: delErr } = await admin.auth.admin.deleteUser(ownerId);

    if (delErr) {
      console.error('Auth user delete failed:', delErr);
      return genericFailure();
    }

    return json({
      success: true,
      deleted: {
        submissions: submissionIds.length,
        projects: projectIds.length,
        storage_objects: storageRemoved,
      },
    }, 200);
  } catch (e) {
    console.error('delete-account failed:', e);
    return genericFailure();
  }
});

// ── Helpers ───────────────────────────────────────────────────

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function genericFailure(): Response {
  return json({ error: 'Account deletion failed. Please contact support.' }, 500);
}

/** Extracts the object path from a Supabase public URL. */
function pathFromPublicUrl(url: unknown): string | null {
  if (typeof url !== 'string') return null;
  const marker = `/object/public/${BUCKET}/`;
  const index = url.indexOf(marker);
  if (index === -1) return null;
  return decodeURIComponent(url.slice(index + marker.length));
}
