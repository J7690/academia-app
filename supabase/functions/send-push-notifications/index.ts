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
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars");
}

type FcmServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

// FCM service account from environment variables
// Try FCM_SERVICE_ACCOUNT_JSON first (JSON format), fallback to individual variables
const fcmServiceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");

let fcmServiceAccount: FcmServiceAccount;

if (fcmServiceAccountJson) {
  try {
    fcmServiceAccount = JSON.parse(fcmServiceAccountJson);
    console.log("[FCM] Service account loaded from FCM_SERVICE_ACCOUNT_JSON for project:", fcmServiceAccount.project_id);
  } catch (e) {
    console.error("[FCM] ERROR: Failed to parse FCM_SERVICE_ACCOUNT_JSON:", e);
    fcmServiceAccount = {
      project_id: Deno.env.get("FCM_PROJECT_ID") || "academia-e2c41",
      client_email: Deno.env.get("FCM_CLIENT_EMAIL") || "firebase-adminsdk-fbsvc@academia-e2c41.iam.gserviceaccount.com",
      private_key: Deno.env.get("FCM_PRIVATE_KEY") || "",
      token_uri: "https://oauth2.googleapis.com/token",
    };
  }
} else {
  fcmServiceAccount = {
    project_id: Deno.env.get("FCM_PROJECT_ID") || "academia-e2c41",
    client_email: Deno.env.get("FCM_CLIENT_EMAIL") || "firebase-adminsdk-fbsvc@academia-e2c41.iam.gserviceaccount.com",
    private_key: Deno.env.get("FCM_PRIVATE_KEY") || "",
    token_uri: "https://oauth2.googleapis.com/token",
  };
}

