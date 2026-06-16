// ========================================
// ACADEMIA - EDGE FUNCTION
// SEND-PHONE-OTP : Supabase Auth SMS Hook
// Appelé par Supabase Auth quand un OTP doit être envoyé par SMS.
// Utilise Twilio Programmable SMS pour envoyer l'OTP généré par Supabase.
// ========================================

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const TWILIO_ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID') ?? '';
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN') ?? '';
// Numéro Twilio d'envoi OU Messaging Service SID
const TWILIO_FROM_NUMBER = Deno.env.get('TWILIO_FROM_NUMBER') ?? '';
const TWILIO_MESSAGING_SERVICE_SID = Deno.env.get('TWILIO_MESSAGING_SERVICE_SID') ?? '';

serve(async (req: Request) => {
  // Supabase SMS Hook envoie toujours un POST
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'method_not_allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'invalid_json' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Payload du SMS Hook Supabase :
  // Format Postgres hook : { phone, otp } ou { sms: { phone, otp }, user: { phone } }
  // Format HTTPS hook   : { user: { phone }, email_data: { token } }
  const user = body.user as Record<string, string> | undefined;
  const sms = body.sms as Record<string, string> | undefined;
  const emailData = body.email_data as Record<string, string> | undefined;

  const phone = (body.phone as string) || sms?.phone || user?.phone || '';
  const otp = (body.otp as string) || sms?.otp || emailData?.token || '';

  console.log(`[send-phone-otp] phone=${phone} otp_len=${otp.length}`);

  if (!phone || !otp) {
    console.error('[send-phone-otp] Missing phone or OTP in hook payload', body);
    return new Response(JSON.stringify({ error: 'missing_phone_or_otp' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN) {
    console.error('[send-phone-otp] Missing Twilio secrets (ACCOUNT_SID or AUTH_TOKEN)');
    return new Response(JSON.stringify({ error: 'missing_twilio_config' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  if (!TWILIO_FROM_NUMBER && !TWILIO_MESSAGING_SERVICE_SID) {
    console.error('[send-phone-otp] Missing TWILIO_FROM_NUMBER or TWILIO_MESSAGING_SERVICE_SID');
    return new Response(JSON.stringify({ error: 'missing_twilio_from' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Normaliser le numéro : doit être au format E.164 (+226XXXXXXXX)
  const normalizedPhone = normalizePhone(phone);
  console.log(`[send-phone-otp] normalized phone=${normalizedPhone}`);

  // Appel Twilio Programmable SMS (pas Verify, pas CustomCode)
  const credentials = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);
  const messagesUrl = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;

  const smsBody = `Votre code de verification Academia est : ${otp}`;

  const params = new URLSearchParams({
    To: normalizedPhone,
    Body: smsBody,
  });
  // Utiliser MessagingServiceSid si disponible, sinon From number
  if (TWILIO_MESSAGING_SERVICE_SID) {
    params.set('MessagingServiceSid', TWILIO_MESSAGING_SERVICE_SID);
  } else {
    params.set('From', TWILIO_FROM_NUMBER);
  }

  let twilioResp: Response;
  try {
    twilioResp = await fetch(messagesUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    });
  } catch (err) {
    console.error('[send-phone-otp] Network error calling Twilio:', err);
    return new Response(JSON.stringify({ error: 'twilio_network_error', details: String(err) }), {
      status: 502,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const twilioData = await twilioResp.json().catch(() => ({}));
  console.log(`[send-phone-otp] Twilio response: status=${twilioResp.status}`, JSON.stringify(twilioData));

  if (!twilioResp.ok) {
    const errCode = (twilioData as Record<string, unknown>).code;
    console.error('[send-phone-otp] Twilio error:', JSON.stringify(twilioData));
    return new Response(
      JSON.stringify({ error: 'twilio_error', code: errCode, details: twilioData }),
      { status: 502, headers: { 'Content-Type': 'application/json' } },
    );
  }

  console.log(`[send-phone-otp] OTP SMS sent successfully to ${normalizedPhone}`);
  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});

// Normalise un numéro vers E.164 en assumant le Burkina Faso (+226) par défaut.
function normalizePhone(raw: string): string {
  let s = raw.replace(/\s+/g, '').replace(/-/g, '');
  if (s.startsWith('+')) return s;
  if (s.startsWith('00')) return '+' + s.slice(2);
  // Numéro Burkina (8 chiffres) sans indicatif
  if (s.length === 8) return '+226' + s;
  // Numéro avec indicatif pays sans '+'
  if (s.length > 8) return '+' + s;
  return s;
}
