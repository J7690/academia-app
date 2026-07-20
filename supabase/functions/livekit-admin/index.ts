// Supabase Edge Function: livekit-admin
// Actions de modération hôte pour une salle AcademiaClassroom :
//   - list_participants : liste les participants LiveKit (avec leurs tracks)
//   - mute_participant  : coupe à distance le micro (ou la caméra) d'un participant
//   - remove_participant: exclut un participant de la room
//
// Réutilise exactement la même stratégie de lookup/host que `livekit-token`
// pour ne pas dupliquer de logique métier ni contourner les règles d'accès.
//
// Required Supabase Secrets:
//   LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_URL

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIVEKIT_API_KEY = Deno.env.get('LIVEKIT_API_KEY') ?? '';
const LIVEKIT_API_SECRET = Deno.env.get('LIVEKIT_API_SECRET') ?? '';
const LIVEKIT_URL = Deno.env.get('LIVEKIT_URL') ?? '';

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

function base64url(data: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < data.byteLength; i++) {
    binary += String.fromCharCode(data[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function hmacSign(secret: string, data: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw', encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(data));
  return base64url(new Uint8Array(signature));
}

// Token d'admin de room (grant roomAdmin, scope sur la room ciblée).
async function generateAdminToken(roomName: string, ttl = 30): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload: Record<string, unknown> = {
    iss: LIVEKIT_API_KEY,
    sub: 'admin-service',
    nbf: now,
    exp: now + ttl,
    iat: now,
    jti: crypto.randomUUID(),
    video: {
      roomAdmin: true,
      room: roomName,
    },
  };
  const enc = new TextEncoder();
  const h = base64url(enc.encode(JSON.stringify(header)));
  const p = base64url(enc.encode(JSON.stringify(payload)));
  const sig = await hmacSign(LIVEKIT_API_SECRET, `${h}.${p}`);
  return `${h}.${p}.${sig}`;
}

function getLiveKitHttpUrl(): string {
  return LIVEKIT_URL.replace('wss://', 'https://').replace('ws://', 'http://');
}

async function twirp(path: string, roomName: string, body: Record<string, unknown>) {
  const token = await generateAdminToken(roomName);
  const resp = await fetch(`${getLiveKitHttpUrl()}/twirp/livekit.RoomService/${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(data.msg || data.message || `LiveKit RoomService error (${resp.status})`);
  }
  return data;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ success: false, error: 'Method not allowed' }, 405);
  }
  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_URL) {
    return jsonResponse({ success: false, error: 'LiveKit non configuré.' }, 500);
  }

  const authHeader = req.headers.get('authorization') ?? '';
  const jwt = authHeader.replace('Bearer ', '');
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

  const action = body.action as string;
  const sessionId = body.session_id as string;
  const sessionSource = (body.session_source as string) ?? 'auto';

  if (!action || !sessionId) {
    return jsonResponse({ success: false, error: 'action et session_id requis.' }, 400);
  }

  // ── Même stratégie de lookup que livekit-token ───────────────────────
  let sessionData: Record<string, unknown> | null = null;
  let sessionType = 'legacy';
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
    const { data: legacyData } = await supabase.rpc(
      'livekit_lookup_session',
      { p_session_id: sessionId },
    );
    if (!legacyData) {
      return jsonResponse({ success: false, error: 'Session introuvable.' }, 404);
    }
    sessionData = legacyData as Record<string, unknown>;
    sessionType = (sessionData.session_type as string) ?? 'course';
  }

  if (sessionData.livekit_room_name) {
    roomName = sessionData.livekit_room_name as string;
  }

  // ── Vérification hôte (même logique que livekit-token) ──────────────
  let isHost = false;
  if (sessionType === 'academia') {
    isHost = user.id === (sessionData.host_id as string);
  } else if (sessionType === 'prep') {
    isHost = user.id === sessionData.teacher_id;
  } else if (sessionType === 'game') {
    isHost = user.id === sessionData.user_id;
  } else {
    isHost = user.id === sessionData.instructor_id;
  }

  if (!isHost) {
    const { data: adminCheck } = await supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('role', 'admin')
      .maybeSingle();
    if (!adminCheck) {
      return jsonResponse({ success: false, error: "Seul l'hôte ou un admin peut modérer cette session." }, 403);
    }
  }

  try {
    if (action === 'list_participants') {
      const data = await twirp('ListParticipants', roomName, { room: roomName });
      return jsonResponse({ success: true, participants: data.participants ?? [] });
    }

    if (action === 'mute_participant') {
      const identity = body.participant_identity as string;
      const trackType = ((body.track_type as string) ?? 'audio').toLowerCase();
      const muted = body.muted !== false; // défaut: couper
      if (!identity) {
        return jsonResponse({ success: false, error: 'participant_identity requis.' }, 400);
      }

      const list = await twirp('ListParticipants', roomName, { room: roomName });
      const participant = (list.participants ?? []).find(
        (p: Record<string, unknown>) => p.identity === identity,
      );
      if (!participant) {
        return jsonResponse({ success: false, error: 'Participant introuvable dans la room.' }, 404);
      }
      const tracks = (participant.tracks ?? []) as Array<Record<string, unknown>>;
      const track = tracks.find((t) =>
        trackType === 'video' ? t.type === 'VIDEO' : t.type === 'AUDIO',
      );
      if (!track) {
        return jsonResponse({ success: false, error: `Aucune piste ${trackType} publiée par ce participant.` }, 404);
      }

      const result = await twirp('MutePublishedTrack', roomName, {
        room: roomName,
        identity,
        track_sid: track.sid,
        muted,
      });
      return jsonResponse({ success: true, result });
    }

    if (action === 'remove_participant') {
      const identity = body.participant_identity as string;
      if (!identity) {
        return jsonResponse({ success: false, error: 'participant_identity requis.' }, 400);
      }
      const result = await twirp('RemoveParticipant', roomName, { room: roomName, identity });
      return jsonResponse({ success: true, result });
    }

    return jsonResponse({ success: false, error: 'action inconnue.' }, 400);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonResponse({ success: false, error: msg }, 500);
  }
});
