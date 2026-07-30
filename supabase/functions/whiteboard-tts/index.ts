import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_TTS_MODEL = Deno.env.get('OPENROUTER_TTS_MODEL') ?? 'mistralai/voxtral-mini-tts-2603';
const OPENROUTER_TTS_VOICE = Deno.env.get('OPENROUTER_TTS_VOICE') ?? 'fr_marie_neutral';
const MAX_INPUT_CHARS = 1200;

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function jsonResponse(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function jwtRole(token: string): string {
  try {
    const payload = token.split('.')[1];
    if (!payload) return '';
    const normalized = payload.replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(normalized)).role ?? '';
  } catch (_) {
    return '';
  }
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const authorization = req.headers.get('Authorization') ?? '';
  const token = authorization.replace(/^Bearer\s+/i, '');
  if (jwtRole(token) !== 'service_role') {
    return jsonResponse({ error: 'Service role required' }, 403);
  }
  if (!OPENROUTER_API_KEY) {
    return jsonResponse({ error: 'OPENROUTER_API_KEY is not configured' }, 500);
  }

  let payload: { input?: unknown; voice?: unknown; model?: unknown };
  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const input = typeof payload.input === 'string' ? payload.input.trim() : '';
  if (!input || input.length > MAX_INPUT_CHARS) {
    return jsonResponse({ error: `input must contain 1 to ${MAX_INPUT_CHARS} characters` }, 400);
  }
  const voice = typeof payload.voice === 'string' && payload.voice.trim()
    ? payload.voice.trim()
    : OPENROUTER_TTS_VOICE;

  // Modele choisissable PAR REQUETE, avec le reglage global en defaut.
  // Sans ca, essayer une voix pour le Studio visuel changerait aussi celle du
  // Smart Whiteboard, qui est en production. Les deux produits doivent pouvoir
  // diverger sans se gener.
  const model = typeof payload.model === 'string' && payload.model.trim()
    ? payload.model.trim()
    : OPENROUTER_TTS_MODEL;

  try {
    const response = await fetch('https://openrouter.ai/api/v1/audio/speech', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
        Accept: 'audio/mpeg',
      },
      body: JSON.stringify({
        model,
        input,
        voice,
        response_format: 'mp3',
      }),
    });

    if (!response.ok) {
      const detail = (await response.text()).slice(0, 500);
      console.error(`[whiteboard-tts] OpenRouter ${response.status}: ${detail}`);
      return jsonResponse({
        error: 'OpenRouter TTS failed',
        status: response.status,
        detail,
      }, 502);
    }

    const audio = await response.arrayBuffer();
    if (audio.byteLength === 0) {
      return jsonResponse({ error: 'OpenRouter returned empty audio' }, 502);
    }
    return new Response(audio, {
      status: 200,
      headers: {
        ...CORS_HEADERS,
        'Content-Type': response.headers.get('Content-Type') ?? 'audio/mpeg',
        'Content-Length': audio.byteLength.toString(),
        'X-TTS-Provider': 'openrouter',
        'X-TTS-Model': model,
      },
    });
  } catch (error) {
    console.error('[whiteboard-tts] Unexpected error', error);
    return jsonResponse({ error: 'OpenRouter TTS request failed' }, 502);
  }
});
