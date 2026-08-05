// ========================================
// ACADEMIA - EDGE FUNCTION
// LIGDICASH-CALLBACK : notification de paiement reçue de LigdiCash
// ========================================
// URL publique (--no-verify-jwt) : LigdiCash doit pouvoir l'atteindre.
//
// ── PRINCIPE, ÉTABLI D'APRÈS LA DOCUMENTATION OFFICIELLE ────────────────────
//
// LigdiCash n'envoie NI signature HMAC, NI secret partagé, NI en-tête
// d'authentification, et ne publie pas d'IP source stables
// (developers.ligdicash.com — « Le callback »).
//
// Il n'existe donc AUCUN moyen de prouver qu'une requête entrante vient de
// LigdiCash. La seule conclusion tenable :
//
//     LE CALLBACK EST UN SIGNAL DE RÉVEIL, JAMAIS UNE PREUVE.
//
// Quoi qu'il annonce, on redemande nous-mêmes à LigdiCash, avec notre clé, si
// la transaction est réellement encaissée. C'est le seul fait opposable.
//
// ── CE QUI ÉTAIT FAUX AVANT LE 04/08/2026 ───────────────────────────────────
//
// La vérification était conditionnée ainsi :
//     if (LIGDICASH_MODE !== 'mock' && token && LIGDICASH_API_KEY) { ...vérifier... }
//     else { verified = true; }   // « mock mode — on fait confiance »
//
// La branche `else` se déclenchait aussi quand `token` était VIDE — or le corps
// de la requête est entièrement contrôlé par l'appelant. Un POST sans jeton,
// portant seulement `custom_data.payment_id`, sautait la vérification, obtenait
// `verified = true`, et faisait confirmer le paiement : reçu émis, écriture au
// grand livre, commissions générées, crédits accordés.
//
// Pour un achat de crédits, l'identifiant de paiement est généré par le client
// lui-même : l'attaquant connaissait donc la valeur à envoyer.
//
// ── RÈGLE APPLIQUÉE MAINTENANT ──────────────────────────────────────────────
//
//   1. Pas de jeton → on refuse. Un callback sans jeton n'est pas de LigdiCash.
//   2. Clés absentes → on refuse. Une panne de configuration ne doit jamais
//      ouvrir un chemin de confirmation.
//   3. Vérification obligatoire auprès de LigdiCash : response_code === '00'
//      ET status === 'completed'. Les statuts réels sont `pending`,
//      `completed`, `notcompleted` — pas `failed`/`cancelled`/`rejected`.
//   4. Le montant retenu est celui que LigdiCash confirme, jamais celui du
//      corps de la requête.
//   5. Le mode simulation n'est jamais atteint par cette voie publique.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIGDICASH_API_KEY = Deno.env.get('LIGDICASH_API_KEY') ?? '';
const LIGDICASH_BEARER_TOKEN = Deno.env.get('LIGDICASH_BEARER_TOKEN') ?? '';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  // On répond toujours 200 à LigdiCash pour ne pas bloquer sa file de reprise.
  // Le message dit ce qui a été fait ; il ne fait pas foi côté sécurité.
  const ok200 = (msg: string) => new Response(
    JSON.stringify({ received: true, message: msg }),
    { status: 200, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
  );

  try {
    // ── Configuration : sans nos clés, aucune vérification n'est possible ──
    // On refuse plutôt que de confirmer sur parole. LigdiCash réessaiera.
    if (!LIGDICASH_API_KEY || !LIGDICASH_BEARER_TOKEN) {
      console.error('[ligdicash-callback] Clés LigdiCash absentes — callback ignoré (fail-closed).');
      return ok200('provider_keys_missing');
    }

    const rawBody = await req.text();
    const contentType = req.headers.get('Content-Type') || '';

    let callbackData: Record<string, unknown> = {};
    if (contentType.includes('application/x-www-form-urlencoded')) {
      for (const [key, value] of new URLSearchParams(rawBody).entries()) {
        callbackData[key] = value;
      }
    } else {
      try {
        callbackData = JSON.parse(rawBody);
      } catch {
        console.log('[ligdicash-callback] Corps illisible.');
        return ok200('unrecognized_content_type');
      }
    }

    const token = String(callbackData.token ?? '').trim();

    // ── 1. Pas de jeton, pas de conversation ──────────────────────────────
    // C'est le jeton qui permet d'interroger LigdiCash. Sans lui, rien n'est
    // vérifiable — et c'était précisément la faille : l'absence de jeton
    // faisait SAUTER la vérification au lieu de l'imposer.
    if (!token) {
      console.warn('[ligdicash-callback] Callback sans jeton — refusé.');
      return ok200('missing_token');
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── 2. Vérification auprès de LigdiCash : le seul fait opposable ──────
    let verifyData: Record<string, unknown>;
    try {
      const verifyResp = await fetch(
        `https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/confirm/?invoiceToken=${encodeURIComponent(token)}`,
        {
          headers: {
            'Apikey': LIGDICASH_API_KEY,
            'Authorization': `Bearer ${LIGDICASH_BEARER_TOKEN}`,
            'Accept': 'application/json',
          },
        },
      );
      verifyData = await verifyResp.json();
    } catch (e) {
      // Injoignable : on ne confirme rien. LigdiCash réessaiera son callback.
      console.error('[ligdicash-callback] Vérification impossible :', e);
      return ok200('verification_unavailable');
    }

    console.log('[ligdicash-callback] Vérification :', JSON.stringify(verifyData));

    const responseCode = String(verifyData.response_code ?? '');
    const statut = String(verifyData.status ?? '').toLowerCase();

    // Statuts réels de l'API : pending | completed | notcompleted.
    if (responseCode !== '00' || statut !== 'completed') {
      console.log(`[ligdicash-callback] Non encaissé (code=${responseCode}, statut=${statut}).`);
      return ok200(statut === 'notcompleted' ? 'payment_failed' : 'payment_not_completed');
    }

    // ── 3. Le paiement visé — résolu par le jeton, pas par le corps ───────
    // Le jeton a été écrit par nous à l'initiation : c'est notre propre trace,
    // pas une donnée fournie par l'appelant.
    let paymentId = '';
    let paymentType = 'application';

    const { data: ap } = await supabase
      .schema('app').from('application_payments')
      .select('id, payment_reason').eq('ligdicash_token', token).limit(1).maybeSingle();

    if (ap) {
      paymentId = ap.id;
      paymentType = ap.payment_reason === 'credit_purchase' ? 'credit_purchase' : 'application';
    } else {
      const { data: mp } = await supabase
        .schema('app').from('marketplace_payments')
        .select('id').eq('ligdicash_token', token).limit(1).maybeSingle();
      if (mp) {
        paymentId = mp.id;
        paymentType = 'marketplace';
      }
    }

    if (!paymentId) {
      // Jeton vérifié chez LigdiCash mais inconnu chez nous : à investiguer,
      // jamais à confirmer au hasard.
      console.error(`[ligdicash-callback] Jeton ${token} vérifié mais introuvable en base.`);
      return ok200('payment_not_found');
    }

    // ── 4. Le montant est celui que LigdiCash confirme ────────────────────
    const montantVerifie = Number(verifyData.amount ?? verifyData.montant ?? 0);
    const montantEncaisse = Number.isFinite(montantVerifie) && montantVerifie > 0
      ? montantVerifie
      : null;

    const transactionId = String(verifyData.transaction_id ?? '');
    const operateur = String(verifyData.operator_name ?? '');

    // ── 5. Confirmation (idempotente côté RPC) ────────────────────────────
    const { data: confirmResult, error: confirmError } = paymentType === 'credit_purchase'
      ? await supabase.rpc('app_confirm_credit_purchase', {
          p_payment_id: paymentId,
          p_ligdicash_token: token,
          p_ligdicash_transaction_id: transactionId,
          p_ligdicash_operator: operateur,
          // Rapproché du prix du pack côté base.
          p_amount_paid: montantEncaisse,
        })
      : await supabase.rpc('app_confirm_ligdicash_payment', {
          p_payment_id: paymentId,
          p_ligdicash_token: token,
          p_ligdicash_transaction_id: transactionId,
          p_ligdicash_operator: operateur,
          p_payment_type: paymentType,
          p_amount_paid: montantEncaisse,
        });

    if (confirmError) {
      console.error('[ligdicash-callback] Erreur RPC :', confirmError);
      return ok200('rpc_error');
    }

    const result = confirmResult as Record<string, unknown> | null;
    console.log('[ligdicash-callback] Résultat :', JSON.stringify(result));

    return ok200(result?.already_confirmed ? 'already_confirmed' : 'confirmed');

  } catch (err) {
    console.error('[ligdicash-callback] Erreur :', err);
    return ok200('internal_error');
  }
});
