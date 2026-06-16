// Edge Function temporaire pour tester bobodo-chat avec logging détaillé
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_EMBEDDING_MODEL = Deno.env.get('OPENROUTER_EMBEDDING_MODEL') ?? '';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  const logs: string[] = [];
  const log = (msg: string) => {
    logs.push(msg);
    console.log(msg);
  };

  log('=== TEST BOBODO-CHAT WITH DETAILED LOGGING ===');
  log(`OPENROUTER_API_KEY: ${OPENROUTER_API_KEY ? 'CONFIGURED (length: ' + OPENROUTER_API_KEY.length + ')' : 'NOT CONFIGURED'}`);
  log(`OPENROUTER_MODEL: ${OPENROUTER_MODEL || 'NOT CONFIGURED'}`);
  log(`OPENROUTER_EMBEDDING_MODEL: ${OPENROUTER_EMBEDDING_MODEL || 'NOT CONFIGURED'}`);

  // Test 1: Embeddings
  log('\n--- TEST 1: EMBEDDINGS ---');
  try {
    const embResp = await fetch('https://openrouter.ai/api/v1/embeddings', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: OPENROUTER_EMBEDDING_MODEL,
        input: ['test'],
      }),
    });
    log(`Embeddings status: ${embResp.status}`);
    const embText = await embResp.text();
    log(`Embeddings response: ${embText.slice(0, 500)}`);
  } catch (e) {
    log(`Embeddings error: ${(e as Error).message}`);
  }

  // Test 2: Chat completions with cascade models
  const modelsToTest = [
    'google/gemini-2.0-flash-exp:free',
    'google/gemini-2.5-flash-preview-05-20',
    'google/gemini-2.0-flash-001',
    'google/gemini-2.5-flash',
  ];

  for (const model of modelsToTest) {
    log(`\n--- TEST: ${model} ---`);
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
      log(`${model} status: ${resp.status}`);
      const text = await resp.text();
      log(`${model} response: ${text.slice(0, 500)}`);
    } catch (e) {
      log(`${model} error: ${(e as Error).message}`);
    }
  }

  return new Response(JSON.stringify({ logs }, null, 2), {
    status: 200,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
});
