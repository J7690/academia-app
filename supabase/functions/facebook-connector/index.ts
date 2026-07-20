// =============================================================================
// facebook-connector — Edge Function unique routant les 10 actions Facebook.
// POST { "action": "facebook_publish_post", "params": { "message": "..." } }
// Auth : Authorization: Bearer <ACADEMIA_API_TOKEN>
// GET  ?health=1  → { ok: true }
// =============================================================================
import { toolMap, tools } from "./tools.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

function authorized(req: Request): boolean {
  const expected = Deno.env.get("ACADEMIA_API_TOKEN");
  if (!expected) return true; // pas de token configuré → ouvert (à restreindre en prod)
  return req.headers.get("authorization") === `Bearer ${expected}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const url = new URL(req.url);
  if (req.method === "GET") {
    if (url.searchParams.has("health")) return json({ ok: true, service: "facebook-connector" });
    return json({ service: "facebook-connector", actions: tools.map((t) => t.name) });
  }

  if (req.method !== "POST") return json({ error: "Méthode non supportée" }, 405);
  if (!authorized(req)) return json({ error: "Non autorisé" }, 401);

  let payload: { action?: string; params?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "JSON invalide" }, 400);
  }

  const tool = payload.action ? toolMap[payload.action] : undefined;
  if (!tool) {
    return json({ error: `Action inconnue: ${payload.action}`, actions: Object.keys(toolMap) }, 400);
  }

  try {
    const data = await tool.handler(payload.params ?? {});
    return json({ data });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 502);
  }
});
