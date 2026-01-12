// ========================================
// ACADEMIA - EDGE FUNCTION
// ENVOI DES NOTIFICATIONS PUSH VIA FCM
// ========================================
// Cette fonction est destinée à être déployée via Supabase CLI.
// Elle lit la file app.notification_events et envoie des push FCM
// aux devices enregistrés dans app.user_device_tokens.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// Supporte deux noms possibles pour le secret du compte de service FCM v1
// 1) FCMServiceAccountJohnson (nom personnalisé initial)
// 2) FCM_SERVICE_ACCOUNT_JSON (nom plus standard)
const FCM_SERVICE_ACCOUNT_JSON =
  Deno.env.get("FCMServiceAccountJohnson") ??
  Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars");
}

type FcmServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

let fcmServiceAccount: FcmServiceAccount | null = null;

if (!FCM_SERVICE_ACCOUNT_JSON) {
  console.error(
    "Missing FCM service account JSON env var (FCMServiceAccountJohnson or FCM_SERVICE_ACCOUNT_JSON)",
  );
} else {
  try {
    const parsed = JSON.parse(FCM_SERVICE_ACCOUNT_JSON) as FcmServiceAccount;
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      console.error(
        "FCM service account JSON is missing project_id, client_email or private_key",
        "FCMServiceAccountJohnson JSON is missing project_id, client_email or private_key",
      );
    } else {
      fcmServiceAccount = parsed;
    }
  } catch (err) {
    console.error("Failed to parse FCMServiceAccountJohnson JSON", err);
  }
}

let cachedAccessToken: string | null = null;
let cachedAccessTokenExpiry: number | null = null;

function base64UrlEncodeBytes(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  const b64 = btoa(binary);
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlEncodeJSON(value: unknown): string {
  const json = JSON.stringify(value);
  const bytes = new TextEncoder().encode(json);
  return base64UrlEncodeBytes(bytes);
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const cleaned = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\r?\n/g, "")
    .trim();
  const binary = atob(cleaned);
  const len = binary.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getFcmAccessToken(): Promise<string> {
  if (!fcmServiceAccount) {
    throw new Error("FCM service account not configured correctly");
  }

  const now = Math.floor(Date.now() / 1000);
  if (
    cachedAccessToken && cachedAccessTokenExpiry &&
    now < (cachedAccessTokenExpiry - 60)
  ) {
    return cachedAccessToken;
  }

  const header = { alg: "RS256", typ: "JWT" };
  const iat = now;
  const exp = iat + 3600; // 1h
  const aud = fcmServiceAccount.token_uri ||
    "https://oauth2.googleapis.com/token";
  const payload = {
    iss: fcmServiceAccount.client_email,
    sub: fcmServiceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud,
    iat,
    exp,
  };

  const unsignedToken =
    `${base64UrlEncodeJSON(header)}.${base64UrlEncodeJSON(payload)}`;

  const keyData = pemToArrayBuffer(fcmServiceAccount.private_key);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedToken),
  );

  const jwt = `${unsignedToken}.${base64UrlEncodeBytes(new Uint8Array(signature))}`;

  const tokenResponse = await fetch(aud, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body:
      `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenBody = await tokenResponse.json();
  if (!tokenResponse.ok) {
    console.error("Failed to obtain FCM access token", tokenBody);
    throw new Error(
      `Failed to obtain FCM access token: ${tokenResponse.status}`,
    );
  }

  const accessToken = tokenBody.access_token as string | undefined;
  const expiresIn = tokenBody.expires_in as number | undefined;
  if (!accessToken) {
    throw new Error("FCM access token missing in response");
  }

  cachedAccessToken = accessToken;
  cachedAccessTokenExpiry = expiresIn
    ? now + Number(expiresIn)
    : now + 3600;

  return accessToken;
}

async function fetchPendingEvents(limit = 100) {
  // Utilise le schéma "app" via l'en-tête Accept-Profile plutôt que dans le chemin
  const url = `${SUPABASE_URL}/rest/v1/notification_events?processed_at=is.null&order=created_at.asc&limit=${limit}`;
  const res = await fetch(url, {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Accept-Profile": "app",
    },
  });
  if (!res.ok) {
    throw new Error(`Failed to fetch notification_events: ${res.status} ${await res.text()}`);
  }
  return await res.json();
}

async function fetchActiveTokens(userId: string) {
  // Table app.user_device_tokens exposée via le schéma "app"
  const url = `${SUPABASE_URL}/rest/v1/user_device_tokens?user_id=eq.${userId}&is_active=eq.true`;
  const res = await fetch(url, {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Accept-Profile": "app",
    },
  });
  if (!res.ok) {
    throw new Error(`Failed to fetch user_device_tokens: ${res.status} ${await res.text()}`);
  }
  return await res.json();
}

async function markProcessed(id: string) {
  const url = `${SUPABASE_URL}/rest/v1/notification_events?id=eq.${id}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
      "Content-Profile": "app",
    },
    body: JSON.stringify({ processed_at: new Date().toISOString(), attempt_count: 1 }),
  });
  if (!res.ok) {
    console.error("Failed to markProcessed", id, await res.text());
  }
}

