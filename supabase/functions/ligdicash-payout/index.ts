// ========================================
// ACADEMIA - EDGE FUNCTION
// LIGDICASH-PAYOUT : Reverser argent vers mobile money des bénéficiaires
// ========================================
// Auth admin required (ou service_role pour cron)
// Mode mock : simule succès
// Mode live : POST /pay/v01/withdrawal/create

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIGDICASH_API_KEY = Deno.env.get('LIGDICASH_API_KEY') ?? '';
const LIGDICASH_BEARER_TOKEN = Deno.env.get('LIGDICASH_BEARER_TOKEN') ?? '';
const LIGDICASH_MODE = Deno.env.get('LIGDICASH_MODE') ?? 'mock';

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
    const authHeader = req.headers.get('Authorization') ?? '';
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Check if called with service_role (cron) or user token (admin)
    const isServiceRole = authHeader.includes(SUPABASE_SERVICE_ROLE_KEY);
    let isAdmin = isServiceRole;

    if (!isServiceRole) {
      const userToken = authHeader.replace('Bearer ', '');
      const { data: { user }, error: authError } = await supabase.auth.getUser(userToken);
      if (authError || !user) {
        return new Response(
          JSON.stringify({ success: false, error: 'not_authenticated' }),
          { status: 401, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }
      // Rôle lu depuis app_metadata (source de confiance, non modifiable par le client),
      // avec repli sur user_metadata pour compat (les deux sont synchronisés par trigger).
      const role = (user.app_metadata as any)?.role || (user.user_metadata as any)?.role || '';
      isAdmin = role === 'admin' || role === 'super_admin';
    }

    if (!isAdmin) {
      return new Response(
        JSON.stringify({ success: false, error: 'not_admin' }),
        { status: 403, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const body = await req.json();
    const { payout_ids, all_pending } = body;

    // Load payouts to process
    let query = supabase.schema('app').from('payout_queue').select('*');

    if (all_pending === true) {
      query = query.eq('status', 'pending');
    } else if (Array.isArray(payout_ids) && payout_ids.length > 0) {
      query = query.in('id', payout_ids).eq('status', 'pending');
    } else {
      return new Response(
        JSON.stringify({ success: false, error: 'specify_payout_ids_or_all_pending' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const { data: payouts, error: loadError } = await query;

    if (loadError) {
      return new Response(
        JSON.stringify({ success: false, error: 'load_payouts_failed', details: loadError.message }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    if (!payouts || payouts.length === 0) {
      return new Response(
        JSON.stringify({ success: true, processed: 0, message: 'Aucun payout en attente.' }),
        { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[ligdicash-payout] Processing ${payouts.length} payouts`);

    let succeeded = 0;
    let failed = 0;
    const results: Array<{ id: string; status: string; error?: string }> = [];

    for (const payout of payouts) {
      const payoutId = payout.id;
      const phone = payout.beneficiary_phone;
      const amount = payout.amount;

      if (!phone || phone.length < 8) {
        // Mark as failed — no phone
        await supabase.schema('app').from('payout_queue')
          .update({ status: 'failed', error_message: 'Numéro de téléphone manquant', updated_at: new Date().toISOString() })
          .eq('id', payoutId);
        failed++;
        results.push({ id: payoutId, status: 'failed', error: 'no_phone' });
        continue;
      }

      // Mark as processing
      await supabase.schema('app').from('payout_queue')
        .update({ status: 'processing' })
        .eq('id', payoutId);

      if (LIGDICASH_MODE !== 'mock' && LIGDICASH_API_KEY && LIGDICASH_BEARER_TOKEN) {
        // ============ LIVE/TEST MODE ============
        try {
          const cleanPhone = phone.replace(/\s+/g, '').replace(/^(\+)/, '');
          const callbackUrl = `${SUPABASE_URL}/functions/v1/ligdicash-callback`;

          const withdrawBody = {
            commande: {
              amount: Math.round(amount),
              description: `Versement Academia - ${payout.reason || payout.beneficiary_type} - ${payoutId.substring(0, 8)}`,
              customer: cleanPhone,
              custom_data: { payout_id: payoutId, beneficiary_type: payout.beneficiary_type },
              callback_url: callbackUrl,
              top_up_wallet: 1, // 1 = transfert LigdiCash → LigdiCash (portefeuille du bénéficiaire)
            },
          };

          const lgResponse = await fetch('https://app.ligdicash.com/pay/v01/withdrawal/create', {
            method: 'POST',
            headers: {
              'Apikey': LIGDICASH_API_KEY,
              'Authorization': `Bearer ${LIGDICASH_BEARER_TOKEN}`,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(withdrawBody),
          });

          const lgData = await lgResponse.json();
          console.log(`[ligdicash-payout] LigdiCash withdrawal response for ${payoutId}:`, JSON.stringify(lgData));

          if (lgData.response_code === '00') {
            const lgToken = lgData.token || '';

            // Verify withdrawal status
            let payoutStatus = 'processing';
            let txnId = '';

            if (lgToken) {
              const verifyUrl = `https://app.ligdicash.com/pay/v01/withdrawal/confirm/?withdrawalToken=${lgToken}`;
              const verifyResp = await fetch(verifyUrl, {
                headers: {
                  'Apikey': LIGDICASH_API_KEY,
                  'Authorization': `Bearer ${LIGDICASH_BEARER_TOKEN}`,
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              });
              const verifyData = await verifyResp.json();

              if (verifyData.response_code === '00' && verifyData.status === 'completed') {
                payoutStatus = 'completed';
                txnId = verifyData.transaction_id || '';
              }
            }

            await supabase.schema('app').from('payout_queue')
              .update({
                status: payoutStatus,
                ligdicash_token: lgToken,
                ligdicash_transaction_id: txnId,
                processed_at: payoutStatus === 'completed' ? new Date().toISOString() : null,
              })
              .eq('id', payoutId);

            if (payoutStatus === 'completed') {
              // Write to platform ledger
              await supabase.schema('app').from('platform_ledger').insert({
                transaction_type: 'payout',
                amount,
                currency: payout.currency || 'XOF',
                direction: 'debit',
                counterpart_type: payout.beneficiary_type,
                counterpart_id: payout.beneficiary_user_id,
                reference_id: payoutId,
                description: `Payout ${payout.reason} vers ${cleanPhone}`,
              });
              succeeded++;
              results.push({ id: payoutId, status: 'completed' });
            } else {
              // Still processing — will be verified later
              succeeded++;
              results.push({ id: payoutId, status: 'processing' });
            }
          } else {
            await supabase.schema('app').from('payout_queue')
              .update({
                status: 'failed',
                error_message: lgData.response_text || lgData.description || 'LigdiCash withdrawal failed',
                retry_count: (payout.retry_count || 0) + 1,
              })
              .eq('id', payoutId);
            failed++;
            results.push({ id: payoutId, status: 'failed', error: 'ligdicash_error' });
          }
        } catch (lgErr) {
          console.error(`[ligdicash-payout] Error for payout ${payoutId}:`, lgErr);
          await supabase.schema('app').from('payout_queue')
            .update({
              status: 'failed',
              error_message: String(lgErr),
              retry_count: (payout.retry_count || 0) + 1,
            })
            .eq('id', payoutId);
          failed++;
          results.push({ id: payoutId, status: 'failed', error: String(lgErr) });
        }

      } else {
        // ============ MOCK MODE ============
        console.log(`[ligdicash-payout] MOCK: simulating payout ${payoutId} → ${phone} for ${amount} XOF`);

        const mockToken = `mock_payout_${Date.now()}_${payoutId.substring(0, 8)}`;
        const mockTxnId = `MOCK_PAYOUT_TXN_${Date.now()}`;

        await supabase.schema('app').from('payout_queue')
          .update({
            status: 'completed',
            ligdicash_token: mockToken,
            ligdicash_transaction_id: mockTxnId,
            processed_at: new Date().toISOString(),
          })
          .eq('id', payoutId);

        // Write to platform ledger
        await supabase.schema('app').from('platform_ledger').insert({
          transaction_type: 'payout',
          amount,
          currency: payout.currency || 'XOF',
          direction: 'debit',
          counterpart_type: payout.beneficiary_type,
          counterpart_id: payout.beneficiary_user_id,
          reference_id: payoutId,
          description: `[MOCK] Payout ${payout.reason} vers ${phone}`,
        });

        succeeded++;
        results.push({ id: payoutId, status: 'completed' });
      }
    }

    console.log(`[ligdicash-payout] Done: ${succeeded} succeeded, ${failed} failed out of ${payouts.length}`);

    return new Response(
      JSON.stringify({
        success: true,
        processed: payouts.length,
        succeeded,
        failed,
        mode: LIGDICASH_MODE === 'live' ? 'live' : 'mock',
        results,
      }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    console.error('[ligdicash-payout] Error:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'internal_error', details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }
});
