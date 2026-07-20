// =============================================================================
// facebook-webhook — Webhook Meta (public, verify_jwt=false).
//   GET  : handshake de vérification (hub.challenge)
//   POST : réception des événements (messages, commentaires, réactions, feed)
// Déployée SANS vérification JWT car Meta appelle sans Authorization.
// =============================================================================

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);

  // --- Vérification de l'abonnement (GET) ---
  if (req.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");
    const verifyToken = Deno.env.get("FACEBOOK_VERIFY_TOKEN");

    if (mode === "subscribe" && token && token === verifyToken) {
      return new Response(challenge ?? "", { status: 200 });
    }
    return new Response("Forbidden", { status: 403 });
  }

  // --- Réception des événements (POST) ---
  if (req.method === "POST") {
    let body: {
      object?: string;
      entry?: Array<{
        messaging?: unknown[];
        changes?: Array<{ field?: string; value?: unknown }>;
      }>;
    };
    try {
      body = await req.json();
    } catch {
      return new Response("Bad Request", { status: 400 });
    }

    for (const entry of body.entry ?? []) {
      for (const event of entry.messaging ?? []) {
        console.log("Messenger event:", JSON.stringify(event));
        // TODO: réponse auto / persistance Supabase
      }
      for (const change of entry.changes ?? []) {
        console.log("Feed change:", change.field, JSON.stringify(change.value));
        // TODO: router selon change.field (feed / comments / reactions)
      }
    }
    // Acquitter rapidement (Meta réémet sinon).
    return new Response("EVENT_RECEIVED", { status: 200 });
  }

  return new Response("Method Not Allowed", { status: 405 });
});
