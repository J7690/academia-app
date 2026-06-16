// Helper: search available Twilio numbers and optionally buy one
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const SID = Deno.env.get('TWILIO_ACCOUNT_SID') ?? '';
const TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN') ?? '';

serve(async (req: Request) => {
  if (!SID || !TOKEN) {
    return new Response(JSON.stringify({ error: 'no_creds' }), { status: 500 });
  }

  const body = await req.json().catch(() => ({}));
  const action = (body as Record<string, string>).action ?? 'search';
  const country = (body as Record<string, string>).country ?? 'US';
  const creds = btoa(`${SID}:${TOKEN}`);

  if (action === 'search') {
    // Search available numbers with SMS capability
    const url = `https://api.twilio.com/2010-04-01/Accounts/${SID}/AvailablePhoneNumbers/${country}/Local.json?SmsEnabled=true&PageSize=5`;
    const resp = await fetch(url, { headers: { 'Authorization': `Basic ${creds}` } });
    const data = await resp.json();
    return new Response(JSON.stringify({
      available: (data.available_phone_numbers ?? []).map((n: any) => ({
        phone_number: n.phone_number,
        friendly_name: n.friendly_name,
        capabilities: n.capabilities,
      })),
    }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }

  if (action === 'buy') {
    const phoneNumber = (body as Record<string, string>).phone_number;
    if (!phoneNumber) {
      return new Response(JSON.stringify({ error: 'missing phone_number' }), { status: 400 });
    }
    const params = new URLSearchParams({ PhoneNumber: phoneNumber });
    const resp = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${SID}/IncomingPhoneNumbers.json`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${creds}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: params.toString(),
      },
    );
    const data = await resp.json();
    return new Response(JSON.stringify(data), {
      status: resp.ok ? 200 : resp.status,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Check balance
  if (action === 'balance') {
    const resp = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${SID}/Balance.json`,
      { headers: { 'Authorization': `Basic ${creds}` } },
    );
    const data = await resp.json();
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Verify caller ID - add a number to verified list
  if (action === 'verify_number') {
    const phoneToVerify = (body as Record<string, string>).phone_number;
    if (!phoneToVerify) {
      return new Response(JSON.stringify({ error: 'missing phone_number' }), { status: 400 });
    }
    const params = new URLSearchParams({
      PhoneNumber: phoneToVerify,
      FriendlyName: 'Academia User',
    });
    const resp = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${SID}/OutgoingCallerIds.json`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${creds}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: params.toString(),
      },
    );
    const data = await resp.json();
    return new Response(JSON.stringify(data), {
      status: resp.ok ? 200 : resp.status,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ error: 'unknown action', valid: ['search','buy','balance','verify_number'] }), { status: 400 });
});
