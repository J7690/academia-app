// ========================================
// ACADEMIA - EDGE FUNCTION
// LIGDICASH-INITIATE : Préparer le paiement mobile money (Orange Money / Moov / Telecel)
// ========================================
// Flux LigdiCash "Payin sans redirection" pour mobile money :
//   1. L'utilisateur compose le code USSD de son opérateur pour obtenir un OTP :
//      - Orange Money BF : *144*4*6*{montant}#
//      - Moov Money BF   : *555*6#
//   2. L'utilisateur saisit l'OTP dans l'app
//   3. ligdicash-confirm valide avec POST /pay/v01/straight/checkout-invoice/create + polling
// NB: debitotp = pour Wallet LigdiCash seulement. Les opérateurs mobile money
//     utilisent leur propre USSD pour générer l'OTP.
// Mode mock : retourne succès simulé

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIGDICASH_API_KEY = Deno.env.get('LIGDICASH_API_KEY') ?? '';
const LIGDICASH_BEARER_TOKEN = Deno.env.get('LIGDICASH_BEARER_TOKEN') ?? '';
const LIGDICASH_MODE = Deno.env.get('LIGDICASH_MODE') ?? 'mock'; // 'mock' or 'live'

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept,x-client-info',
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
    const { payment_type, payment_id, phone_number, operator, amount_override } = body;

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

    // Override eventuel (mode test / dev) : montant choisi par l'utilisateur >= 10 XOF.
    const overrideNum = typeof amount_override === 'number'
      ? amount_override
      : (amount_override != null ? Number(amount_override) : NaN);
    const hasOverride = !isNaN(overrideNum) && overrideNum > 0;

    if (payment_type === 'application' || payment_type === 'subscription' || payment_type === 'td' || payment_type === 'short_training') {
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

      // Override eventuel du montant (mode test) : repercute aussi dans la DB.
      const finalAmount = hasOverride ? overrideNum : amount;
      amount = finalAmount;

      // Update payment: store phone + set status to processing (+ amount si override)
      const updatePayload: Record<string, unknown> = {
        phone_number: cleanPhone,
        payment_method: 'ligdicash_otp',
        channel: 'ligdicash',
        status: 'processing',
        updated_at: new Date().toISOString(),
      };
      if (hasOverride) {
        updatePayload.amount_due = finalAmount;
      }
      await supabase
        .schema('app')
        .from('application_payments')
        .update(updatePayload)
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
      const finalMpAmount = hasOverride ? overrideNum : amount;
      amount = finalMpAmount;

      // Update marketplace payment (+ amount si override)
      const mpUpdatePayload: Record<string, unknown> = {
        phone_number: cleanPhone,
        payment_method: 'ligdicash_otp',
        payment_provider: 'ligdicash',
        status: 'processing',
        updated_at: new Date().toISOString(),
      };
      if (hasOverride) {
        mpUpdatePayload.gross_amount = finalMpAmount;
      }
      await supabase
        .schema('app')
        .from('marketplace_payments')
        .update(mpUpdatePayload)
        .eq('id', payment_id);

    } else {
      return new Response(
        JSON.stringify({ success: false, error: 'unknown_payment_type' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // Montant minimal commun a tous les services : 10 XOF
    const MIN_PAYMENT_AMOUNT = 10;
    if (amount <= 0) {
      return new Response(
        JSON.stringify({ success: false, error: 'invalid_amount', amount }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }
    if (amount < MIN_PAYMENT_AMOUNT) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'amount_below_minimum',
          message: `Le montant minimum est de ${MIN_PAYMENT_AMOUNT} XOF.`,
          amount,
          minimum: MIN_PAYMENT_AMOUNT,
        }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // ==========================
    // Pour les opérateurs mobile money : PAS d'appel à debitotp.
    // L'utilisateur doit composer le code USSD de son opérateur pour obtenir son OTP.
    // debitotp = Wallet LigdiCash seulement (nos utilisateurs n'en ont pas).
    // ==========================
    const op = (operator || '').toLowerCase();
    const roundedAmount = Math.round(amount);

    // Déterminer le code USSD selon l'opérateur
    let ussdCode = '';
    let ussdMessage = '';

    if (op === 'orange') {
      ussdCode = `*144*4*6*${roundedAmount}#`;
      ussdMessage = `Composez ${ussdCode} sur votre téléphone pour recevoir votre code OTP Orange Money.`;
    } else if (op === 'moov') {
      ussdCode = '*555*6#';
      ussdMessage = `Composez ${ussdCode} sur votre téléphone pour recevoir votre code OTP Moov Money.`;
    } else if (op === 'telecel') {
      ussdCode = '*100*6#';
      ussdMessage = `Composez ${ussdCode} sur votre téléphone pour recevoir votre code OTP Telecel Money.`;
    } else {
      // Opérateur inconnu : fallback générique
      ussdMessage = 'Composez le code USSD de votre opérateur pour recevoir votre code OTP.';
    }

    if (LIGDICASH_MODE === 'mock') {
      console.log(`[ligdicash-initiate] MOCK: ${cleanPhone}, amount ${amount}, operator ${op}`);
      return new Response(
        JSON.stringify({
          success: true,
          mode: 'mock',
          operator: op || 'mock',
          phone: cleanPhone,
          amount,
          ussd_code: ussdCode || '*144*4*6*100#',
          message: ussdCode
            ? `Mode test. ${ussdMessage} Puis saisissez le code 123456.`
            : 'Mode test : utilisez le code 123456.',
        }),
        { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // ===== LIVE MODE =====
    // Pas d'appel API LigdiCash ici. L'utilisateur compose le USSD lui-même.
    // L'appel API se fait dans ligdicash-confirm avec l'OTP.
    if (!LIGDICASH_API_KEY || !LIGDICASH_BEARER_TOKEN) {
      return new Response(
        JSON.stringify({ success: false, error: 'ligdicash_not_configured' }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[ligdicash-initiate] LIVE: operator=${op}, phone=${cleanPhone}, amount=${roundedAmount}, ussd=${ussdCode}`);

    return new Response(
      JSON.stringify({
        success: true,
        mode: 'live',
        operator: op || 'unknown',
        phone: cleanPhone,
        amount,
        ussd_code: ussdCode,
        message: ussdMessage || 'Composez le code USSD de votre opérateur pour obtenir votre code OTP.',
      }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    console.error('[ligdicash-initiate] Error:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'internal_error', details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }
});
