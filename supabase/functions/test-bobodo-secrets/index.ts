// Edge Function de test pour logger les secrets effectifs de bobodo-chat
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';
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

  const secrets = {
    OPENROUTER_API_KEY: {
      present: OPENROUTER_API_KEY.length > 0,
      length: OPENROUTER_API_KEY.length,
      prefix: OPENROUTER_API_KEY.length > 10 ? OPENROUTER_API_KEY.substring(0, 10) : '',
      suffix: OPENROUTER_API_KEY.length > 4 ? OPENROUTER_API_KEY.substring(OPENROUTER_API_KEY.length - 4) : '',
    },
    OPENROUTER_MODEL: {
      present: OPENROUTER_MODEL.length > 0,
      value: OPENROUTER_MODEL,
    },
    OPENROUTER_FALLBACK_MODEL: {
      present: OPENROUTER_FALLBACK_MODEL.length > 0,
      value: OPENROUTER_FALLBACK_MODEL,
    },
    OPENROUTER_EMBEDDING_MODEL: {
      present: OPENROUTER_EMBEDDING_MODEL.length > 0,
      value: OPENROUTER_EMBEDDING_MODEL,
    },
  };

  return new Response(JSON.stringify(secrets, null, 2), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
