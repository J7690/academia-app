// =============================================================================
// academia-mcp — Serveur MCP HTTP (JSON-RPC 2.0) + mini-serveur OAuth 2.1.
//
// Pourquoi l'OAuth ? Le connecteur personnalisé de Claude EXIGE un flux OAuth
// pour les serveurs MCP distants HTTP (bug connu : pas d'option "no auth").
// On implémente donc un OAuth minimal à AUTO-APPROBATION : n'importe quel client
// obtient un jeton (même niveau d'ouverture qu'un endpoint public), ce qui
// satisfait Claude sans imposer d'écran de connexion.
//
// Routes (toutes sous /functions/v1/academia-mcp) :
//   (racine)                                  → MCP JSON-RPC (POST) / info (GET)
//   /.well-known/oauth-protected-resource     → métadonnées ressource
//   /.well-known/oauth-authorization-server   → métadonnées serveur d'autorisation
//   /register                                 → enregistrement dynamique (DCR)
//   /authorize                                → auto-approbation (redirige avec code)
//   /token                                    → délivre l'access token
// =============================================================================
import { toolMap, tools } from "./tools.ts";

const PROTOCOL_DEFAULT = "2025-06-18";
const SERVER_INFO = { name: "academia-mcp", version: "0.2.0" };
const ISSUED_TOKEN = "academia_mcp_access_token";
const AUTH_CODE = "academia_mcp_auth_code";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, mcp-session-id, mcp-protocol-version",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

// --------------------------------------------------------------------------
// JSON-RPC (MCP)
// --------------------------------------------------------------------------
interface RpcReq {
  jsonrpc: "2.0";
  id?: string | number | null;
  method?: string;
  params?: Record<string, unknown>;
}

function rpcResult(id: RpcReq["id"], result: unknown): Response {
  return json({ jsonrpc: "2.0", id: id ?? null, result });
}
function rpcError(id: RpcReq["id"], code: number, message: string): Response {
  return json({ jsonrpc: "2.0", id: id ?? null, error: { code, message } });
}

async function handleRpc(msg: RpcReq): Promise<Response | null> {
  const id = msg.id;
  const method = msg.method ?? "";
  const params = msg.params;

  switch (method) {
    case "initialize":
      return rpcResult(id, {
        protocolVersion: (params?.protocolVersion as string) ?? PROTOCOL_DEFAULT,
        capabilities: { tools: { listChanged: false } },
        serverInfo: SERVER_INFO,
      });
    case "ping":
      return rpcResult(id, {});
    case "tools/list":
      return rpcResult(id, {
        tools: tools.map((t) => ({ name: t.name, description: t.description, inputSchema: t.inputSchema })),
      });
    case "tools/call": {
      const name = params?.name as string;
      const args = (params?.arguments as Record<string, unknown>) ?? {};
      const tool = toolMap[name];
      if (!tool) return rpcError(id, -32602, `Outil inconnu: ${name}`);
      try {
        const data = await tool.handler(args);
        return rpcResult(id, { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] });
      } catch (e) {
        return rpcResult(id, {
          content: [{ type: "text", text: `Erreur: ${e instanceof Error ? e.message : String(e)}` }],
          isError: true,
        });
      }
    }
    default:
      if (id === undefined || id === null || method.startsWith("notifications/")) return null;
      return rpcError(id, -32601, `Méthode non supportée: ${method}`);
  }
}

// --------------------------------------------------------------------------
// Serveur
// --------------------------------------------------------------------------
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const url = new URL(req.url);
  const marker = "/academia-mcp";
  const idx = url.pathname.indexOf(marker);
  const sub = url.pathname.slice(idx + marker.length).replace(/\/+$/, ""); // "" = racine
  // URL publique externe (l'edge function voit une adresse interne http :
  // on force https + le préfixe /functions/v1 pour annoncer les bons endpoints).
  const base = `https://${url.host}/functions/v1/academia-mcp`;

  // ---- Métadonnées OAuth (découverte) ----
  if (sub === "/.well-known/oauth-protected-resource") {
    return json({ resource: base, authorization_servers: [base] });
  }
  if (sub === "/.well-known/oauth-authorization-server") {
    return json({
      issuer: base,
      authorization_endpoint: `${base}/authorize`,
      token_endpoint: `${base}/token`,
      registration_endpoint: `${base}/register`,
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code"],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: ["none"],
      scopes_supported: ["mcp"],
    });
  }

  // ---- Enregistrement dynamique du client (DCR) ----
  if (sub === "/register" && req.method === "POST") {
    let body: { redirect_uris?: string[]; client_name?: string } = {};
    try {
      body = await req.json();
    } catch { /* corps optionnel */ }
    return json(
      {
        client_id: "academia-mcp-client",
        client_name: body.client_name ?? "Academia",
        redirect_uris: body.redirect_uris ?? [],
        grant_types: ["authorization_code"],
        response_types: ["code"],
        token_endpoint_auth_method: "none",
      },
      201,
    );
  }

  // ---- Autorisation : auto-approbation → redirection avec code ----
  if (sub === "/authorize" && req.method === "GET") {
    const redirect = url.searchParams.get("redirect_uri");
    const state = url.searchParams.get("state");
    if (!redirect) return json({ error: "invalid_request", error_description: "redirect_uri requis" }, 400);
    const loc = new URL(redirect);
    loc.searchParams.set("code", AUTH_CODE);
    if (state) loc.searchParams.set("state", state);
    return new Response(null, { status: 302, headers: { Location: loc.toString(), ...CORS } });
  }

  // ---- Token : délivre l'access token ----
  if (sub === "/token" && req.method === "POST") {
    return json({ access_token: ISSUED_TOKEN, token_type: "Bearer", expires_in: 31536000, scope: "mcp" });
  }

  // ---- Endpoint MCP (racine) ----
  if (sub === "") {
    if (req.method === "GET") {
      return json({ service: "academia-mcp", transport: "streamable-http", tools: tools.length });
    }
    if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405, headers: CORS });

    let payload: RpcReq | RpcReq[];
    try {
      payload = await req.json();
    } catch {
      return rpcError(null, -32700, "Parse error");
    }
    if (Array.isArray(payload)) {
      const responses: unknown[] = [];
      for (const msg of payload) {
        const res = await handleRpc(msg);
        if (res) responses.push(JSON.parse(await res.text()));
      }
      if (responses.length === 0) return new Response(null, { status: 202, headers: CORS });
      return json(responses);
    }
    const res = await handleRpc(payload);
    if (!res) return new Response(null, { status: 202, headers: CORS });
    return res;
  }

  return new Response("Not Found", { status: 404, headers: CORS });
});
