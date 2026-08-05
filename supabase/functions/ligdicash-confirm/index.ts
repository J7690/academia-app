// ========================================
// ACADEMIA - EDGE FUNCTION
// LIGDICASH-CONFIRM : Valider OTP et finaliser le paiement
// ========================================
// Mode mock : simule succès et appelle RPC app_confirm_ligdicash_payment
// Mode live : POST /pay/v01/straight/checkout-invoice/create (mobile money) + polling verify + RPC

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIGDICASH_API_KEY = Deno.env.get('LIGDICASH_API_KEY') ?? '';
const LIGDICASH_BEARER_TOKEN = Deno.env.get('LIGDICASH_BEARER_TOKEN') ?? '';
const LIGDICASH_MODE = Deno.env.get('LIGDICASH_MODE') ?? 'mock';
const LIGDICASH_CALLBACK_URL = Deno.env.get('LIGDICASH_CALLBACK_URL') ?? '';

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
    const { payment_type, payment_id, otp_code, phone_number } = body;

    if (!payment_type || !payment_id || !otp_code || !phone_number) {
      return new Response(
        JSON.stringify({ success: false, error: 'missing_parameters' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const cleanPhone = phone_number.replace(/\s+/g, '').replace(/^(\+)/, '');

    // Load payment to get amount + details for the invoice
    let amount = 0;
    let description = 'Paiement Academia';
    let customerEmail = '';
    let customerFirstname = '';
    let customerLastname = '';

    if (payment_type === 'marketplace') {
      const { data: mp } = await supabase
        .schema('app').from('marketplace_payments')
        .select('id, gross_amount, status, buyer_id')
        .eq('id', payment_id).single();

      if (!mp || mp.buyer_id !== user.id) {
        return new Response(
          JSON.stringify({ success: false, error: 'payment_not_found_or_not_owner' }),
          { status: 404, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }
      amount = mp.gross_amount;
      description = `Achat marketplace - Commande Academia`;
    } else {
      const { data: ap } = await supabase
        .schema('app').from('application_payments')
        .select('id, amount_due, amount_paid, status, student_id, payment_reason, reference_code')
        .eq('id', payment_id).single();

      if (!ap || ap.student_id !== user.id) {
        return new Response(
          JSON.stringify({ success: false, error: 'payment_not_found_or_not_owner' }),
          { status: 404, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }
      amount = ap.amount_due || ap.amount_paid || 0;
      description = `Paiement ${ap.payment_reason} - Réf ${ap.reference_code}`;
    }

    // Get user info for invoice
    const userMeta = user.user_metadata || {};
    customerEmail = user.email || '';
    customerFirstname = userMeta.first_name || userMeta.full_name?.split(' ')[0] || '';
    customerLastname = userMeta.last_name || userMeta.full_name?.split(' ').slice(1).join(' ') || '';

    let ligdicashToken = '';
    let ligdicashTransactionId = '';
    let ligdicashOperator = '';
    let montantEncaisse: number | null = null;

    // ── REFUSER PLUTÔT QUE SIMULER ───────────────────────────────────────
    // Le test d'origine était `LIGDICASH_MODE !== 'mock' && CLÉS`. Si une clé
    // expirait, était mal orthographiée ou effacée, la fonction ne signalait
    // rien : elle basculait silencieusement dans la branche `else`, c'est-à-dire
    // en mode simulation, où le code « 123456 » confirme n'importe quel
    // paiement. Une panne de configuration devenait une faille de sécurité.
    //
    // `ligdicash-initiate` refusait déjà ce cas (`ligdicash_not_configured`) ;
    // `ligdicash-confirm` ne le faisait pas. Les deux sont désormais alignées.
    if (LIGDICASH_MODE !== 'mock' && (!LIGDICASH_API_KEY || !LIGDICASH_BEARER_TOKEN)) {
      console.error('[ligdicash-confirm] Mode live mais clés absentes — refus (fail-closed).');
      return new Response(
        JSON.stringify({
          success: false,
          error: 'ligdicash_not_configured',
          message: 'Le service de paiement est indisponible. Aucun montant n\'a été débité.',
        }),
        { status: 503, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    if (LIGDICASH_MODE !== 'mock') {
      // ============ LIVE MODE ============
      // Flux LigdiCash "Payin sans redirection" pour Orange Money / Moov / Telecel :
      //   Étape 1 (déjà faite par l'utilisateur) : composer USSD (*144*4*6*montant# pour Orange)
      //   Étape 2 : POST /pay/v01/straight/checkout-invoice/create → soumet l'OTP, lance le débit
      //   Étape 3 : GET /pay/v01/redirect/checkout-invoice/confirm/ → polling statut jusqu'à completed
      console.log(`[ligdicash-confirm] LIVE: confirming OTP for ${cleanPhone}, amount ${amount}`);

      const invoiceBody = {
        commande: {
          invoice: {
            items: [{ name: description, description, quantity: 1, unit_price: Math.round(amount), total_price: Math.round(amount) }],
            total_amount: Math.round(amount),
            devise: 'XOF',
            description,
            customer: cleanPhone,
            customer_firstname: customerFirstname,
            customer_lastname: customerLastname,
            customer_email: customerEmail,
            external_id: payment_id,
            otp: otp_code,
          },
          store: { name: 'Academia', website_url: 'https://nexiomgroup.space' },
          actions: {
            cancel_url: '',
            return_url: '',
            callback_url: LIGDICASH_CALLBACK_URL || `${SUPABASE_URL}/functions/v1/ligdicash-callback`,
          },
          custom_data: { payment_id, payment_type },
        },
      };

      // Étape 2 : POST straight/checkout-invoice/create (pour mobile money Orange/Moov/Telecel)
      const lgResponse = await fetch('https://app.ligdicash.com/pay/v01/straight/checkout-invoice/create', {
        method: 'POST',
        headers: {
          'Apikey': LIGDICASH_API_KEY,
          'Authorization': `Bearer ${LIGDICASH_BEARER_TOKEN}`,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(invoiceBody),
      });

      const lgData = await lgResponse.json();
      console.log(`[ligdicash-confirm] straight/checkout response:`, JSON.stringify(lgData));

      if (lgData.response_code !== '00') {
        return new Response(
          JSON.stringify({ success: false, error: 'ligdicash_payment_failed', details: lgData }),
          { status: 502, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      ligdicashToken = lgData.token || '';

      // Étape 3 : Polling agressif — 10 tentatives × 3s = ~30s max
      // Le débit mobile money prend typiquement 5-15s après soumission OTP
      if (ligdicashToken) {
        const verifyUrl = `https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/confirm/?invoiceToken=${ligdicashToken}`;
        const MAX_POLLS = 10;
        const POLL_INTERVAL_MS = 3000;
        let verified = false;

        for (let attempt = 1; attempt <= MAX_POLLS; attempt++) {
          if (attempt > 1) {
            await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
          }
          console.log(`[ligdicash-confirm] Verify attempt ${attempt}/${MAX_POLLS}`);

          try {
            const verifyResp = await fetch(verifyUrl, {
              headers: {
                'Apikey': LIGDICASH_API_KEY,
                'Authorization': `Bearer ${LIGDICASH_BEARER_TOKEN}`,
              },
            });
            const verifyData = await verifyResp.json();
            console.log(`[ligdicash-confirm] Verify response (${attempt}):`, JSON.stringify(verifyData));

            const statut = String(verifyData.status ?? '').toLowerCase();

            if (verifyData.response_code === '00' && statut === 'completed') {
              ligdicashTransactionId = verifyData.transaction_id || '';
              ligdicashOperator = verifyData.operator_name || '';
              // Le montant que LigdiCash confirme, et lui seul. Il alimente
              // `amount_paid`, sans lequel aucune commission ne peut naître.
              const m = Number(verifyData.amount ?? verifyData.montant ?? 0);
              montantEncaisse = Number.isFinite(m) && m > 0 ? m : null;
              verified = true;
              break;
            }

            // Statuts réels de l'API LigdiCash : pending | completed |
            // notcompleted. Le code guettait `failed`, `cancelled`, `rejected` —
            // trois valeurs qui n'existent pas. Un échec définitif n'était donc
            // jamais reconnu : on attendait les dix scrutations avant de rendre
            // un « délai dépassé » au lieu d'un refus franc.
            if (statut === 'notcompleted') {
              console.log(`[ligdicash-confirm] Paiement refusé par l'opérateur : ${statut}`);
              return new Response(
                JSON.stringify({
                  success: false,
                  error: 'ligdicash_payment_failed',
                  details: verifyData,
                  message: 'Le paiement a été refusé par l\'opérateur.',
                }),
                { status: 402, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
              );
            }
          } catch (verifyErr) {
            console.error(`[ligdicash-confirm] Verify attempt ${attempt} error:`, verifyErr);
          }
        }

        if (!verified) {
          console.log(`[ligdicash-confirm] Payment not completed after ${MAX_POLLS} polls (~${MAX_POLLS * POLL_INTERVAL_MS / 1000}s)`);
          return new Response(
            JSON.stringify({
              success: false,
              error: 'ligdicash_payment_failed',
              message: 'Le paiement n\'a pas abouti dans le délai imparti. Vérifiez votre solde et réessayez.',
              token: ligdicashToken,
            }),
            { status: 408, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
          );
        }
      }

    } else {
      // ============ MOCK MODE ============
      console.log(`[ligdicash-confirm] MOCK: simulating confirmation for ${cleanPhone}, OTP ${otp_code}`);

      if (otp_code !== '123456') {
        return new Response(
          JSON.stringify({ success: false, error: 'invalid_otp_code', message: 'Mode test : utilisez le code 123456' }),
          { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      ligdicashToken = `mock_token_${Date.now()}`;
      ligdicashTransactionId = `MOCK_TXN_${Date.now()}`;
      ligdicashOperator = 'MOCK_OPERATOR';
      montantEncaisse = amount;
    }

    // ============ CONFIRM IN DB via RPC ============
    // credit_purchase => RPC dediee (confirme + credite le pack), sinon RPC generique.
    const { data: confirmResult, error: confirmError } = payment_type === 'credit_purchase'
      ? await supabase.rpc('app_confirm_credit_purchase', {
          p_payment_id: payment_id,
          p_ligdicash_token: ligdicashToken,
          p_ligdicash_transaction_id: ligdicashTransactionId,
          p_ligdicash_operator: ligdicashOperator,
          // Rapproché du PRIX DU PACK côté base : aucun crédit n'est accordé
          // sur un montant qui ne correspond pas au tarif.
          p_amount_paid: montantEncaisse,
        })
      : await supabase.rpc('app_confirm_ligdicash_payment', {
          p_payment_id: payment_id,
          p_ligdicash_token: ligdicashToken,
          p_ligdicash_transaction_id: ligdicashTransactionId,
          p_ligdicash_operator: ligdicashOperator,
          p_payment_type: payment_type,
          // Le montant encaissé, vérifié auprès de LigdiCash. Sans lui,
          // `amount_paid` restait NULL et les générateurs de commission
          // abandonnaient en silence sur « no_amount_paid ».
          p_amount_paid: montantEncaisse,
        });

    if (confirmError) {
      console.error(`[ligdicash-confirm] RPC error:`, confirmError);
      return new Response(
        JSON.stringify({ success: false, error: 'confirmation_rpc_failed', details: confirmError.message }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const result = confirmResult as Record<string, unknown> | null;
    if (!result || result.success !== true) {
      return new Response(
        JSON.stringify({ success: false, error: 'confirmation_failed', details: result }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[ligdicash-confirm] Payment confirmed:`, JSON.stringify(result));

    return new Response(
      JSON.stringify({
        success: true,
        mode: LIGDICASH_MODE === 'live' ? 'live' : 'mock',
        receipt_number: result.receipt_number || null,
        transaction_id: ligdicashTransactionId,
        operator: ligdicashOperator,
        commission_created: result.commission_created || false,
        commission_amount: result.commission_amount || 0,
      }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    console.error('[ligdicash-confirm] Error:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'internal_error', details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }
});
