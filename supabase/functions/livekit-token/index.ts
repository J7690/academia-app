// Supabase Edge Function: livekit-token
// Generates LiveKit JWT access tokens for authenticated users.
//
// Required Supabase Secrets:
//   LIVEKIT_API_KEY / LIVEKIT_API_SECRET / LIVEKIT_URL
//
// 30/07/2026 — CORRECTIF CONSULTATION :
//   `canPublish` valait `isHost`, donc l'etudiant d'un entretien d'orientation
//   recevait un token en LECTURE SEULE et l'application restait bloquee sur
//   « Activation du micro et de la camera… ». Un entretien est un ECHANGE.
//
// 30/07/2026 — SUPERVISION ADMINISTRATEUR :
//   Un administrateur doit pouvoir entrer dans N'IMPORTE QUELLE seance, qu'il y
//   soit invite ou non, y prendre la parole et la moderer. Il obtient donc
//   toujours le droit de publier et contourne le controle de statut.
//   Les actions de moderation (couper, retirer, arreter) ne passent PAS par ce
//   token : elles sont executees cote serveur par la fonction `livekit-moderate`,
//   qui reverifie le role. Un token client ne porte donc jamais `roomAdmin` :
//   s'il fuitait, il ne donnerait aucun pouvoir d'administration.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

