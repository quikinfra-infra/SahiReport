// supabase/functions/verify-payment/index.ts
// ─────────────────────────────────────────────────────────────
// Server-side Razorpay payment verification.
//
// Fixes N1 properly:
//   • the slot count comes from the server-created order, never the client
//   • the order and payment are fetched from Razorpay and checked for
//     amount, currency and owner
//   • a replay of the same payment id is a no-op
//
// Env: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, PRO_PRICE_PAISE (optional)
// ─────────────────────────────────────────────────────────────

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const PRICE_PAISE = parseInt(Deno.env.get('PRO_PRICE_PAISE') ?? '49900', 10);
const MAX_SLOTS = 20;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  try {
    // ── 1. Authenticate the calling owner ─────────────────────
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

    // ── 2. Parse the request ──────────────────────────────────
    const body = await req.json().catch(() => ({}));
    const {
      razorpay_payment_id,
      razorpay_order_id,
      razorpay_signature,
    } = body;

    if (!razorpay_payment_id || !razorpay_order_id || !razorpay_signature) {
      return json({ error: 'Missing required payment fields' }, 400);
    }

    const keyId = Deno.env.get('RAZORPAY_KEY_ID');
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET');

    if (!keyId || !keySecret) {
      console.error('Razorpay credentials are not configured');
      return json({ error: 'Server misconfiguration' }, 500);
    }

    const basicAuth = 'Basic ' + btoa(`${keyId}:${keySecret}`);

    // ── 3. Verify the HMAC signature ──────────────────────────
    const expectedSignature = await hmacSha256Hex(
      keySecret,
      `${razorpay_order_id}|${razorpay_payment_id}`,
    );

    if (!timingSafeEqual(expectedSignature, String(razorpay_signature))) {
      console.error(`Signature mismatch for payment ${razorpay_payment_id}`);
      return json({ error: 'Payment verification failed' }, 400);
    }

    // ── 4. Fetch the order and payment from Razorpay ──────────
    const [orderRes, paymentRes] = await Promise.all([
      fetch(`https://api.razorpay.com/v1/orders/${razorpay_order_id}`, {
        headers: { 'Authorization': basicAuth },
      }),
      fetch(`https://api.razorpay.com/v1/payments/${razorpay_payment_id}`, {
        headers: { 'Authorization': basicAuth },
      }),
    ]);

    if (!orderRes.ok || !paymentRes.ok) {
      console.error('Could not fetch Razorpay order/payment');
      return json({ error: 'Payment verification failed' }, 502);
    }

    const order = await orderRes.json();
    const payment = await paymentRes.json();

    // ── 5. Bind the payment to this owner and this price ──────
    const slots = Number.parseInt(String(order?.notes?.extra_projects ?? ''), 10);

    if (!Number.isInteger(slots) || slots < 1 || slots > MAX_SLOTS) {
      console.error(`Order ${razorpay_order_id} has an invalid slot note`);
      return json({ error: 'Payment verification failed' }, 400);
    }

    const expectedAmount = slots * PRICE_PAISE;

    const orderOk =
      order?.id === razorpay_order_id &&
      order?.currency === 'INR' &&
      order?.amount === expectedAmount &&
      order?.notes?.owner_id === user.id;

    const paymentOk =
      payment?.order_id === razorpay_order_id &&
      payment?.currency === 'INR' &&
      payment?.amount === expectedAmount &&
      (payment?.status === 'captured' || payment?.status === 'authorized');

    if (!orderOk || !paymentOk) {
      console.error('Order/payment mismatch', {
        orderOk,
        paymentOk,
        orderAmount: order?.amount,
        paymentAmount: payment?.amount,
        paymentStatus: payment?.status,
      });
      return json({ error: 'Payment verification failed' }, 400);
    }

    // An 'authorized' payment has not moved money yet. Capture it before
    // granting entitlement, otherwise slots could be issued for funds that
    // are only held. Capture is idempotent in Razorpay.
    let paymentStatus: string = payment.status;

    if (paymentStatus === 'authorized') {
      const captureRes = await fetch(
        `https://api.razorpay.com/v1/payments/${razorpay_payment_id}/capture`,
        {
          method: 'POST',
          headers: {
            'Authorization': basicAuth,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            amount: expectedAmount,
            currency: 'INR',
          }),
        },
      );

      const captured = await captureRes.json().catch(() => null);
      paymentStatus = captured?.status ?? 'unknown';

      if (!captureRes.ok || paymentStatus !== 'captured') {
        console.error('Payment capture failed:', captured);
        return json({ error: 'Payment could not be captured' }, 402);
      }
    }

    if (paymentStatus !== 'captured') {
      console.error(`Payment ${razorpay_payment_id} is '${paymentStatus}', not captured`);
      return json({ error: 'Payment verification failed' }, 400);
    }

    // ── 6. Idempotent entitlement update ──────────────────────
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: currentRow, error: fetchErr } = await admin
      .from('owners')
      .select('pro_project_slots, pro_expires_at, last_payment_id')
      .eq('id', user.id)
      .single();

    if (fetchErr || !currentRow) {
      console.error('Owner lookup failed:', fetchErr);
      return json({ error: 'Owner record not found' }, 404);
    }

    // Replay protection: a retried callback must not add slots twice.
    if (currentRow.last_payment_id === razorpay_payment_id) {
      return json({
        success: true,
        updatedSlots: currentRow.pro_project_slots ?? 0,
        replay: true,
      }, 200);
    }

    const existingSlots = (currentRow.pro_project_slots as number) ?? 0;
    const expiresStr = currentRow.pro_expires_at as string | null;
    const isStillValid = expiresStr != null && new Date(expiresStr) > new Date();

    const updatedSlots = (isStillValid ? existingSlots : 0) + slots;
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
        error: 'Payment received but activation failed. Contact support.',
      }, 500);
    }

    return json({ success: true, updatedSlots }, 200);
  } catch (e) {
    console.error('verify-payment failed:', e);
    return json({ error: 'Unexpected error' }, 500);
  }
});

// ── Helpers ───────────────────────────────────────────────────

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function hmacSha256Hex(secret: string, payload: string): Promise<string> {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const buffer = await crypto.subtle.sign(
    'HMAC',
    cryptoKey,
    encoder.encode(payload),
  );
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}
