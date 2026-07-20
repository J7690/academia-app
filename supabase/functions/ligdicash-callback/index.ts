// ========================================
// ACADEMIA - EDGE FUNCTION
// LIGDICASH-CALLBACK : Webhook backup reçu de LigdiCash
// ========================================
// URL publique (--no-verify-jwt)
// LigdiCash envoie 2 POST : form-urlencoded + JSON
// Idempotent : ignore si paiement déjà confirmé

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIGDICASH_API_KEY = Deno.env.get('LIGDICASH_API_KEY') ?? '';
const LIGDICASH_BEARER_TOKEN = Deno.env.get('LIGDICASH_BEARER_TOKEN') ?? '';
const LIGDICASH_MODE = Deno.env.get('LIGDICASH_MODE') ?? 'mock';
// Allowlist IP OPTIONNELLE. LigdiCash ne publie pas d'IP source stables et
// n'envoie NI signature HMAC NI timestamp (cf. doc officielle
// https://developers.ligdicash.com/api1/callback). La sécurité réelle repose
// donc sur : (1) re-vérification serveur par token auprès de LigdiCash avant
// tout crédit, (2) idempotence de la RPC. Ne définir LIGDICASH_ALLOWED_IPS que
// si le support LigdiCash fournit des IP officielles garanties stables ; sinon
// laisser vide (comportement par défaut : autorise tout).
const LIGDICASH_ALLOWED_IPS = (Deno.env.get('LIGDICASH_ALLOWED_IPS') ?? '').split(',').map(ip => ip.trim()).filter(ip => ip);

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

