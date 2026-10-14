// supabase/functions/send-notification/index.ts
// ─────────────────────────────────────────────────────────────
// Called after every form submission
// Sends FCM push notification to project owner
// ─────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { submission_id, project_id, project_user_id } = await req.json();

    // Init Supabase with service role
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Get submission details
    const { data: submission } = await supabase
      .from("submissions")
      .select("*, project_users(name), projects(name, owner_id)")
      .eq("id", submission_id)
      .single();

    if (!submission) {
      return new Response(JSON.stringify({ error: "Submission not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const ownerId      = submission.projects.owner_id;
    const projectName  = submission.projects.name;
    const userName     = submission.project_users.name;
    const siteName     = submission.site_name || "No site name";

    // 2. Check if project is muted by owner
    const { data: muteSetting } = await supabase
      .from("project_notifications")
      .select("is_muted")
      .eq("owner_id", ownerId)
      .eq("project_id", project_id)
      .single();

    if (muteSetting?.is_muted) {
      return new Response(
        JSON.stringify({ message: "Notifications muted for this project" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Get owner's FCM token
    const { data: owner } = await supabase
      .from("owners")
      .select("fcm_token, full_name")
      .eq("id", ownerId)
      .single();

    if (!owner?.fcm_token) {
      return new Response(
        JSON.stringify({ message: "Owner has no FCM token" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Get FCM access token using service account
    const fcmToken = await getFCMAccessToken();

    // 5. Get Firebase project ID from service account
    const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
    const projectId = serviceAccount.project_id;

    // 6. Send FCM notification
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${fcmToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: owner.fcm_token,
            notification: {
              title: "New report submitted",
              body:  `${userName} · ${projectName}`,
            },
            data: {
              submission_id: submission_id,
              project_id:    project_id,
              site_name:     siteName,
              route:         `/owner/project/${project_id}`,
            },
            android: {
              priority: "high",
              notification: {
                sound:        "default",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                channel_id:   "sahi_report_submissions",
              },
            },
          },
        }),
      }
    );

    const fcmResult = await fcmResponse.json();

    if (!fcmResponse.ok) {
      console.error("FCM error:", fcmResult);
      return new Response(JSON.stringify({ error: fcmResult }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ success: true, result: fcmResult }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ── Get FCM access token from service account ─────────────────
async function getFCMAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);

  const now     = Math.floor(Date.now() / 1000);
  const payload = {
    iss:   serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud:   "https://oauth2.googleapis.com/token",
    iat:   now,
    exp:   now + 3600,
  };

  // Create JWT
  const header  = { alg: "RS256", typ: "JWT" };
  const encoder = new TextEncoder();

  const headerB64  = btoa(JSON.stringify(header))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  const payloadB64 = btoa(JSON.stringify(payload))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const signingInput = `${headerB64}.${payloadB64}`;

  // Import private key
  const privateKey = serviceAccount.private_key;
  const pemContents = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(signingInput)
  );

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const jwt = `${signingInput}.${signatureB64}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}