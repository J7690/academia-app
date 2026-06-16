// Temporary diagnostic: test LigdiCash API with configured secrets
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const LIGDICASH_API_KEY = Deno.env.get('LIGDICASH_API_KEY') ?? '';
const LIGDICASH_BEARER_TOKEN = Deno.env.get('LIGDICASH_BEARER_TOKEN') ?? '';
const LIGDICASH_MODE = Deno.env.get('LIGDICASH_MODE') ?? '';

serve(async (req: Request) => {
  const body = await req.json().catch(() => ({}));
  const action = (body as Record<string, string>).action ?? 'info';
  const phone = (body as Record<string, string>).phone ?? '22666660538';
  const amount = (body as Record<string, string>).amount ?? '100';
  const otp = (body as Record<string, string>).otp ?? '';

  const headers: Record<string, string> = {
    'Apikey': LIGDICASH_API_KEY,
    'Authorization': `Bearer ${LIGDICASH_BEARER_TOKEN}`,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // Action: info - show config
  if (action === 'info') {
    return new Response(JSON.stringify({
      mode: LIGDICASH_MODE,
      api_key_set: !!LIGDICASH_API_KEY,
      api_key_prefix: LIGDICASH_API_KEY.substring(0, 8) + '...',
      bearer_token_set: !!LIGDICASH_BEARER_TOKEN,
      bearer_token_prefix: LIGDICASH_BEARER_TOKEN.substring(0, 8) + '...',
    }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }

  // Action: send_otp - test debitotp endpoint
  if (action === 'send_otp') {
    const url = `https://app.ligdicash.com/pay/v02/debitotp/${phone}/${amount}`;
    console.log(`[diag] GET ${url}`);
    const resp = await fetch(url, { method: 'GET', headers });
    const text = await resp.text();
    console.log(`[diag] Response: ${text}`);
    let data;
    try { data = JSON.parse(text); } catch { data = text; }
    return new Response(JSON.stringify({
      url,
      status: resp.status,
      response: data,
    }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }

  // Action: confirm - test debitwallet/withotp
  if (action === 'confirm') {
    const invoiceBody = {
      commande: {
        invoice: {
          items: [{ name: 'Test Academia', description: 'Test paiement', quantity: 1, unit_price: parseInt(amount), total_price: parseInt(amount) }],
          total_amount: parseInt(amount),
          devise: 'XOF',
          description: 'Test paiement Academia',
          customer: phone,
          customer_firstname: 'Test',
          customer_lastname: 'User',
          customer_email: 'test@test.com',
          external_id: 'diag-test-' + Date.now(),
          otp: otp,
        },
        store: { name: 'Academia', website_url: 'https://nexiomgroup.space' },
        actions: { cancel_url: '', return_url: '', callback_url: '' },
        custom_data: { payment_id: 'diag', payment_type: 'test' },
      },
    };

    console.log(`[diag] POST debitwallet/withotp body=`, JSON.stringify(invoiceBody));
    const resp = await fetch('https://app.ligdicash.com/pay/v02/debitwallet/withotp', {
      method: 'POST',
      headers,
      body: JSON.stringify(invoiceBody),
    });
    const text = await resp.text();
    console.log(`[diag] Response: ${text}`);
    let data;
    try { data = JSON.parse(text); } catch { data = text; }
    return new Response(JSON.stringify({
      status: resp.status,
      response: data,
    }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }

  // Action: check_balance - verify merchant balance on LigdiCash
  if (action === 'check_balance') {
    // Try to get balance info
    const urls = [
      'https://app.ligdicash.com/pay/v01/merchant/balance',
      'https://app.ligdicash.com/pay/v02/merchant/balance',
    ];
    const results: Record<string, unknown>[] = [];
    for (const url of urls) {
      try {
        const resp = await fetch(url, { method: 'GET', headers });
        const text = await resp.text();
        let data;
        try { data = JSON.parse(text); } catch { data = text; }
        results.push({ url, status: resp.status, response: data });
      } catch (e) {
        results.push({ url, error: String(e) });
      }
    }
    return new Response(JSON.stringify({ results }), {
      status: 200, headers: { 'Content-Type': 'application/json' },
    });
  }

  // Action: verify_token - GET status d'une invoice par son token (preuve qu'elle existe cote LigdiCash)
  if (action === 'verify_token') {
    const token = (body as Record<string, string>).token ?? '';
    if (!token) {
      return new Response(JSON.stringify({ error: 'token required' }), { status: 400 });
    }
    const url = `https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/confirm/?invoiceToken=${token}`;
    console.log(`[diag] GET ${url.substring(0, 100)}...`);
    const resp = await fetch(url, { method: 'GET', headers });
    const text = await resp.text();
    let data;
    try { data = JSON.parse(text); } catch { data = text; }
    return new Response(JSON.stringify({ status: resp.status, response: data }), {
      status: 200, headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ error: 'unknown action', valid: ['info', 'send_otp', 'confirm', 'check_balance', 'verify_token'] }), { status: 400 });
});
