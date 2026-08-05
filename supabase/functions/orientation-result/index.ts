// Academia / Nexiom Group - Module Orientation
// Endpoint GET /orientation-result?slug=XXXX : renvoie la recommandation publique (aucune PII)
// pour la page de partage academiea.com/orientation/resultat/{slug}.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "GET") return json({ error: "method not allowed" }, 405);

  try {
    const url = new URL(req.url);
    const slug = (url.searchParams.get("slug") ?? "").trim();
    if (!slug) return json({ error: "slug requis" }, 400);

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
      db: { schema: "app" },
      auth: { persistSession: false },
    });

    // Fonction filtrante SECURITY DEFINER : ne renvoie que la reco (pas de PII)
    const { data, error } = await supabase.rpc("get_orientation_public_result", { p_slug: slug });
    if (error) throw new Error(error.message);

    const result = Array.isArray(data) ? data[0] : data;
    if (!result) return json({ error: "resultat introuvable" }, 404);

    return json({
      public_slug: result.public_slug,
      recommandation: result.recommandation,
      top_piste_titre: result.top_piste_titre,
      top_score: result.top_score,
      created_at: result.created_at,
    });
  } catch (e) {
    console.error("orientation-result error:", (e as Error).message);
    return json({ error: "lecture impossible", details: (e as Error).message }, 500);
  }
});
