// supabase/functions/create-order/index.ts
// ─────────────────────────────────────────────────────────────
// Creates a Razorpay order server-side.
//
// This is the missing half of N1. Without an order, Razorpay never
// issues razorpay_order_id / razorpay_signature, so the payment can
// never be verified. The amount is computed here from a server-side
// price, never trusted from the client.
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
    // ── 1. Authenticate the owner ─────────────────────────────
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

    // ── 2. Validate the requested slot count ──────────────────
    const body = await req.json().catch(() => ({}));
    const slots = Number.parseInt(String(body.extra_projects ?? '1'), 10);

    if (!Number.isInteger(slots) || slots < 1 || slots > MAX_SLOTS) {
      return json({ error: 'Invalid extra_projects value' }, 400);
    }

    const keyId = Deno.env.get('RAZORPAY_KEY_ID');
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET');

    if (!keyId || !keySecret) {
      // Do not leak which variable is missing.
      console.error('Razorpay credentials are not configured');
      return json({ error: 'Server misconfiguration' }, 500);
    }

    // ── 3. Create the order ───────────────────────────────────
    const amount = slots * PRICE_PAISE;

    const response = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Authorization': 'Basic ' + btoa(`${keyId}:${keySecret}`),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount,
        currency: 'INR',
        receipt: `sr_${user.id.slice(0, 8)}_${Date.now()}`,
        notes: {
          owner_id: user.id,
          extra_projects: String(slots),
        },
      }),
    });

    const order = await response.json();

    if (!response.ok || !order?.id) {
      console.error('Razorpay order creation failed:', order);
      return json({ error: 'Could not create payment order' }, 502);
    }

    // ── 4. Return what the client needs to open checkout ──────
    return json({
      order_id: order.id,
      amount: order.amount,
      currency: order.currency,
      key_id: keyId,
      extra_projects: slots,
    }, 200);
  } catch (e) {
    console.error('create-order failed:', e);
    return json({ error: 'Unexpected error' }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
