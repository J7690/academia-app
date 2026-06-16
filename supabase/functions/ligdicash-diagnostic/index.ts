// TEMPORARY DIAGNOSTIC FUNCTION - DELETE AFTER USE
// Tests LigdiCash API endpoints directly and returns raw responses
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const LIGDICASH_API_KEY = Deno.env.get('LIGDICASH_API_KEY') ?? '';
const LIGDICASH_BEARER_TOKEN = Deno.env.get('LIGDICASH_BEARER_TOKEN') ?? '';
const LIGDICASH_MODE = Deno.env.get('LIGDICASH_MODE') ?? '';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept,x-client-info',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
  'Content-Type': 'application/json',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  const results: Record<string, unknown> = {
    timestamp: new Date().toISOString(),
    ligdicash_mode: LIGDICASH_MODE,
    api_key_set: !!LIGDICASH_API_KEY,
    api_key_preview: LIGDICASH_API_KEY ? LIGDICASH_API_KEY.substring(0, 8) + '...' : 'NOT SET',
    bearer_token_set: !!LIGDICASH_BEARER_TOKEN,
    bearer_token_preview: LIGDICASH_BEARER_TOKEN ? LIGDICASH_BEARER_TOKEN.substring(0, 8) + '...' : 'NOT SET',
  };

  const phone = '22666660538';
  const amounts = [100, 500, 1000];

  for (const amount of amounts) {
    const url = `https://app.ligdicash.com/pay/v02/debitotp/${phone}/${amount}`;
    try {
      const resp = await fetch(url, {
        method: 'GET',
        headers: {
          'Apikey': LIGDICASH_API_KEY,
          'Authorization': `Bearer ${LIGDICASH_BEARER_TOKEN}`,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      });
      const text = await resp.text();
      let parsed;
      try { parsed = JSON.parse(text); } catch { parsed = text; }
      results[`debitotp_${amount}XOF`] = {
        status: resp.status,
        statusText: resp.statusText,
        response: parsed,
      };
    } catch (err) {
      results[`debitotp_${amount}XOF`] = { error: String(err) };
    }
  }

  // Also test straight/checkout-invoice/create (the old endpoint) with a dummy OTP
  // to see what response it gives vs debitwallet/withotp
  const testEndpoints = [
    { name: 'debitwallet_withotp', url: 'https://app.ligdicash.com/pay/v02/debitwallet/withotp' },
    { name: 'straight_checkout', url: 'https://app.ligdicash.com/pay/v01/straight/checkout-invoice/create' },
  ];

  const invoiceBody = {
    commande: {
      invoice: {
        items: [{ name: 'Test', description: 'Test diagnostic', quantity: 1, unit_price: 100, total_price: 100 }],
        total_amount: 100,
        devise: 'XOF',
        description: 'Test diagnostic',
        customer: phone,
        customer_firstname: 'Test',
        customer_lastname: 'User',
        customer_email: 'test@test.com',
        external_id: 'diag-test',
        otp: '000000',
      },
      store: { name: 'Academia', website_url: 'https://nexiomgroup.space' },
      actions: { cancel_url: '', return_url: '', callback_url: '' },
      custom_data: { payment_id: 'diagnostic' },
    },
  };

  for (const ep of testEndpoints) {
    try {
      const resp = await fetch(ep.url, {
        method: 'POST',
        headers: {
          'Apikey': LIGDICASH_API_KEY,
          'Authorization': `Bearer ${LIGDICASH_BEARER_TOKEN}`,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(invoiceBody),
      });
      const text = await resp.text();
      let parsed;
      try { parsed = JSON.parse(text); } catch { parsed = text; }
      results[ep.name] = {
        status: resp.status,
        statusText: resp.statusText,
        response: parsed,
      };
    } catch (err) {
      results[ep.name] = { error: String(err) };
    }
  }

  return new Response(JSON.stringify(results, null, 2), { headers: CORS });
});
