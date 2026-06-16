// ========================================
// ACADEMIA - EDGE FUNCTION SQUELETTE
// ENVOI DES NOTIFICATIONS PUSH VIA FCM
// ========================================

// Ce fichier est un squelette TypeScript/Deno destiné à être
// copié/collé dans une Edge Function Supabase.
// Il s'appuie sur les tables app.notification_events et app.user_device_tokens
// définies dans sql_changes/20260101_push_notifications_arch.sql.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars");
}

if (!FCM_SERVER_KEY) {
  console.error("Missing FCM_SERVER_KEY env var (clé serveur Firebase)");
}

async function fetchPendingEvents(limit = 100) {
  const url = `${SUPABASE_URL}/rest/v1/app.notification_events?processed_at=is.null&order=created_at.asc&limit=${limit}`;
  const res = await fetch(url, {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
  });
  if (!res.ok) {
    throw new Error(`Failed to fetch notification_events: ${res.status} ${await res.text()}`);
  }
  return await res.json();
}

async function fetchActiveTokens(userId: string) {
  const url = `${SUPABASE_URL}/rest/v1/app.user_device_tokens?user_id=eq.${userId}&is_active=eq.true`;
  const res = await fetch(url, {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
  });
  if (!res.ok) {
    throw new Error(`Failed to fetch user_device_tokens: ${res.status} ${await res.text()}`);
  }
  return await res.json();
}

async function markProcessed(id: string) {
  const url = `${SUPABASE_URL}/rest/v1/app.notification_events?id=eq.${id}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify({ processed_at: new Date().toISOString(), attempt_count: 1 }),
  });
  if (!res.ok) {
    console.error("Failed to markProcessed", id, await res.text());
  }
}

async function markFailed(id: string, error: unknown) {
  const url = `${SUPABASE_URL}/rest/v1/app.notification_events?id=eq.${id}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
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
  const res = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify({
      to: token,
      notification: message.notification,
      data: message.data,
    }),
  });

  if (!res.ok) {
    throw new Error(`FCM error ${res.status}: ${await res.text()}`);
  }
}

serve(async (req) => {
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
    console.error("Fatal error in edge_send_push_notifications", err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
