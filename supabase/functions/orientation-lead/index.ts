// Academia / Nexiom Group - Module Orientation
// Endpoint POST /orientation-lead : capture d'un lead commercial ("etre recontacte").
// Alimente app.orientation_leads (pipeline commercial Nexiom Group).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const PHONE_RE = /^[+0-9 ().-]{6,20}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  try {
    const body = await req.json().catch(() => ({}));
    const {
      orientation_id, public_slug, full_name, phone, email,
      preferred_channel, message, consent_contact, source,
    } = body ?? {};

    if (consent_contact !== true) return json({ error: "consentement contact requis" }, 400);
    if (!phone && !email) return json({ error: "telephone ou email requis" }, 400);
    if (phone && !PHONE_RE.test(String(phone))) return json({ error: "telephone invalide" }, 400);
    if (email && !EMAIL_RE.test(String(email))) return json({ error: "email invalide" }, 400);
    if (preferred_channel && !["phone", "whatsapp", "email"].includes(preferred_channel)) {
      return json({ error: "canal invalide" }, 400);
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
      db: { schema: "app" },
      auth: { persistSession: false },
    });

    // Resolution de l'orientation_id via le slug si non fourni
    let oid: string | null = orientation_id ?? null;
    if (!oid && public_slug) {
      const { data: r } = await supabase
        .from("orientation_responses").select("id").eq("public_slug", public_slug).maybeSingle();
      oid = r?.id ?? null;
    }

    const { data, error } = await supabase
      .from("orientation_leads")
      .insert({
        orientation_id: oid,
        full_name: full_name ?? null,
        phone: phone ?? null,
        email: email ?? null,
        preferred_channel: preferred_channel ?? null,
        message: message ?? null,
        consent_contact: true,
        source: source ?? {},
        status: "new",
      })
      .select("id")
      .single();
    if (error) throw new Error(error.message);

    return json({ ok: true, lead_id: data.id });
  } catch (e) {
    console.error("orientation-lead error:", (e as Error).message);
    return json({ error: "enregistrement impossible", details: (e as Error).message }, 500);
  }
});