// IP allowlisting (optionnelle : autorise tout si aucune IP configurée)
function isAllowedIP(ip: string, allowedIPs: string[]): boolean {
  if (allowedIPs.length === 0) {
    return true; // Aucune allowlist configurée -> on autorise (LigdiCash ne publie pas d'IP stables)
  }
  const isValid = allowedIPs.includes(ip);
  if (!isValid) {
    console.log(`[ligdicash-callback] IP ${ip} not in allowlist`);
  }
  return isValid;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  // Always return 200 to LigdiCash (don't block their retry queue)
  const ok200 = (msg: string) => new Response(
    JSON.stringify({ received: true, message: msg }),
    { status: 200, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
  );

  try {
    // Sécurité (optionnelle) : allowlist IP. Aucune vérif HMAC/timestamp : LigdiCash
    // n'en envoie pas. La vraie protection anti-fraude est la re-vérification par
    // token auprès de LigdiCash (plus bas) + l'idempotence de la RPC.
    const clientIP = req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || '';
    if (!isAllowedIP(clientIP, LIGDICASH_ALLOWED_IPS)) {
      console.log(`[ligdicash-callback] Unauthorized IP: ${clientIP}`);
      return ok200('unauthorized_ip');
    }

    // Corps brut (LigdiCash envoie form-urlencoded ET json)
    const rawBody = await req.text();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Parse body — LigdiCash sends both form-urlencoded and JSON
    let callbackData: Record<string, unknown> = {};
    const contentType = req.headers.get('Content-Type') || '';

    if (contentType.includes('application/json')) {
      callbackData = JSON.parse(rawBody);
    } else if (contentType.includes('application/x-www-form-urlencoded')) {
      const formData = new FormData();
      const params = new URLSearchParams(rawBody);
      for (const [key, value] of params.entries()) {
        formData.append(key, value);
      }
      for (const [key, value] of formData.entries()) {
        callbackData[key] = value;
      }
    } else {
      // Try JSON first, fallback to text
      try {
        callbackData = JSON.parse(rawBody);
      } catch {
        console.log(`[ligdicash-callback] Raw body: ${rawBody}`);
        return ok200('unrecognized_content_type');
      }
    }

    console.log(`[ligdicash-callback] Received:`, JSON.stringify(callbackData));

    const token = (callbackData.token as string) || '';
    const status = (callbackData.status as string) || '';
    const transactionId = (callbackData.transaction_id as string) || '';
    const amount = callbackData.amount || callbackData.montant || '';
    const operatorName = (callbackData.operator_name as string) || '';

    // Extract custom_data to find our payment_id and payment_type
    let paymentId = '';
    let paymentType = 'application';
    const customData = callbackData.custom_data;

    if (Array.isArray(customData)) {
      for (const item of customData) {
        if (typeof item === 'object' && item !== null) {
          const obj = item as Record<string, unknown>;
          if (obj.keyof_customdata === 'payment_id') paymentId = String(obj.valueof_customdata || '');
          if (obj.keyof_customdata === 'payment_type') paymentType = String(obj.valueof_customdata || 'application');
        }
      }
    } else if (typeof customData === 'object' && customData !== null) {
      const cd = customData as Record<string, unknown>;
      paymentId = String(cd.payment_id || '');
      paymentType = String(cd.payment_type || 'application');
    }

    if (!token && !paymentId) {
      console.log(`[ligdicash-callback] No token or payment_id found, ignoring`);
      return ok200('no_identifiable_data');
    }

    // If we have a token but no payment_id, try to find it in DB
    if (!paymentId && token) {
      const { data: ap } = await supabase
        .schema('app').from('application_payments')
        .select('id, payment_reason').eq('ligdicash_token', token).limit(1).single();
      if (ap) {
        paymentId = ap.id;
        // Distinguer credit_purchase des autres paiements application
        paymentType = ap.payment_reason === 'credit_purchase' ? 'credit_purchase' : 'application';
      } else {
        const { data: mp } = await supabase
          .schema('app').from('marketplace_payments')
          .select('id').eq('ligdicash_token', token).limit(1).single();
        if (mp) {
          paymentId = mp.id;
          paymentType = 'marketplace';
        }
      }
    }

    if (!paymentId) {
      console.log(`[ligdicash-callback] Could not resolve payment_id for token ${token}`);
      return ok200('payment_not_found');
    }

    // VERIFY with LigdiCash (anti-fraud) — only in live mode
    let verified = false;
    let verifiedOperator = operatorName;
    let verifiedTxnId = transactionId;

    if (LIGDICASH_MODE !== 'mock' && token && LIGDICASH_API_KEY) {
      try {
        const verifyUrl = `https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/confirm/?invoiceToken=${token}`;
        const verifyResp = await fetch(verifyUrl, {
          headers: {
            'Apikey': LIGDICASH_API_KEY,
            'Authorization': `Bearer ${LIGDICASH_BEARER_TOKEN}`,
          },
        });
        const verifyData = await verifyResp.json();
        console.log(`[ligdicash-callback] Verify response:`, JSON.stringify(verifyData));

        if (verifyData.response_code === '00' && verifyData.status === 'completed') {
          verified = true;
          verifiedTxnId = verifyData.transaction_id || transactionId;
          verifiedOperator = verifyData.operator_name || operatorName;
        }
      } catch (verifyErr) {
        console.error(`[ligdicash-callback] Verify error:`, verifyErr);
      }
    } else {
      // Mock mode — on fait confiance au callback
      verified = true;
    }

    if (!verified && LIGDICASH_MODE !== 'mock') {
      console.log(`[ligdicash-callback] Payment not verified as completed, ignoring`);
      return ok200('payment_not_completed');
    }

    // CONFIRM via RPC (idempotent — will return already_confirmed if already done)
    // credit_purchase => RPC dediee (confirme + credite le pack), sinon RPC generique.
    const { data: confirmResult, error: confirmError } = paymentType === 'credit_purchase'
      ? await supabase.rpc('app_confirm_credit_purchase', {
          p_payment_id: paymentId,
          p_ligdicash_token: token,
          p_ligdicash_transaction_id: verifiedTxnId,
          p_ligdicash_operator: verifiedOperator,
        })
      : await supabase.rpc('app_confirm_ligdicash_payment', {
          p_payment_id: paymentId,
          p_ligdicash_token: token,
          p_ligdicash_transaction_id: verifiedTxnId,
          p_ligdicash_operator: verifiedOperator,
          p_payment_type: paymentType,
        });

    if (confirmError) {
      console.error(`[ligdicash-callback] RPC error:`, confirmError);
      return ok200('rpc_error');
    }

    const result = confirmResult as Record<string, unknown> | null;
    console.log(`[ligdicash-callback] Confirm result:`, JSON.stringify(result));

    return ok200(result?.already_confirmed ? 'already_confirmed' : 'confirmed');

  } catch (err) {
    console.error('[ligdicash-callback] Error:', err);
    return ok200('internal_error');
  }
});
