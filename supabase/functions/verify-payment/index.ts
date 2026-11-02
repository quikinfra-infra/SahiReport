// supabase/functions/verify-payment/index.ts
// ─────────────────────────────────────────────────────────────
// Server-side Razorpay payment verification.
//
// Called by the Flutter client AFTER Razorpay fires onSuccess.
// It verifies the HMAC-SHA256 signature using the secret key
// (never shipped in the app), then updates the owner's plan.
//
// Flow:
//  1. Flutter receives paymentId + orderId + signature from Razorpay
//  2. Flutter calls this Edge Function with those three values + ownerId
//  3. This function re-generates the expected HMAC and compares it
//  4. Only on a valid signature does it update owners.plan_type
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
    // ── 1. Authenticate the calling owner via their JWT ────────
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

    // ── 2. Parse and validate request body ────────────────────
    const body = await req.json();
    const { razorpay_payment_id, razorpay_order_id, razorpay_signature, extra_projects } = body;

    if (!razorpay_payment_id || !razorpay_order_id || !razorpay_signature) {
      return json({ error: 'Missing required payment fields' }, 400);
    }

    const extraProjectsCount = parseInt(extra_projects ?? '1', 10);
    if (isNaN(extraProjectsCount) || extraProjectsCount < 1 || extraProjectsCount > 20) {
      return json({ error: 'Invalid extra_projects value' }, 400);
    }

    // ── 3. Verify Razorpay HMAC-SHA256 signature ──────────────
    const razorpayKeySecret = Deno.env.get('RAZORPAY_KEY_SECRET');
    if (!razorpayKeySecret) {
      console.error('RAZORPAY_KEY_SECRET env var is not set');
      return json({ error: 'Server misconfiguration' }, 500);
    }

    // Razorpay signature = HMAC-SHA256(orderId + "|" + paymentId, secret)
    const signaturePayload = `${razorpay_order_id}|${razorpay_payment_id}`;
    const encoder = new TextEncoder();

    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      encoder.encode(razorpayKeySecret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    );

    const signatureBuffer = await crypto.subtle.sign(
      'HMAC',
      cryptoKey,
      encoder.encode(signaturePayload),
    );

    // Convert the buffer to a lowercase hex string
    const expectedSignature = Array.from(new Uint8Array(signatureBuffer))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');

    // Constant-time comparison to prevent timing attacks
    if (!timingSafeEqual(expectedSignature, razorpay_signature)) {
      console.error(`Signature mismatch for payment ${razorpay_payment_id}`);
      return json({ error: 'Invalid payment signature. Possible fraud attempt.' }, 400);
    }

    // ── 4. Update owner plan using service-role key ────────────
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Ensure the owner record belongs to the authenticated user
    const { data: currentRow, error: fetchErr } = await admin
      .from('owners')
      .select('pro_project_slots, pro_expires_at')
      .eq('id', user.id)
      .single();

    if (fetchErr || !currentRow) {
      return json({ error: 'Owner record not found' }, 404);
    }

    const existingSlots = (currentRow.pro_project_slots as number) ?? 0;
    const expiresStr = currentRow.pro_expires_at as string | null;
    const isStillValid =
      expiresStr != null && new Date(expiresStr) > new Date();

    const updatedSlots = (isStillValid ? existingSlots : 0) + extraProjectsCount;
    const newExpiry = new Date(
      Date.now() + 365 * 24 * 60 * 60 * 1000,
    ).toISOString();

    const { error: updateErr } = await admin
      .from('owners')
      .update({
        plan_type: 'pro',
        pro_project_slots: updatedSlots,
        extra_projects_count: updatedSlots,
        pro_expires_at: newExpiry,
        // Store payment id for audit trail
        last_payment_id: razorpay_payment_id,
        last_payment_at: new Date().toISOString(),
      })
      .eq('id', user.id);

    if (updateErr) {
      console.error('Plan update failed:', updateErr);
      return json({
        error: 'Payment verified but plan update failed. Contact support with payment ID: ' +
          razorpay_payment_id,
      }, 500);
    }

    return json({ success: true, updatedSlots }, 200);
  } catch (e) {
    console.error('Unexpected error:', e);
    return json({ error: String(e) }, 500);
  }
});

// ── Helpers ───────────────────────────────────────────────────

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/**
 * Constant-time string comparison to prevent timing-attack leakage.
 * Both strings are compared character-by-character without early exit.
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}
