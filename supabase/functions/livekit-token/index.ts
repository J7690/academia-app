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
  if (!sessionId) {
    return jsonResponse({ success: false, error: 'session_id requis.' }, 400);
  }

  // Look up the session in DB to get room name and validate access
  // Try prep_live_sessions first, then online_course_live_sessions
  let sessionData: Record<string, unknown> | null = null;
  let sessionType = '';

  const { data: prepSession } = await supabase
    .from('prep_live_sessions')
    .select('id, title, status, teacher_id')
    .eq('id', sessionId)
    .single();

  if (prepSession) {
    sessionData = prepSession;
    sessionType = 'prep';
  } else {
    const { data: courseSession } = await supabase
      .from('online_course_live_sessions')
      .select('id, title, status, instructor_id')
      .eq('id', sessionId)
      .single();

    if (courseSession) {
      sessionData = courseSession;
      sessionType = 'course';
    }
  }

  if (!sessionData) {
    return jsonResponse({ success: false, error: 'Session introuvable.' }, 404);
  }

  // Check session is active
  const status = sessionData.status as string;
  if (status !== 'live' && status !== 'scheduled' && status !== 'active' && status !== 'running' && status !== 'approved') {
    return jsonResponse({
      success: false,
      error: `Session non accessible (statut: ${status}).`,
    }, 403);
  }

  // Determine if user is the host (teacher/instructor)
  const isHost = sessionType === 'prep'
    ? user.id === sessionData.teacher_id
    : user.id === (sessionData as Record<string, unknown>).instructor_id;

  // Get user display name
  const { data: studentData } = await supabase
    .from('students')
    .select('full_name')
    .eq('id', user.id)
    .single();

  const displayName = (studentData?.full_name as string) ?? user.email ?? user.id;

  // Room name = session ID (unique per session)
  const roomName = `session_${sessionId}`;

  // Generate token
  const token = await generateLiveKitToken({
    apiKey: LIVEKIT_API_KEY,
    apiSecret: LIVEKIT_API_SECRET,
    roomName,
    participantIdentity: user.id,
    participantName: displayName,
    canPublish: isHost, // Only host can publish by default
    canSubscribe: true,
    ttlSeconds: 3600 * 4, // 4 hours
  });

  // Register participant in DB
  if (sessionType === 'prep') {
    await supabase.rpc('app_prep_student_join_live_session', {
      p_session_id: sessionId,
    });
  } else {
    await supabase.rpc('app_register_online_course_live_session_participant', {
      p_session_id: sessionId,
      p_user_id: user.id,
    });
  }

  return jsonResponse({
    success: true,
    token,
    url: LIVEKIT_URL,
    room_name: roomName,
    identity: user.id,
    display_name: displayName,
    is_host: isHost,
  });
});