if (!fcmServiceAccount.private_key) {
  console.error("[FCM] ERROR: FCM_PRIVATE_KEY environment variable is not set");
  console.error("[FCM] Please set FCM_SERVICE_ACCOUNT_JSON or FCM_PROJECT_ID, FCM_CLIENT_EMAIL, and FCM_PRIVATE_KEY in Supabase Edge Function secrets");
} else {
  console.log("[FCM] Service account loaded for project:", fcmServiceAccount.project_id);
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

async function deactivateToken(tokenId: string) {
  const url = `${SUPABASE_URL}/rest/v1/user_device_tokens?id=eq.${tokenId}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
      "Content-Profile": "app",
    },
    body: JSON.stringify({ is_active: false }),
  });
  if (!res.ok) {
    console.error("Failed to deactivateToken", tokenId, await res.text());
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

  // --- Candidatures ---
  if (domain === "student_applications" && type === "message") {
    title = "💬 Nouvelle réponse à ta candidature";
    body = "Un message a été ajouté à ton dossier";
  } else if (domain === "admin_applications" && type === "message") {
    title = "Nouvelle activité sur une candidature";
    body = "Un étudiant a envoyé un message";

  // --- Paiements étudiant (statut précis) ---
  } else if (domain === "student_payments" && type === "payment_status_changed") {
    const newStatus = payload.new_status || "";
    const reasonLabel = payload.reason_label || payload.payment_reason || "";
    const programName = payload.program_name || "";
    const refCode = payload.reference_code || "";
    if (newStatus === "confirmed") {
      title = "✅ Paiement confirmé !";
      body = reasonLabel ? `${reasonLabel} confirmé` + (programName ? ` — ${programName}` : "") : "Ton paiement a été confirmé";
    } else if (newStatus === "rejected") {
      title = "❌ Paiement rejeté";
      body = reasonLabel ? `${reasonLabel} rejeté` + (refCode ? ` (réf. ${refCode})` : "") : "Ton paiement a été rejeté. Contacte l'administration.";
    } else if (newStatus === "under_verification") {
      title = "🔍 Paiement en vérification";
      body = reasonLabel ? `${reasonLabel} est en cours de vérification` : "Ton paiement est en cours de vérification";
    } else {
      title = "💳 Mise à jour de paiement";
      body = "Le statut de ton paiement a changé";
    }
  } else if (domain === "student_payments") {
    title = "💳 Paiement";
    body = "Une mise à jour sur tes paiements";

  // --- Communautés ---
  } else if (domain === "student_communities" && type === "message") {
    title = "👥 Nouveau dans tes communautés";
    body = "Une nouvelle publication est disponible";

  // --- Bobodo ---
  } else if (domain === "student_bobodo" && type === "message") {
    title = "🤖 Bobodo a répondu";
    body = "Une nouvelle réponse est disponible";

  // --- Opportunités ---
  } else if (domain === "student_opportunities" && type === "new_opportunity") {
    const oppTitle = payload.title || "";
    title = "🔥 Nouvelle opportunité !";
    body = oppTitle ? `${oppTitle}` : "Une nouvelle opportunité a été publiée";
  } else if (domain === "student_opportunities" && type === "opportunity_comment") {
    const oppTitle = payload.opportunity_title || "";
    title = "💬 Nouveau commentaire";
    body = oppTitle ? `Commentaire sur : ${oppTitle}` : "Un commentaire a été ajouté à une opportunité";
  } else if (domain === "student_opportunities") {
    title = "📢 Opportunités";
    body = "De nouvelles opportunités sont disponibles";

  // --- Marketplace (inquiries + review) ---
  } else if (domain === "marketplace_inquiries" && type === "message") {
    title = "💬 Nouveau message (Marketplace)";
    body = "Vous avez un nouveau message sur une demande";
  } else if (domain === "marketplace_opportunities" && type === "review") {
    const reviewStatus = payload.review_status || "";
    if (reviewStatus === "approved") {
      title = "✅ Annonce approuvée";
      body = "Votre annonce a été approuvée et publiée";
    } else if (reviewStatus === "rejected") {
      title = "❌ Annonce rejetée";
      body = payload.review_reason
        ? `Motif: ${payload.review_reason}`
        : "Votre annonce a été rejetée";
    } else {
      title = "📌 Mise à jour annonce";
      body = "Le statut de votre annonce a changé";
    }

  // --- Universités (news + events) ---
  } else if (domain === "student_universities" && type === "university_news") {
    const uniName = payload.university_name || "";
    const newsTitle = payload.news_title || "";
    title = `🏫 ${uniName || "Université"} — Actualité`;
    body = newsTitle || "Une nouvelle actualité est disponible";
  } else if (domain === "student_universities" && type === "university_event") {
    const uniName = payload.university_name || "";
    const eventTitle = payload.event_title || "";
    title = `📅 ${uniName || "Université"} — Événement`;
    body = eventTitle || "Un nouvel événement est programmé";
  } else if (domain === "student_universities") {
    title = "🏫 Actualité universitaire";
    body = "Du nouveau dans tes universités";

  // --- Annonces officielles ---
  } else if (domain === "student_announcements") {
    const annTitle = payload.title || "";
    const urgency = payload.urgency || "normal";
    title = urgency === "critical" ? "🚨 Annonce importante !" : "📣 Annonce officielle";
    body = annTitle || "Une nouvelle annonce est disponible";

  // --- Challenges ---
  } else if (domain === "student_challenges") {
    const chalTitle = payload.title || "";
    title = "🏆 Nouveau challenge !";
    body = chalTitle || "Un nouveau challenge est disponible";

  // --- Cours en ligne ---
  } else if (domain === "student_online_courses" && type === "new_course") {
    const courseTitle = payload.title || "";
    title = "📚 Nouveau cours disponible";
    body = courseTitle || "Un nouveau cours en ligne a été ajouté";
  } else if (domain === "student_online_courses" && type === "new_lesson") {
    const courseTitle = payload.course_title || "";
    const lessonTitle = payload.lesson_title || "";
    title = `📖 Nouvelle leçon — ${courseTitle || "Cours"}`;
    body = lessonTitle || "Une nouvelle leçon est disponible";
  } else if (domain === "student_online_courses") {
    title = "📚 Cours en ligne";
    body = "Du nouveau dans tes cours";

  // --- Lives ---
  } else if (domain === "student_lives") {
    const courseTitle = payload.course_title || "";
    const sessionTitle = payload.session_title || "";
    title = `🔴 Live en direct — ${courseTitle || "Cours"}`;
    body = sessionTitle || "Une session live commence bientôt !";

  // --- Formations courtes (TD) ---
  } else if (domain === "student_short_trainings" && type === "new_training") {
    const trainingTitle = payload.title || "";
    title = "🎓 Nouvelle formation courte";
    body = trainingTitle || "Une nouvelle formation est disponible";
  } else if (domain === "student_short_trainings" && type === "new_session") {
    const trainingTitle = payload.training_title || "";
    title = `🎓 Nouvelle session — ${trainingTitle || "Formation"}`;
    body = "Une nouvelle session de formation est ouverte";
  } else if (domain === "student_short_trainings") {
    title = "🎓 Formations";
    body = "Du nouveau dans tes formations";

  // --- Accueil étudiant ---
  } else if (domain === "student_home") {
    title = "🏠 Nouveau contenu";
    body = "Du nouveau sur ton accueil Academia";

  // --- Prépa concours ---
  } else if (domain === "student_prep_concours") {
    title = "📝 Prépa concours";
    body = "De nouveaux contenus sont disponibles";

  // --- Admin: comptes ---
  } else if (domain === "admin_accounts" && type === "new_account") {
    const role = payload.role || "";
    const email = payload.email || "";
    title = "👤 Nouveau compte créé";
    body = `${role} — ${email}`;

  // --- Admin: candidatures ---
  } else if (domain === "admin_applications" && type === "new_application") {
    const studentName = payload.student_name || "";
    const programName = payload.program_name || "";
    title = "📋 Nouvelle candidature";
    body = studentName ? `${studentName} → ${programName || "programme"}` : "Un étudiant a soumis une candidature";
  } else if (domain === "admin_applications" && type === "message") {
    const senderRole = payload.sender_role || "";
    title = "💬 Message candidature";
    body = senderRole === "student" ? "Un étudiant a envoyé un message" : senderRole === "university" ? "Une université a répondu" : "Nouveau message sur une candidature";
  } else if (domain === "admin_applications") {
    title = "📋 Candidatures";
    body = "Nouvelle activité sur les candidatures";

  // --- Admin: paiements (enrichi) ---
  } else if (domain === "admin_payments") {
    const studentName = payload.student_name || "";
    const status = payload.status || "";
    const reasonLabel = payload.reason_label || "";
    const programName = payload.program_name || "";
    const statusLabel = status === "declared_by_student" ? "déclaré" : status === "confirmed" ? "confirmé" : status === "rejected" ? "rejeté" : status === "under_verification" ? "en vérification" : status;
    if (status === "declared_by_student") {
      title = "💰 Paiement déclaré";
      body = studentName ? `${studentName} a déclaré un paiement` + (reasonLabel ? ` (${reasonLabel})` : "") : "Un étudiant a déclaré un paiement";
    } else if (status === "confirmed") {
      title = "✅ Paiement confirmé";
      body = studentName ? `${studentName} — ${reasonLabel || "paiement"} confirmé` : "Un paiement a été confirmé";
    } else {
      title = "💰 Paiement";
      body = studentName ? `${studentName} — ${statusLabel}` + (reasonLabel ? ` (${reasonLabel})` : "") : "Un paiement a été mis à jour";
    }

  // --- Admin: challenges ---
  } else if (domain === "admin_challenges") {
    title = "🏆 Participation challenge";
    body = payload.challenge_title || "Un étudiant a participé à un challenge";

  // --- Admin: formations courtes ---
  } else if (domain === "admin_short_trainings") {
    title = "🎓 Inscription formation";
    body = payload.training_title ? `Inscription à : ${payload.training_title}` : "Nouvelle inscription à une formation";

  // --- Admin: cours en ligne ---
  } else if (domain === "admin_online_courses") {
    title = "📚 Inscription cours";
    body = payload.course_title ? `Inscription à : ${payload.course_title}` : "Nouvelle inscription à un cours";

  // --- Admin: TD ---
  } else if (domain === "admin_td" && type === "new_request") {
    title = "📝 Demande TD";
    body = "Un étudiant a fait une demande de TD";
  } else if (domain === "admin_td" && type === "new_message") {
    title = "💬 Message TD";
    body = "Nouveau message dans un TD";
  } else if (domain === "admin_td") {
    title = "📝 TD";
    body = "Nouvelle activité TD";

  // --- Admin: communautés ---
  } else if (domain === "admin_communities" && type === "join_request") {
    title = "👥 Demande communauté";
    body = payload.community_name ? `Demande pour : ${payload.community_name}` : "Demande d'adhésion à une communauté";
  } else if (domain === "admin_communities") {
    title = "👥 Communautés";
    body = "Nouvelle activité dans les communautés";

  // --- Admin: marketplace ---
  } else if (domain === "admin_marketplace") {
    title = "🛒 Nouvelle commande";
    body = "Un étudiant a passé une commande";

  // --- Admin: opportunités ---
  } else if (domain === "admin_opportunities" && type === "new_application") {
    title = "📢 Candidature opportunité";
    body = payload.opportunity_title ? `Candidature sur : ${payload.opportunity_title}` : "Un étudiant a postulé à une opportunité";
  } else if (domain === "admin_opportunities") {
    title = "📢 Opportunités";
    body = "Nouvelle activité sur les opportunités";

  // --- Admin: support (URGENT) ---
  } else if (domain === "admin_support" && type === "new_message") {
    const requesterName = payload.requester_name || "Un utilisateur";
    const preview = payload.content_preview || "";
    title = "🚨 SUPPORT URGENT";
    body = preview ? `${requesterName}: ${preview}` : `${requesterName} a envoyé un message support`;
  } else if (domain === "admin_support" && type === "new_conversation") {
    const requesterName = payload.requester_name || "Un utilisateur";
    const requesterRole = payload.requester_role || "";
    title = "🚨 NOUVELLE DEMANDE SUPPORT";
    body = `${requesterName} (${requesterRole}) a ouvert une conversation support`;
  } else if (domain === "admin_support") {
    title = "🚨 Support";
    body = "Nouvelle activité support — répondez rapidement !";

  // --- Admin: bobodo ---
  } else if (domain === "admin_bobodo") {
    title = "🤖 Bobodo";
    body = "Nouvelle activité Bobodo";

  // --- Admin: prépa concours ---
  } else if (domain === "admin_prep_concours") {
    title = "📝 Prépa concours";
    body = "De nouveaux contenus sont disponibles";

  // --- University: candidatures ---
  } else if (domain === "university_applications" && type === "new_application") {
    const studentName = payload.student_name || "";
    const programName = payload.program_name || "";
    title = "📋 Nouvelle candidature";
    body = studentName ? `${studentName} → ${programName || "votre programme"}` : "Un étudiant a candidaté à votre programme";
  } else if (domain === "university_applications" && type === "message") {
    title = "💬 Message candidature";
    body = payload.sender_role === "student" ? "Un étudiant a envoyé un message" : "Nouveau message sur une candidature";
  } else if (domain === "university_applications") {
    title = "📋 Candidatures";
    body = "Nouvelle activité sur vos candidatures";

  // --- University: paiements (enrichi) ---
  } else if (domain === "university_payments") {
    const studentName = payload.student_name || "";
    const status = payload.status || "";
    const reasonLabel = payload.reason_label || "";
    const programName = payload.program_name || "";
    if (status === "confirmed") {
      title = "✅ Paiement confirmé";
      body = studentName ? `${studentName} a réglé : ${reasonLabel || "paiement"}` + (programName ? ` — ${programName}` : "") : "Un paiement étudiant a été confirmé";
    } else if (status === "declared_by_student") {
      title = "💰 Paiement déclaré";
      body = studentName ? `${studentName} a déclaré : ${reasonLabel || "paiement"}` : "Un étudiant a déclaré un paiement";
    } else {
      title = "💰 Paiement";
      body = studentName ? `${studentName} — ${reasonLabel || "paiement"}` : "Un paiement étudiant a été mis à jour";
    }

  // --- Instructor: TD ---
  } else if (domain === "instructor_td" && type === "new_message") {
    title = "💬 Message TD";
    body = "Un étudiant vous a envoyé un message";
  } else if (domain === "instructor_td" && type === "new_enrollment") {
    title = "👨‍🎓 Nouvel élève TD";
    body = "Un nouvel élève vous a été assigné";
  } else if (domain === "instructor_td") {
    title = "📝 TD";
    body = "Nouvelle activité dans vos TD";

  // --- Instructor: cours en ligne ---
  } else if (domain === "instructor_courses" && type === "new_enrollment") {
    const courseTitle = payload.course_title || "";
    title = "👨‍🎓 Nouvel inscrit";
    body = courseTitle ? `Inscription à : ${courseTitle}` : "Un étudiant s'est inscrit à votre cours";
  } else if (domain === "instructor_courses" && type === "forum_message") {
    const courseTitle = payload.course_title || "";
    title = `💬 Forum — ${courseTitle || "Cours"}`;
    body = "Un étudiant a posté dans le forum";
  } else if (domain === "instructor_courses") {
    title = "📚 Cours";
    body = "Nouvelle activité dans vos cours";

  // --- Commercial: prospect payments ---
  } else if (domain === "commercial_prospect_payments" && type === "prospect_declared_payment") {
    const studentName = payload.student_name || "";
    const reasonLabel = payload.reason_label || "";
    const programName = payload.program_name || "";
    title = "💰 Prospect a payé !";
    body = studentName ? `${studentName} a déclaré : ${reasonLabel || "paiement"}` + (programName ? ` — ${programName}` : "") : "Un de vos prospects a déclaré un paiement";
  } else if (domain === "commercial_prospect_payments" && type === "prospect_payment_confirmed") {
    const studentName = payload.student_name || "";
    const reasonLabel = payload.reason_label || payload.payment_reason || "";
    title = "✅ Paiement prospect confirmé !";
    body = studentName ? `Le paiement de ${studentName} a été confirmé` : "Le paiement d'un prospect a été confirmé";
  } else if (domain === "commercial_prospect_payments") {
    title = "💰 Activité prospect";
    body = "Nouvelle activité de paiement d'un prospect";

  // --- Commercial: parrainages ---
  } else if (domain === "commercial_referrals") {
    title = "🤝 Nouveau parrainage";
    body = "Un nouvel étudiant a été parrainé";

  // --- Commercial: commissions ---
  } else if (domain === "commercial_commissions") {
    const amount = payload.commission_amount || "";
    const currency = payload.currency || "XOF";
    title = "💵 Nouvelle commission";
    body = amount ? `Commission de ${amount} ${currency} générée` : "Vous avez reçu une nouvelle commission";

  // --- Admin : digest d'activité / parcours utilisateurs ---
  } else if (domain === "admin_audience") {
    const visitors = Number(payload.visitors || 0);
    const offerViews = Number(payload.offer_views || 0);
    const mins = payload.window_minutes || 15;
    title = "📊 Activité sur Academia";
    const parts: string[] = [];
    parts.push(`${visitors} visiteur${visitors > 1 ? "s" : ""}`);
    if (offerViews > 0) parts.push(`${offerViews} consultation${offerViews > 1 ? "s" : ""} d'offres`);
    body = `${parts.join(" · ")} (${mins} dernières min)`;
  }

  return {
    notification: {
      title,
      body,
    },
    data: Object.fromEntries(
      Object.entries({ domain, event_type: type, ...payload })
        .map(([k, v]) => [k, String(v ?? "")])
    ),
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
        android: {
          priority: "HIGH",
          notification: {
            channel_id: "academia_default",
            notification_count: 1,
            sound: "default",
            default_vibrate_timings: true,
            default_light_settings: true,
            visibility: "PUBLIC",
            notification_priority: "PRIORITY_MAX",
          },
        },
      },
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("FCM v1 error", res.status, text);
    // Return error info instead of throwing so caller can handle UNREGISTERED tokens
    return { ok: false, status: res.status, text, token };
  }
  return { ok: true, status: res.status, text: "", token };
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
        let anySent = false;
        for (const t of tokens) {
          const result = await sendFcm(t.fcm_token, msg);
          if (result.ok) {
            anySent = true;
          } else if (result.status === 404 || result.text.includes("UNREGISTERED") || result.text.includes("NOT_FOUND")) {
            // Token expired/unregistered — deactivate it
            console.log(`[PUSH] Deactivating expired token ${t.fcm_token.substring(0, 20)}... for user ${event.user_id}`);
            await deactivateToken(t.id);
          } else {
            console.error(`[PUSH] FCM error for event ${event.id}:`, result.status, result.text.substring(0, 200));
          }
        }
        // Always mark as processed (avoid infinite retry on permanent errors)
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
