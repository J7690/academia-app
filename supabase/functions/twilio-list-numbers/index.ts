// Temporary helper: list Twilio phone numbers on the account
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const SID = Deno.env.get('TWILIO_ACCOUNT_SID') ?? '';
const TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN') ?? '';

serve(async () => {
  if (!SID || !TOKEN) {
    return new Response(JSON.stringify({ error: 'no_creds' }), { status: 500 });
  }

  const creds = btoa(`${SID}:${TOKEN}`);

  // List incoming phone numbers
  const numbersResp = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${SID}/IncomingPhoneNumbers.json`,
    { headers: { 'Authorization': `Basic ${creds}` } },
  );
  const numbersData = await numbersResp.json();

  // List messaging services
  let msgServices = null;
  try {
    const msResp = await fetch(
      `https://messaging.twilio.com/v1/Services`,
      { headers: { 'Authorization': `Basic ${creds}` } },
    );
    msgServices = await msResp.json();
  } catch (_) {}

  // Account info
  const acctResp = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${SID}.json`,
    { headers: { 'Authorization': `Basic ${creds}` } },
  );
  const acctData = await acctResp.json();

  return new Response(JSON.stringify({
    account: { friendly_name: acctData.friendly_name, type: acctData.type, status: acctData.status },
    phone_numbers: (numbersData.incoming_phone_numbers ?? []).map((n: any) => ({
      sid: n.sid,
      phone_number: n.phone_number,
      friendly_name: n.friendly_name,
      capabilities: n.capabilities,
    })),
    messaging_services: msgServices?.services?.map((s: any) => ({
      sid: s.sid,
      friendly_name: s.friendly_name,
    })) ?? [],
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
