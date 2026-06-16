// Edge Function temporaire pour vérifier la configuration OpenRouter
// Affiche les valeurs des secrets et teste les modèles

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_EMBEDDING_MODEL = Deno.env.get('OPENROUTER_EMBEDDING_MODEL') ?? '';
const OPENROUTER_CHAT_MODEL = Deno.env.get('OPENROUTER_CHAT_MODEL') ?? '';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  const results: Record<string, unknown> = {
    secrets: {
      OPENROUTER_API_KEY: OPENROUTER_API_KEY ? 'CONFIGURED (length: ' + OPENROUTER_API_KEY.length + ')' : 'NOT CONFIGURED',
      OPENROUTER_MODEL: OPENROUTER_MODEL || 'NOT CONFIGURED',
      OPENROUTER_EMBEDDING_MODEL: OPENROUTER_EMBEDDING_MODEL || 'NOT CONFIGURED',
      OPENROUTER_CHAT_MODEL: OPENROUTER_CHAT_MODEL || 'NOT CONFIGURED',
    },
    model_tests: {},
  };

  // Tester les modèles
  const modelsToTest = [
    'google/gemini-2.0-flash-001',
    'google/gemini-2.0-flash-exp:free',
    'google/gemini-2.5-flash-preview-05-20',
    'google/gemini-2.5-flash',
    OPENROUTER_MODEL,
  ];

  for (const model of modelsToTest) {
    if (!model) continue;
    try {
      const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: [{ role: 'user', content: 'test' }],
          max_tokens: 10,
        }),
      });

      const text = await resp.text();
      results.model_tests[model as string] = {
        status: resp.status,
        ok: resp.ok,
        response: text.slice(0, 500),
      };
    } catch (e) {
      results.model_tests[model as string] = {
        error: (e as Error).message,
      };
    }
  }

  return new Response(JSON.stringify(results, null, 2), {
    status: 200,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
});
