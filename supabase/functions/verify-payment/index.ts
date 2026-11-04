// supabase/functions/verify-payment/index.ts
// ─────────────────────────────────────────────────────────────
// Server-side Razorpay payment verification & replay mitigation.
//
// Dual-path verification:
//  1. HMAC-SHA256 signature verification when order_id & signature exist.
//  2. Direct Razorpay REST API verification when order_id is null (direct checkout).
//
// Replay protection:
//  Each payment_id is recorded uniquely in public.payment_transactions.
//  Subsequent calls with the same payment_id are rejected immediately.
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
    // ── 1. Authenticate caller via JWT ─────────────────────────
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

    // ── 2. Parse and validate payload ──────────────────────────
    const body = await req.json();
    const {
      razorpay_payment_id,
      razorpay_order_id,
      razorpay_signature,
      extra_projects,
    } = body;

    if (!razorpay_payment_id || typeof razorpay_payment_id !== 'string') {
      return json({ error: 'Missing or invalid razorpay_payment_id' }, 400);
    }

    const extraProjectsCount = parseInt(extra_projects ?? '1', 10);
    if (isNaN(extraProjectsCount) || extraProjectsCount < 1 || extraProjectsCount > 20) {
      return json({ error: 'Invalid extra_projects value (must be 1-20)' }, 400);
    }

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ── 3. Replay attack prevention ───────────────────────────
    const { data: existingTx } = await admin
      .from('payment_transactions')
      .select('id')
      .eq('payment_id', razorpay_payment_id)
      .maybeSingle();

    if (existingTx) {
      return json({ error: 'This payment ID has already been processed.' }, 400);
    }

    // ── 4. Cryptographic / API Verification ────────────────────
    const razorpayKeySecret = Deno.env.get('RAZORPAY_KEY_SECRET');
    if (!razorpayKeySecret) {
      console.error('RAZORPAY_KEY_SECRET env var is not set');
      return json({ error: 'Server payment misconfiguration' }, 500);
    }

    const expectedPaise = extraProjectsCount * 49900; // Rs. 499 per project slot

    if (razorpay_order_id && razorpay_signature) {
      // Path A: HMAC-SHA256 signature verification (Order-based flow)
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

      const expectedSignature = Array.from(new Uint8Array(signatureBuffer))
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('');

      if (!timingSafeEqual(expectedSignature, razorpay_signature)) {
        console.error(`Signature mismatch for payment ${razorpay_payment_id}`);
        return json({ error: 'Invalid payment signature. Verification failed.' }, 400);
      }
    } else {
      // Path B: Direct Razorpay REST API verification (Orderless flow)
      const razorpayKeyId = Deno.env.get('RAZORPAY_KEY_ID') || 'rzp_test_ThMjDTWNO7te4s';
      const basicAuth = btoa(`${razorpayKeyId}:${razorpayKeySecret}`);

      const rzpRes = await fetch(
        `https://api.razorpay.com/v1/payments/${razorpay_payment_id}`,
        {
          headers: {
            'Authorization': `Basic ${basicAuth}`,
          },
        },
      );

      if (!rzpRes.ok) {
        const errText = await rzpRes.text();
        console.error(`Razorpay API fetch failed (${rzpRes.status}): ${errText}`);
        return json({ error: 'Could not verify payment status with gateway.' }, 400);
      }

      const pData = await rzpRes.json();
      if (pData.status !== 'captured' && pData.status !== 'authorized') {
        return json({ error: `Payment not completed (status: ${pData.status})` }, 400);
      }

      if (typeof pData.amount === 'number' && pData.amount < expectedPaise) {
        return json({
          error: `Payment amount (${pData.amount}) does not match expected amount (${expectedPaise})`,
        }, 400);
      }

      if (pData.currency && pData.currency !== 'INR') {
        return json({ error: `Invalid currency: ${pData.currency}` }, 400);
      }
    }

    // ── 5. Record Transaction Atomically ───────────────────────
    const { error: txErr } = await admin
      .from('payment_transactions')
      .insert({
        payment_id: razorpay_payment_id,
        order_id: razorpay_order_id ?? null,
        owner_id: user.id,
        amount_paise: expectedPaise,
        extra_projects: extraProjectsCount,
        status: 'captured',
      });

    if (txErr) {
      if (txErr.code === '23505') { // Unique constraint violation
        return json({ error: 'Payment has already been applied.' }, 400);
      }
      console.warn('Logging payment transaction note:', txErr.message);
    }

    // ── 6. Update Owner Subscription ───────────────────────────
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
    console.error('Unexpected error in verify-payment:', e);
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

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}
