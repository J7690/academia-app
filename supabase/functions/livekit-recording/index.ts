// Supabase Edge Function: livekit-recording
// Start/Stop LiveKit Egress recording for a session.
// Called by Flutter via POST /functions/v1/livekit-recording
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

async function generateLiveKitToken(apiKey: string, apiSecret: string, ttl = 30): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload: Record<string, unknown> = {
    iss: apiKey,
    sub: 'recording-service',
    nbf: now,
    exp: now + ttl,
    iat: now,
    jti: crypto.randomUUID(),
    video: {
      roomRecord: true,
    },
  };
  const enc = new TextEncoder();
  const h = base64url(enc.encode(JSON.stringify(header)));
  const p = base64url(enc.encode(JSON.stringify(payload)));
  const sig = await hmacSign(apiSecret, `${h}.${p}`);
  return `${h}.${p}.${sig}`;
}

function getLiveKitHttpUrl(): string {
  // LIVEKIT_URL is ws:// or wss://, convert to http:// or https://
  return LIVEKIT_URL
    .replace('wss://', 'https://')
    .replace('ws://', 'http://');
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

  // Auth
  const authHeader = req.headers.get('authorization') ?? '';
  const jwt = authHeader.replace('Bearer ', '');
  if (!jwt) return jsonResponse({ success: false, error: 'Non authentifié.' }, 401);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);
  if (authError || !user) return jsonResponse({ success: false, error: 'Token invalide.' }, 401);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return jsonResponse({ success: false, error: 'Corps invalide.' }, 400); }

  const action = body.action as string; // 'start' or 'stop'
  const sessionId = body.session_id as string;
  const sessionType = (body.session_type as string) || 'course'; // 'course' or 'prep'

  if (!action || !sessionId) {
    return jsonResponse({ success: false, error: 'action et session_id requis.' }, 400);
  }

  // Verify the user is the host
  const table = sessionType === 'prep' ? 'prep_live_sessions' : 'online_course_live_sessions';
  const hostCol = sessionType === 'prep' ? 'teacher_id' : 'host_id';

  const { data: session, error: sessErr } = await supabase
    .from(table)
    .select('*')
    .eq('id', sessionId)
    .single();

  if (sessErr || !session) {
    return jsonResponse({ success: false, error: 'Session introuvable.' }, 404);
  }

  // Check host (for course sessions, also check instructor_id as fallback)
  const isHost = session[hostCol] === user.id ||
    (sessionType === 'course' && session.instructor_id === user.id);

  // Also allow admin role
  const { data: adminCheck } = await supabase
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id)
    .eq('role', 'admin')
    .maybeSingle();

  if (!isHost && !adminCheck) {
    return jsonResponse({ success: false, error: 'Seul l\'hôte peut enregistrer.' }, 403);
  }

  const lkToken = await generateLiveKitToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, 60);
  const lkHttp = getLiveKitHttpUrl();
  const roomName = session.livekit_room_name || `session_${sessionId}`;

  if (action === 'start') {
    // Start Room Composite Egress via LiveKit Twirp API
    const egressReq = {
      room_name: roomName,
      file: {
        file_type: 'MP4',
        filepath: `recordings/${sessionId}/{time}`,
      },
    };

    try {
      const resp = await fetch(`${lkHttp}/twirp/livekit.Egress/StartRoomCompositeEgress`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${lkToken}`,
        },
        body: JSON.stringify(egressReq),
      });

      const data = await resp.json();

      if (!resp.ok) {
        return jsonResponse({
          success: false,
          error: `Egress start failed: ${data.msg || data.message || JSON.stringify(data)}`,
        }, resp.status);
      }

      // Store egress_id in session for later stop
      const egressId = data.egress_id;
      const updateCol = sessionType === 'prep' ? 'replay_url' : 'replay_video_url';
      await supabase
        .from(table)
        .update({ [updateCol]: `recording:${egressId}` })
        .eq('id', sessionId);

      return jsonResponse({
        success: true,
        egress_id: egressId,
        status: data.status,
      });
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      return jsonResponse({ success: false, error: `Egress error: ${msg}` }, 500);
    }

  } else if (action === 'stop') {
    const egressId = body.egress_id as string;
    if (!egressId) {
      return jsonResponse({ success: false, error: 'egress_id requis pour stop.' }, 400);
    }

    try {
      const resp = await fetch(`${lkHttp}/twirp/livekit.Egress/StopEgress`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${lkToken}`,
        },
        body: JSON.stringify({ egress_id: egressId }),
      });

      const data = await resp.json();

      if (!resp.ok) {
        return jsonResponse({
          success: false,
          error: `Egress stop failed: ${data.msg || data.message || JSON.stringify(data)}`,
        }, resp.status);
      }

      // Update replay URL from egress file info
      const fileUrl = data.file?.location || data.file_results?.[0]?.location || '';
      if (fileUrl) {
        const updateCol = sessionType === 'prep' ? 'replay_url' : 'replay_video_url';
        await supabase
          .from(table)
          .update({ [updateCol]: fileUrl })
          .eq('id', sessionId);
      }

      return jsonResponse({
        success: true,
        egress_id: egressId,
        file_url: fileUrl,
        status: data.status,
      });
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      return jsonResponse({ success: false, error: `Egress stop error: ${msg}` }, 500);
    }

  } else {
    return jsonResponse({ success: false, error: 'action doit être start ou stop.' }, 400);
  }
});
