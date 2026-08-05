// Academia / Nexiom Group - Module Orientation
// Endpoint POST /orientation-analyser : recoit le profil quiz, appelle Claude via OpenRouter,
// stocke et renvoie la recommandation structuree.
// Pattern LLM aligne sur les edge functions IA existantes (academia-ai-assistant, prep-*, td-*).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY") ?? "";
const OPENROUTER_MODEL = Deno.env.get("OPENROUTER_MODEL") ?? "anthropic/claude-sonnet-4.5";
const OPENROUTER_FALLBACK_MODEL = Deno.env.get("OPENROUTER_FALLBACK_MODEL") ?? "anthropic/claude-3.5-sonnet";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const SYSTEM_PROMPT = `Tu es un conseiller d'orientation pour Academia, la plateforme de la societe
Nexiom Group qui accompagne les etudiants et professionnels du Burkina Faso
et de la diaspora dans leurs projets de formation et de reconversion.

REGLES STRICTES :
- Ne jamais utiliser le terme "bourse d'etude". Utilise "accompagnement",
  "facilitation" ou "orientation".
- Ne jamais promettre une admission garantie ni un tarif precis : Nexiom Group
  est un intermediaire, pas l'organisme de formation.
- Reste factuel, bienveillant, concret. Pas de jargon.
- Reponds UNIQUEMENT en JSON valide, sans texte avant/apres, selon le schema fourni.

Genere une recommandation d'orientation avec :
1. 2 a 3 pistes de formation ou de reconversion adaptees au profil et a l'objectif exprime
2. Pour chaque piste : un score de compatibilite (0-100), une justification de 2-3 phrases
   maximum reprenant des elements precis du profil (grade, experience, objectif), et la duree
   de formation estimee
3. Un court message de synthese personnalise (3 phrases max), en s'adressant directement a l'usager ("tu")

Schema de reponse attendu (JSON strict) :
{
  "synthese": "string",
  "pistes": [
    { "titre": "string", "score_compatibilite": number, "justification": "string", "duree_estimee": "string", "secteur": "string" }
  ]
}`;

function extractJson(text: string): any {
  if (!text) throw new Error("empty LLM content");
  let t = text.trim();
  // retire d'eventuels fences markdown
  t = t.replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
  try { return JSON.parse(t); } catch (_) {}
  const start = t.indexOf("{");
  const end = t.lastIndexOf("}");
  if (start !== -1 && end !== -1 && end > start) {
    return JSON.parse(t.slice(start, end + 1));
  }
  throw new Error("invalid JSON from LLM");
}

async function callLLM(profilPayload: unknown): Promise<{ reco: any; model: string }> {
  const userContent = `Voici le profil de l'usager :\n${JSON.stringify(profilPayload, null, 2)}`;
  const messages = [
    { role: "system", content: SYSTEM_PROMPT },
    { role: "user", content: userContent },
  ];
  const modelsToTry = [OPENROUTER_MODEL, OPENROUTER_FALLBACK_MODEL].filter((m) => m);
  const errors: string[] = [];

  for (const model of modelsToTry) {
    try {
      const resp = await fetch(OPENROUTER_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${OPENROUTER_API_KEY}`,
          "HTTP-Referer": "https://academia-app.nexiomgroup.space",
          "X-Title": "Academia Orientation",
        },
        body: JSON.stringify({
          model,
          messages,
          max_tokens: 1200,
          temperature: 0.5,
          response_format: { type: "json_object" },
        }),
      });
      if (!resp.ok) {
        errors.push(`${model} (${resp.status}): ${(await resp.text()).slice(0, 120)}`);
        continue;
      }
      const data = await resp.json();
      const content = data?.choices?.[0]?.message?.content ?? "";
      const reco = extractJson(content);
      if (!reco?.pistes?.length) { errors.push(`${model}: no pistes`); continue; }
      return { reco, model };
    } catch (e) {
      errors.push(`${model}: ${(e as Error).message}`);
    }
  }
  throw new Error(`All models failed: ${errors.join(" | ")}`);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
    db: { schema: "app" },
    auth: { persistSession: false },
  });

  let insertedId: string | null = null;
  try {
    const body = await req.json().catch(() => ({}));
    const { profil, objectif, source, consent_data } = body ?? {};

    if (!profil || typeof profil !== "object" || !objectif || typeof objectif !== "object") {
      return json({ error: "profil et objectif requis" }, 400);
    }
    if (consent_data !== true) {
      return json({ error: "consentement RGPD requis (consent_data=true)" }, 400);
    }

    // 1) creation de la reponse (statut pending)
    const { data: row, error: insErr } = await supabase
      .from("orientation_responses")
      .insert({
        profil,
        objectif,
        source: source ?? {},
        consent_data: true,
        consent_data_at: new Date().toISOString(),
        status: "pending",
      })
      .select("id, public_slug")
      .single();
    if (insErr) throw new Error(`insert failed: ${insErr.message}`);
    insertedId = row.id;

    // 2) appel LLM
    const { reco, model } = await callLLM({ profil, objectif });

    // 3) piste principale (score max)
    const pistes = Array.isArray(reco.pistes) ? reco.pistes : [];
    const top = pistes.reduce(
      (best: any, p: any) => (p?.score_compatibilite > (best?.score_compatibilite ?? -1) ? p : best),
      null,
    );

    // 4) mise a jour completed
    const { error: updErr } = await supabase
      .from("orientation_responses")
      .update({
        recommandation: reco,
        top_piste_titre: top?.titre ?? null,
        top_score: top?.score_compatibilite ?? null,
        model_used: model,
        status: "completed",
      })
      .eq("id", insertedId);
    if (updErr) throw new Error(`update failed: ${updErr.message}`);

    return json({
      id: insertedId,
      public_slug: row.public_slug,
      recommandation: reco,
      share_url: `https://academiea.com/orientation/resultat/${row.public_slug}`,
    });
  } catch (e) {
    const msg = (e as Error).message;
    console.error("orientation-analyser error:", msg);
    if (insertedId) {
      await supabase.from("orientation_responses")
        .update({ status: "failed", error_detail: msg.slice(0, 500) })
        .eq("id", insertedId);
    }
    return json({ error: "analyse impossible", details: msg }, 502);
  }
});