function base64url(data: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < data.byteLength; i++) {
    binary += String.fromCharCode(data[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIVEKIT_API_KEY = Deno.env.get('LIVEKIT_API_KEY') ?? '';
const LIVEKIT_API_SECRET = Deno.env.get('LIVEKIT_API_SECRET') ?? '';
const LIVEKIT_URL = Deno.env.get('LIVEKIT_URL') ?? '';

// Formats d'echange BIDIRECTIONNEL : tout participant y prend la parole.
// Un `course` (un intervenant, N spectateurs) reste reserve a l'hote.
//
// 02/08/2026 — ALIGNEMENT SUR LA CONTRAINTE REELLE.
//   La liste du 30/07 portait quatre valeurs qui n'existent nulle part —
//   'consultation', 'workshop', 'atelier', 'tutoring'. La contrainte
//   app.academia_sessions_session_type_check n'accepte que :
//     course | td | prep_concours | orientation | conference | masterclass |
//     live_pedagogique | revision_collective | exam_blanc | game_challenge
//   et livekit_lookup_session ne renvoie pour l'historique que prep|course|game.
//   Ces quatre valeurs ne pouvaient donc jamais etre atteintes : elles
//   donnaient l'illusion d'une couverture large.
//
//   Dans le meme mouvement, `revision_collective` MANQUAIT — personne ne revise
//   collectivement en silence. Ses participants recevaient un token muet.
//
// Restent volontairement unidirectionnels, l'hote pouvant toujours accorder la
// parole au cas par cas via `livekit-moderate` (action `grant_publish`) :
//   course, conference, masterclass, live_pedagogique, prep_concours — un
//   intervenant s'adresse a une salle ;
//   exam_blanc — le silence fait partie de l'epreuve.
const BIDIRECTIONAL_KINDS = ['orientation', 'td', 'revision_collective'];

// Un defi en mode `duo` est un face-a-face : les deux joueurs se parlent. En
// `solo` il n'y a personne a qui parler. Le mode est porte par la session de
// jeu historique, pas par son type — d'ou ce test separe.
const BIDIRECTIONAL_GAME_MODES = ['duo', 'versus', 'multi'];

const ADMIN_ROLES = ['admin', 'super_admin'];

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

async function hmacSign(secret: string, data: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(data));
  return base64url(new Uint8Array(signature));
}

async function generateLiveKitToken(params: {
  apiKey: string;
  apiSecret: string;
  roomName: string;
  participantIdentity: string;
  participantName: string;
  canPublish: boolean;
  canSubscribe: boolean;
  ttlSeconds: number;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: 'HS256', typ: 'JWT' };

  const payload: Record<string, unknown> = {
    iss: params.apiKey,
    sub: params.participantIdentity,
    name: params.participantName,
    nbf: now,
    exp: now + params.ttlSeconds,
    iat: now,
    jti: crypto.randomUUID(),
    video: {
      roomJoin: true,
      room: params.roomName,
      canPublish: params.canPublish,
      canSubscribe: params.canSubscribe,
      canPublishData: true,
    },
  };

  const encodedHeader = base64url(new TextEncoder().encode(JSON.stringify(header)));
  const encodedPayload = base64url(new TextEncoder().encode(JSON.stringify(payload)));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signature = await hmacSign(params.apiSecret, signingInput);

  return `${signingInput}.${signature}`;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ success: false, error: 'Method not allowed' }, 405);
  }

  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_URL) {
    return jsonResponse({
      success: false,
      error: 'LiveKit non configuré. Contactez l\'administrateur.',
    }, 500);
  }

  const authHeader = req.headers.get('authorization') ?? '';
  const jwt = authHeader.replace('Bearer ', '');

  if (!jwt) {
    return jsonResponse({ success: false, error: 'Non authentifié.' }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);
  if (authError || !user) {
    return jsonResponse({ success: false, error: 'Token invalide.' }, 401);
  }

  // ── Role administrateur ───────────────────────────────────────
  // Meme source de verite que public.app_is_admin_user() : les metadonnees
  // auth.users. Lues ici directement depuis le jeton verifie — aucun aller-retour
  // supplementaire vers la base.
  const metaRole = (
    (user.app_metadata as Record<string, unknown> | null)?.role ??
    (user.user_metadata as Record<string, unknown> | null)?.role ??
    ''
  ).toString().toLowerCase();
  const isAdmin = ADMIN_ROLES.includes(metaRole);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ success: false, error: 'Corps de requête invalide.' }, 400);
  }

  const sessionId = body.session_id as string;
  const sessionSource = (body.session_source as string) ?? 'auto';

  if (!sessionId) {
    return jsonResponse({ success: false, error: 'session_id requis.' }, 400);
  }

  // ── Lookup : table unifiee d'abord, puis tables historiques ────────────
  let sessionData: Record<string, unknown> | null = null;
  let sessionType = 'legacy';
  let isHost = false;
  let roomName = `session_${sessionId}`;

  if (sessionSource !== 'legacy') {
    const { data: unifiedData } = await supabase.rpc(
      'livekit_lookup_academia_session',
      { p_session_id: sessionId, p_user_id: user.id },
    );
    if (unifiedData && typeof unifiedData === 'object') {
      sessionData = unifiedData as Record<string, unknown>;
      sessionType = 'academia';
    }
  }

  if (!sessionData) {
    const { data: legacyData, error: lookupError } = await supabase.rpc(
      'livekit_lookup_session',
      { p_session_id: sessionId },
    );
    if (lookupError || !legacyData) {
      return jsonResponse({ success: false, error: 'Session introuvable.' }, 404);
    }
    sessionData = legacyData as Record<string, unknown>;
    sessionType = (sessionData.session_type as string) ?? 'course';
  }

  // ── Controle de statut ───────────────────────────────────────
  // L'administrateur n'est pas soumis a ce controle : il doit pouvoir entrer
  // dans une seance quel que soit son etat, precisement pour la superviser ou
  // l'arreter.
  const status = sessionData.status as string;
  const allowedStatuses = ['live', 'scheduled', 'active', 'running', 'approved', 'draft'];
  if (!allowedStatuses.includes(status) && !isAdmin) {
    return jsonResponse({
      success: false,
      error: `Session non accessible (statut: ${status}).`,
    }, 403);
  }

  // ── Hote ──────────────────────────────────────────────────
  if (sessionType === 'academia') {
    isHost = user.id === (sessionData.host_id as string);
  } else if (sessionType === 'prep') {
    isHost = user.id === sessionData.teacher_id;
  } else if (sessionType === 'game') {
    isHost = user.id === sessionData.user_id;
  } else {
    isHost = user.id === sessionData.instructor_id;
  }

  // ── Droit de publier ────────────────────────────────────────
  // ATTENTION : quand la session vient de la table unifiee, `sessionType` vaut
  // 'academia' — le vrai format est dans sessionData.session_type
  // ('orientation' | 'td' | 'course'…). C'est LUI qui decide du droit de parole.
  const academiaKind = ((sessionData.session_type as string) ?? '').toLowerCase();
  const legacyKind = sessionType.toLowerCase();
  const gameMode = ((sessionData.mode as string) ?? '').toLowerCase();
  const isBidirectional =
    BIDIRECTIONAL_KINDS.includes(academiaKind) ||
    BIDIRECTIONAL_KINDS.includes(legacyKind) ||
    (legacyKind === 'game' && BIDIRECTIONAL_GAME_MODES.includes(gameMode));
  // L'administrateur doit pouvoir INTERVENIR, pas seulement observer.
  const canPublish = isHost || isAdmin || isBidirectional;
  // Qui a le droit de moderer (couper un micro, retirer quelqu'un, arreter) :
  // l'hote pour SA seance, l'administrateur pour TOUTES.
  const isModerator = isHost || isAdmin;

  if (sessionData.livekit_room_name) {
    roomName = sessionData.livekit_room_name as string;
  }

  const { data: displayNameResult } = await supabase.rpc(
    'livekit_get_user_display_name',
    { p_user_id: user.id },
  );
  const displayName = (displayNameResult as string) ?? user.email ?? user.id;

  const token = await generateLiveKitToken({
    apiKey: LIVEKIT_API_KEY,
    apiSecret: LIVEKIT_API_SECRET,
    roomName,
    participantIdentity: user.id,
    participantName: displayName,
    canPublish,
    canSubscribe: true,
    ttlSeconds: 3600 * 4,
  });

  // ── Enregistrement du participant ──────────────────────────────
  // NB : supabase.rpc() renvoie un PostgrestFilterBuilder « thenable » qui
  // n'expose pas .catch() — l'enchainer leve un TypeError et fait echouer la
  // fonction en 500 alors que le token est deja genere. try/catch obligatoire.
  // Un administrateur en supervision n'est pas inscrit comme participant.
  try {
    if (isAdmin && !isHost) {
      // Supervision : aucune inscription, la presence ne doit pas fausser les
      // statistiques de frequentation de la seance.
    } else if (sessionType === 'academia') {
      // Jointure unifiee — deja faite cote Flutter via app_learning_join_session.
    } else if (sessionType === 'prep') {
      await supabase.rpc('app_prep_student_join_live_session', {
        p_session_id: sessionId,
      });
    } else if (sessionType === 'course') {
      await supabase.rpc('app_register_online_course_live_session_participant', {
        p_session_id: sessionId,
        p_user_id: user.id,
      });
    }
  } catch (e) {
    console.error('[livekit-token] participant registration failed', e);
  }

  return jsonResponse({
    success: true,
    token,
    url: LIVEKIT_URL,
    room_name: roomName,
    identity: user.id,
    display_name: displayName,
    is_host: isHost,
    // Indique a l'application si elle a le droit d'activer micro/camera.
    can_publish: canPublish,
    // Affiche les commandes de moderation cote application.
    is_admin: isAdmin,
    is_moderator: isModerator,
    session_type: sessionType,
    session_kind: academiaKind || legacyKind,
  });
});
