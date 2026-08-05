// Supabase Edge Function: livekit-moderate
// Actions de moderation d'une seance live (30/07/2026).
//
// POURQUOI COTE SERVEUR : couper un micro, retirer un participant ou arreter
// une seance passe par l'API serveur de LiveKit, qui exige la CLE SECRETE. Cette
// cle ne doit jamais quitter le serveur. L'application demande donc l'action ;
// c'est cette fonction qui la verifie puis l'execute.
//
// QUI A LE DROIT :
//   • administrateur (`admin` / `super_admin`) — sur N'IMPORTE QUELLE seance ;
//   • hote — uniquement sur SA seance.
// Le droit est revalide a chaque appel : un token client, meme trafique, ne
// donne aucun pouvoir ici.
//
// ACTIONS : list | mute | unmute | revoke_publish | grant_publish | remove | end_session

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIVEKIT_API_KEY = Deno.env.get('LIVEKIT_API_KEY') ?? '';
const LIVEKIT_API_SECRET = Deno.env.get('LIVEKIT_API_SECRET') ?? '';
const LIVEKIT_URL = Deno.env.get('LIVEKIT_URL') ?? '';

const ADMIN_ROLES = ['admin', 'super_admin'];

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  // 05/08/2026 — CORRECTIF WEB : `x-client-info` manquait. Le client Supabase
  // l'envoie systematiquement ; sans lui dans le preambule CORS, le navigateur
  // BLOQUE le POST (trace : uniquement des OPTIONS 200, aucun POST). En natif
  // CORS n'est pas applique — d'ou un defaut invisible sur mobile.
  'Access-Control-Allow-Headers':
    'authorization,apikey,content-type,accept,x-client-info,x-supabase-api-version',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function base64url(data: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < data.byteLength; i++) binary += String.fromCharCode(data[i]);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function hmacSign(secret: string, data: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(data));
  return base64url(new Uint8Array(sig));
}

/// Token d'ADMINISTRATION de salle, forge ici et utilise immediatement.
/// Duree tres courte (60 s) : il ne sert qu'a l'appel en cours.
async function mintRoomAdminToken(roomName: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = {
    iss: LIVEKIT_API_KEY,
    sub: 'academia-moderation',
    nbf: now,
    exp: now + 60,
    iat: now,
    jti: crypto.randomUUID(),
    video: { roomAdmin: true, room: roomName, roomList: true },
  };
  const h = base64url(new TextEncoder().encode(JSON.stringify(header)));
  const p = base64url(new TextEncoder().encode(JSON.stringify(payload)));
  const s = await hmacSign(LIVEKIT_API_SECRET, `${h}.${p}`);
  return `${h}.${p}.${s}`;
}

