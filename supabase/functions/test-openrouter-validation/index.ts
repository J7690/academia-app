import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, content-type',
      },
    });
  }

  const results: { name: string; model: string; status: string; error?: string }[] = [];

  // Test 1: OPENROUTER_MODEL
  try {
    const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: OPENROUTER_MODEL,
        messages: [{ role: 'user', content: 'Test: respond with OK' }],
        max_tokens: 10,
      }),
    });
    results.push({
      name: 'OPENROUTER_MODEL',
      model: OPENROUTER_MODEL,
      status: resp.ok ? 'OK' : `FAILED (${resp.status})`,
      error: resp.ok ? undefined : await resp.text(),
    });
  } catch (e) {
    results.push({
      name: 'OPENROUTER_MODEL',
      model: OPENROUTER_MODEL,
      status: 'ERROR',
      error: (e as Error).message,
    });
  }

  // Test 2: OPENROUTER_FALLBACK_MODEL
  try {
    const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: OPENROUTER_FALLBACK_MODEL,
        messages: [{ role: 'user', content: 'Test: respond with OK' }],
        max_tokens: 10,
      }),
    });
    results.push({
      name: 'OPENROUTER_FALLBACK_MODEL',
      model: OPENROUTER_FALLBACK_MODEL,
      status: resp.ok ? 'OK' : `FAILED (${resp.status})`,
      error: resp.ok ? undefined : await resp.text(),
    });
  } catch (e) {
    results.push({
      name: 'OPENROUTER_FALLBACK_MODEL',
      model: OPENROUTER_FALLBACK_MODEL,
      status: 'ERROR',
      error: (e as Error).message,
    });
  }

  return new Response(JSON.stringify({
    secrets: {
      OPENROUTER_MODEL,
      OPENROUTER_FALLBACK_MODEL,
    },
    tests: results,
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