async function markFailed(id: string, error: unknown) {
  const url = `${SUPABASE_URL}/rest/v1/notification_events?id=eq.${id}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
      "Content-Profile": "app",
    },
    body: JSON.stringify({
      attempt_count: 1,
      last_error: String(error).slice(0, 500),
    }),
  });
  if (!res.ok) {
    console.error("Failed to markFailed", id, await res.text());
  }
}

function buildFcmMessage(event: any) {
  const domain = event.domain as string;
  const type = event.event_type as string;
  const payload = event.payload || {};

  let title = "Academia";
  let body = "";

  if (domain === "student_applications" && type === "message") {
    title = "Nouvelle réponse à ta candidature";
    body = "Un message a été ajouté à ton dossier";
  } else if (domain === "admin_applications" && type === "message") {
    title = "Nouvelle activité sur une candidature";
    body = "Un étudiant a envoyé un message";
  } else if (domain === "student_payments" && type === "payment") {
    title = "Mise à jour de paiement";
    body = "Un paiement ou reçu a été mis à jour";
  } else if (domain === "admin_payments" && type === "payment") {
    title = "Paiement mis à jour";
    body = "Un paiement étudiant a changé de statut";
  } else if (domain === "student_communities" && type === "message") {
    title = "Nouveau message dans tes communautés";
    body = "Une nouvelle publication est disponible";
  } else if (domain === "student_bobodo" && type === "message") {
    title = "Bobodo a répondu";
    body = "Une nouvelle réponse est disponible";
  } else if (domain === "student_opportunities") {
    title = "Nouvelle opportunité";
    body = "Une nouvelle opportunité a été publiée";
  } else if (domain === "student_prep_concours") {
    title = "Nouveau contenu Prépa concours";
    body = "De nouveaux contenus sont disponibles";
  } else if (domain === "admin_opportunities") {
    title = "Opportunités mises à jour";
    body = "Les opportunités ont été modifiées";
  } else if (domain === "admin_communities") {
    title = "Communautés mises à jour";
    body = "De nouvelles publications sont disponibles";
  } else if (domain === "admin_bobodo") {
    title = "Nouvelles activités Bobodo";
    body = "Une nouvelle activité Bobodo est disponible";
  } else if (domain === "admin_prep_concours") {
    title = "Prépa concours mise à jour";
    body = "De nouveaux contenus sont disponibles";
  }

  return {
    notification: {
      title,
      body,
    },
    data: {
      domain,
      event_type: type,
      ...payload,
    },
  };
}

async function sendFcm(token: string, message: { notification: any; data: any }) {
  if (!fcmServiceAccount) {
    throw new Error("FCM service account not configured");
  }

  const accessToken = await getFcmAccessToken();
  const url =
    `https://fcm.googleapis.com/v1/projects/${fcmServiceAccount.project_id}/messages:send`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token,
        notification: message.notification,
        data: message.data,
      },
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("FCM v1 error", res.status, text);
    throw new Error(`FCM v1 error ${res.status}: ${text}`);
  }
}

serve(async (_req) => {
  try {
    const events = await fetchPendingEvents(100);
    for (const event of events) {
      try {
        const tokens = await fetchActiveTokens(event.user_id);
        if (!tokens.length) {
          await markProcessed(event.id);
          continue;
        }

        const msg = buildFcmMessage(event);
        for (const t of tokens) {
          await sendFcm(t.fcm_token, msg);
        }
        await markProcessed(event.id);
      } catch (err) {
        console.error("Error processing event", event.id, err);
        await markFailed(event.id, err);
      }
    }

    return new Response(
      JSON.stringify({ success: true, processed: events.length }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Fatal error in send-push-notifications", err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
