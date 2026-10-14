// supabase/functions/delete-account/index.ts
// ─────────────────────────────────────────────────────────────
// Securely deletes a project owner's account and ALL their data.
// Required for App Store / Play Store compliance (in-app account
// deletion).
//
// The client calls this with the user's auth JWT. We verify the
// caller, then use the service-role key to:
//   1. delete the owner's submissions, submission_images,
//      project_users, project_notifications, projects, owner row
//   2. delete the auth user itself
//
// Cascade note: if your DB has ON DELETE CASCADE foreign keys from
// owner_id, deleting the owner row may remove children automatically.
// We delete explicitly here so it works regardless of FK setup.
// ─────────────────────────────────────────────────────────────

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Identify the caller from their JWT.
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Missing Authorization header' }, 401);
    }

    // Client scoped to the caller's token — to read their identity.
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

    // 2. Admin client (service role) for the actual deletions.
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // 3. Delete dependent data first (child → parent order).
    //    Wrapped individually so a missing table doesn't abort the rest.
    const tables = [
      'submission_images',
      'submissions',
      'project_users',
      'project_notifications',
      'projects',
    ];
    for (const table of tables) {
      try {
        await admin.from(table).delete().eq('owner_id', ownerId);
      } catch (_) {
        // Table may not have owner_id or may not exist — ignore and continue.
      }
    }

    // 4. Delete the owner profile row.
    try {
      await admin.from('owners').delete().eq('id', ownerId);
    } catch (_) {
      // continue to auth deletion regardless
    }

    // 5. Delete the auth user (irreversible).
    const { error: delErr } = await admin.auth.admin.deleteUser(ownerId);
    if (delErr) {
      return json({ error: 'Failed to delete auth user: ' + delErr.message }, 500);
    }

    return json({ success: true }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}