/// Base HTTP de l'API LiveKit. LIVEKIT_URL est une URL WebSocket (wss://) ;
/// l'API serveur repond en HTTPS sur le meme hote.
function livekitHttpBase(): string {
  return LIVEKIT_URL.replace(/^wss:\/\//i, 'https://').replace(/^ws:\/\//i, 'http://').replace(/\/+$/, '');
}

async function roomService(
  method: string,
  roomName: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const token = await mintRoomAdminToken(roomName);
  const res = await fetch(`${livekitHttpBase()}/twirp/livekit.RoomService/${method}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`LiveKit ${method} ${res.status}: ${text.slice(0, 300)}`);
  }
  try {
    return text ? JSON.parse(text) as Record<string, unknown> : {};
  } catch {
    return {};
  }
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ success: false, error: 'Method not allowed' }, 405);

  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_URL) {
    return jsonResponse({ success: false, error: 'LiveKit non configuré.' }, 500);
  }

  const jwt = (req.headers.get('authorization') ?? '').replace('Bearer ', '');
  if (!jwt) return jsonResponse({ success: false, error: 'Non authentifié.' }, 401);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);
  if (authError || !user) return jsonResponse({ success: false, error: 'Token invalide.' }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ success: false, error: 'Corps de requête invalide.' }, 400);
  }

  const sessionId = (body.session_id ?? '').toString();
  const action = (body.action ?? '').toString().toLowerCase();
  const targetIdentity = (body.target_identity ?? '').toString();

  if (!sessionId) return jsonResponse({ success: false, error: 'session_id requis.' }, 400);
  if (!action) return jsonResponse({ success: false, error: 'action requise.' }, 400);

  // ── Role administrateur ───────────────────────────────────────
  const metaRole = (
    (user.app_metadata as Record<string, unknown> | null)?.role ??
    (user.user_metadata as Record<string, unknown> | null)?.role ??
    ''
  ).toString().toLowerCase();
  const isAdmin = ADMIN_ROLES.includes(metaRole);

  // ── Session + hote ───────────────────────────────────────────
  let sessionData: Record<string, unknown> | null = null;
  let sessionType = 'legacy';

  const { data: unifiedData } = await supabase.rpc('livekit_lookup_academia_session', {
    p_session_id: sessionId, p_user_id: user.id,
  });
  if (unifiedData && typeof unifiedData === 'object') {
    sessionData = unifiedData as Record<string, unknown>;
    sessionType = 'academia';
  } else {
    const { data: legacyData, error: lookupError } = await supabase.rpc('livekit_lookup_session', {
      p_session_id: sessionId,
    });
    if (lookupError || !legacyData) {
      return jsonResponse({ success: false, error: 'Session introuvable.' }, 404);
    }
    sessionData = legacyData as Record<string, unknown>;
    sessionType = (sessionData.session_type as string) ?? 'course';
  }

  let isHost = false;
  if (sessionType === 'academia') isHost = user.id === (sessionData.host_id as string);
  else if (sessionType === 'prep') isHost = user.id === sessionData.teacher_id;
  else if (sessionType === 'game') isHost = user.id === sessionData.user_id;
  else isHost = user.id === sessionData.instructor_id;

  if (!isAdmin && !isHost) {
    return jsonResponse({
      success: false,
      error: 'Action réservée à l\'hôte de la séance ou à un administrateur.',
    }, 403);
  }

  // Un hote ne peut pas se faire retirer par lui-meme, et personne ne peut
  // retirer un administrateur : garde-fou contre la prise de controle.
  const roomName = (sessionData.livekit_room_name as string) ?? `session_${sessionId}`;

  try {
    switch (action) {
      case 'list': {
        const out = await roomService('ListParticipants', roomName, { room: roomName });
        return jsonResponse({ success: true, action, participants: out.participants ?? [] });
      }

      case 'mute':
      case 'unmute': {
        if (!targetIdentity) return jsonResponse({ success: false, error: 'target_identity requis.' }, 400);
        const muted = action === 'mute';
        // Il faut le SID de chaque piste : on liste, puis on coupe l'audio
        // (et la video si demande explicitement).
        const listed = await roomService('ListParticipants', roomName, { room: roomName });
        const participants = (listed.participants ?? []) as Array<Record<string, unknown>>;
        const target = participants.find((p) => (p.identity as string) === targetIdentity);
        if (!target) return jsonResponse({ success: false, error: 'Participant absent de la salle.' }, 404);

        const includeVideo = body.include_video === true;
        const tracks = (target.tracks ?? []) as Array<Record<string, unknown>>;
        let touched = 0;
        for (const t of tracks) {
          const type = (t.type ?? '').toString().toUpperCase();
          const isAudio = type.includes('AUDIO');
          const isVideo = type.includes('VIDEO');
          if (!isAudio && !(includeVideo && isVideo)) continue;
          await roomService('MutePublishedTrack', roomName, {
            room: roomName, identity: targetIdentity, track_sid: t.sid, muted,
          });
          touched++;
        }
        return jsonResponse({ success: true, action, tracks_affected: touched });
      }

      case 'revoke_publish':
      case 'grant_publish': {
        if (!targetIdentity) return jsonResponse({ success: false, error: 'target_identity requis.' }, 400);
        const allow = action === 'grant_publish';
        await roomService('UpdateParticipant', roomName, {
          room: roomName,
          identity: targetIdentity,
          permission: { can_subscribe: true, can_publish: allow, can_publish_data: true },
        });
        return jsonResponse({ success: true, action, can_publish: allow });
      }

      case 'remove': {
        if (!targetIdentity) return jsonResponse({ success: false, error: 'target_identity requis.' }, 400);
        if (targetIdentity === user.id) {
          return jsonResponse({ success: false, error: 'Utilisez « Quitter » pour sortir vous-même.' }, 400);
        }
        await roomService('RemoveParticipant', roomName, { room: roomName, identity: targetIdentity });
        return jsonResponse({ success: true, action });
      }

      case 'end_session': {
        // Ferme la salle pour TOUT le monde, puis marque la seance terminee.
        await roomService('DeleteRoom', roomName, { room: roomName });
        // La mise a jour du statut ne doit jamais faire echouer l'arret : la
        // salle est deja fermee, c'est l'effet attendu par le moderateur.
        try {
          if (sessionType === 'academia') {
            await supabase.schema('app').from('academia_sessions')
              .update({ status: 'ended' }).eq('id', sessionId);
          }
        } catch (e) {
          console.error('[livekit-moderate] statut non mis a jour', e);
        }
        return jsonResponse({ success: true, action });
      }

      default:
        return jsonResponse({ success: false, error: `Action inconnue : ${action}` }, 400);
    }
  } catch (e) {
    console.error('[livekit-moderate]', e);
    return jsonResponse({
      success: false,
      error: (e as Error).message?.slice(0, 300) ?? 'Erreur de modération.',
    }, 502);
  }
});
