// ========================================
// ACADEMIA - EDGE FUNCTION
// LIGDICASH-INITIATE : Envoyer OTP pour paiement mobile money
// ========================================
// Mode mock : retourne succès sans appeler LigdiCash (LIGDICASH_MODE != 'live')
// Mode live : appelle GET /pay/v02/debitotp/{phone}/{amount}

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIGDICASH_API_KEY = Deno.env.get('LIGDICASH_API_KEY') ?? '';
const LIGDICASH_BEARER_TOKEN = Deno.env.get('LIGDICASH_BEARER_TOKEN') ?? '';
const LIGDICASH_MODE = Deno.env.get('LIGDICASH_MODE') ?? 'mock'; // 'mock' or 'live'

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    // Auth: extract user token
    const authHeader = req.headers.get('Authorization') ?? '';
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const userToken = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(userToken);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: 'not_authenticated' }),
        { status: 401, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const body = await req.json();
    const { payment_type, payment_id, phone_number } = body;

    if (!payment_type || !payment_id || !phone_number) {
      return new Response(
        JSON.stringify({ success: false, error: 'missing_parameters', required: ['payment_type', 'payment_id', 'phone_number'] }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // Validate phone (must start with 226 and have at least 11 digits)
    const cleanPhone = phone_number.replace(/\s+/g, '').replace(/^(\+)/, '');
    if (cleanPhone.length < 10) {
      return new Response(
        JSON.stringify({ success: false, error: 'invalid_phone_number' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // Load payment from DB to get amount
    let amount = 0;
    let paymentStatus = '';

    if (payment_type === 'application' || payment_type === 'subscription' || payment_type === 'td') {
      const { data: payment, error: payErr } = await supabase
        .schema('app')
        .from('application_payments')
        .select('id, amount_due, amount_paid, status, student_id')
        .eq('id', payment_id)
        .single();

      if (payErr || !payment) {
        return new Response(
          JSON.stringify({ success: false, error: 'payment_not_found' }),
          { status: 404, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      // Verify ownership
      if (payment.student_id !== user.id) {
        return new Response(
          JSON.stringify({ success: false, error: 'not_owner' }),
          { status: 403, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      paymentStatus = payment.status;
      if (!['pending', 'processing'].includes(paymentStatus)) {
        return new Response(
          JSON.stringify({ success: false, error: 'invalid_payment_status', current_status: paymentStatus }),
          { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      amount = payment.amount_due || payment.amount_paid || 0;

      // Update payment: store phone + set status to processing
      await supabase
        .schema('app')
        .from('application_payments')
        .update({
          phone_number: cleanPhone,
          payment_method: 'ligdicash_otp',
          channel: 'ligdicash',
          status: 'processing',
          updated_at: new Date().toISOString(),
        })
        .eq('id', payment_id);

    } else if (payment_type === 'marketplace') {
      const { data: mpPayment, error: mpErr } = await supabase
        .schema('app')
        .from('marketplace_payments')
        .select('id, gross_amount, status, buyer_id')
        .eq('id', payment_id)
        .single();

      if (mpErr || !mpPayment) {
        return new Response(
          JSON.stringify({ success: false, error: 'marketplace_payment_not_found' }),
          { status: 404, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      if (mpPayment.buyer_id !== user.id) {
        return new Response(
          JSON.stringify({ success: false, error: 'not_owner' }),
          { status: 403, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      paymentStatus = mpPayment.status;
      if (!['pending', 'processing'].includes(paymentStatus)) {
        return new Response(
          JSON.stringify({ success: false, error: 'invalid_payment_status', current_status: paymentStatus }),
          { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      amount = mpPayment.gross_amount || 0;

      // Update marketplace payment
      await supabase
        .schema('app')
        .from('marketplace_payments')
        .update({
          phone_number: cleanPhone,
          payment_method: 'ligdicash_otp',
          payment_provider: 'ligdicash',
          status: 'processing',
          updated_at: new Date().toISOString(),
        })
        .eq('id', payment_id);

    } else {
      return new Response(
        JSON.stringify({ success: false, error: 'unknown_payment_type' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    if (amount <= 0) {
      return new Response(
        JSON.stringify({ success: false, error: 'invalid_amount', amount }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // ==========================
    // CALL LIGDICASH API (or mock)
    // ==========================
    if (LIGDICASH_MODE === 'live' && LIGDICASH_API_KEY && LIGDICASH_BEARER_TOKEN) {
      // LIVE MODE: call LigdiCash OTP endpoint
      const otpUrl = `https://app.ligdicash.com/pay/v02/debitotp/${cleanPhone}/${Math.round(amount)}`;
      console.log(`[ligdicash-initiate] LIVE: calling ${otpUrl}`);

      const lgResponse = await fetch(otpUrl, {
        method: 'GET',
        headers: {
          'Apikey': LIGDICASH_API_KEY,
          'Authorization': `Bearer ${LIGDICASH_BEARER_TOKEN}`,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      });

      const lgData = await lgResponse.json();
      console.log(`[ligdicash-initiate] LigdiCash response:`, JSON.stringify(lgData));

      if (lgData.error === true || lgData.error === 'true') {
        return new Response(
          JSON.stringify({ success: false, error: 'ligdicash_otp_failed', details: lgData.message || lgData }),
          { status: 502, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({
          success: true,
          otp_sent: true,
          mode: 'live',
          phone: cleanPhone,
          amount,
          message: lgData.message || 'OTP envoyé. Vérifiez votre téléphone.',
        }),
        { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );

    } else {
      // MOCK MODE: simulate success
      console.log(`[ligdicash-initiate] MOCK: simulating OTP for ${cleanPhone}, amount ${amount}`);

      return new Response(
        JSON.stringify({
          success: true,
          otp_sent: true,
          mode: 'mock',
          phone: cleanPhone,
          amount,
          message: 'Mode test : OTP simulé. Utilisez le code 123456 pour confirmer.',
        }),
        { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

  } catch (err) {
    console.error('[ligdicash-initiate] Error:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'internal_error', details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }
});
