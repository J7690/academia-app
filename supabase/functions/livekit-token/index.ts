// Supabase Edge Function: livekit-token
// Generates LiveKit JWT access tokens for authenticated users.
// Called by Flutter via POST /functions/v1/livekit-token
//
// Required Supabase Secrets:
//   LIVEKIT_API_KEY     — LiveKit server API key
//   LIVEKIT_API_SECRET  — LiveKit server API secret
//   LIVEKIT_URL         — LiveKit server WebSocket URL (wss://...)

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

// HMAC-SHA256 signing for JWT
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

// Generate a LiveKit-compatible JWT token
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

  const header = {
    alg: 'HS256',
    typ: 'JWT',
  };

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
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ success: false, error: 'Method not allowed' }, 405);
  }

  // Check LiveKit config
  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_URL) {
    return jsonResponse({
      success: false,
      error: 'LiveKit non configuré. Contactez l\'administrateur.',
    }, 500);
  }

  // Authenticate user via Supabase JWT
  const authHeader = req.headers.get('authorization') ?? '';
  const jwt = authHeader.replace('Bearer ', '');

  if (!jwt) {
    return jsonResponse({ success: false, error: 'Non authentifié.' }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Verify the user's JWT
  const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);
  if (authError || !user) {
    return jsonResponse({ success: false, error: 'Token invalide.' }, 401);
  }

  // Parse request body
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ success: false, error: 'Corps de requête invalide.' }, 400);
  }

  const sessionId = body.session_id as string;
  // Optional: caller specifies 'academia' to force unified table lookup
  const sessionSource = (body.session_source as string) ?? 'auto';

  if (!sessionId) {
    return jsonResponse({ success: false, error: 'session_id requis.' }, 400);
  }

  // ── Lookup strategy: unified table first, then legacy tables ────────
  let sessionData: Record<string, unknown> | null = null;
  let sessionType = 'legacy';
  let isHost = false;
  let roomName = `session_${sessionId}`;

  // 1. Try academia_sessions (unified Learning Engine)
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

  // 2. Fallback: legacy lookup for old tables
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

  // ── Status check ─────────────────────────────────────────────────────
  const status = sessionData.status as string;
  const allowedStatuses = ['live', 'scheduled', 'active', 'running', 'approved', 'draft'];
  if (!allowedStatuses.includes(status)) {
    return jsonResponse({
      success: false,
      error: `Session non accessible (statut: ${status}).`,
    }, 403);
  }

  // ── Determine host ────────────────────────────────────────────────────
  if (sessionType === 'academia') {
    isHost = user.id === (sessionData.host_id as string);
  } else if (sessionType === 'prep') {
    isHost = user.id === sessionData.teacher_id;
  } else if (sessionType === 'game') {
    isHost = user.id === sessionData.user_id;
  } else {
    isHost = user.id === sessionData.instructor_id;
  }

  // ── Room name ──────────────────────────────────────────────────────────
  if (sessionData.livekit_room_name) {
    roomName = sessionData.livekit_room_name as string;
  }

  // ── Display name ──────────────────────────────────────────────────────
  const { data: displayNameResult } = await supabase.rpc(
    'livekit_get_user_display_name',
    { p_user_id: user.id },
  );
  const displayName = (displayNameResult as string) ?? user.email ?? user.id;

  // ── Generate LiveKit JWT ───────────────────────────────────────────────
  const token = await generateLiveKitToken({
    apiKey: LIVEKIT_API_KEY,
    apiSecret: LIVEKIT_API_SECRET,
    roomName,
    participantIdentity: user.id,
    participantName: displayName,
    canPublish: isHost,
    canSubscribe: true,
    ttlSeconds: 3600 * 4, // 4 hours
  });

  // ── Register participant ───────────────────────────────────────────────
  if (sessionType === 'academia') {
    // Unified join — tracked via app_learning_join_session RPC called by Flutter
    // (already done in AcademiaSessionProvider.joinSession before token request)
  } else if (sessionType === 'prep') {
    await supabase.rpc('app_prep_student_join_live_session', {
      p_session_id: sessionId,
    }).catch(() => null);
  } else if (sessionType === 'course') {
    await supabase.rpc('app_register_online_course_live_session_participant', {
      p_session_id: sessionId,
      p_user_id: user.id,
    }).catch(() => null);
  }

  return jsonResponse({
    success: true,
    token,
    url: LIVEKIT_URL,
    room_name: roomName,
    identity: user.id,
    display_name: displayName,
    is_host: isHost,
    session_type: sessionType,
  });
});
