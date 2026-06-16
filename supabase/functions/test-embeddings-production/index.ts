// Edge Function de test pour embeddings avec la clé de production
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_EMBEDDING_MODEL = Deno.env.get('OPENROUTER_EMBEDDING_MODEL') ?? '';

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const payload = await req.json();
  const text = payload.text || "Test embedding generation";

  console.log(`Testing embeddings with model: ${OPENROUTER_EMBEDDING_MODEL}`);
  console.log(`API Key length: ${OPENROUTER_API_KEY.length}`);

  try {
    const resp = await fetch('https://openrouter.ai/api/v1/embeddings', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        model: OPENROUTER_EMBEDDING_MODEL,
        input: text,
      }),
    });

    const body = await resp.text();
    console.log(`OpenRouter embeddings status=${resp.status} body=${body.slice(0, 500)}`);

    if (!resp.ok) {
      return new Response(JSON.stringify({
        success: false,
        status: resp.status,
        error: body,
        model: OPENROUTER_EMBEDDING_MODEL,
        api_key_length: OPENROUTER_API_KEY.length,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: resp.status,
      });
    }

    const data = JSON.parse(body);
    const arr = Array.isArray(data?.data) ? data.data : null;
    
    if (!arr || !arr.length) {
      return new Response(JSON.stringify({
        success: false,
        error: "No embeddings returned",
        model: OPENROUTER_EMBEDDING_MODEL,
        api_key_length: OPENROUTER_API_KEY.length,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    const first = arr[0] as { embedding?: unknown };
    const rawVec = (first?.embedding as unknown) as unknown[] | undefined;
    
    if (!Array.isArray(rawVec) || !rawVec.length) {
      return new Response(JSON.stringify({
        success: false,
        error: "Invalid embedding format",
        model: OPENROUTER_EMBEDDING_MODEL,
        api_key_length: OPENROUTER_API_KEY.length,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    return new Response(JSON.stringify({
      success: true,
      model: OPENROUTER_EMBEDDING_MODEL,
      api_key_length: OPENROUTER_API_KEY.length,
      embedding_dimension: rawVec.length,
      model_used: data.model,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Embeddings test error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      model: OPENROUTER_EMBEDDING_MODEL,
      api_key_length: OPENROUTER_API_KEY.length,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
