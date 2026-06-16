// Edge Function temporaire: génère les embeddings manquants pour prep_chunks
// Utilise OPENROUTER_API_KEY côté serveur (secret Supabase)

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_EMBEDDING_MODEL = Deno.env.get('OPENROUTER_EMBEDDING_MODEL') ?? 'openai/text-embedding-3-small';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });

  const rpcHeaders = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    'Content-Type': 'application/json',
  };

  // Lire les chunks sans embedding via execute_sql (bypasse RLS)
  const readResp = await fetch(`${SUPABASE_URL}/rest/v1/rpc/execute_sql`, {
    method: 'POST',
    headers: rpcHeaders,
    body: JSON.stringify({
      sql_query: "SELECT id, content FROM app.prep_chunks WHERE embedding IS NULL LIMIT 100",
    }),
  });

  if (!readResp.ok) {
    return new Response(JSON.stringify({ error: `read failed: ${readResp.status}` }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const chunks = await readResp.json() as Array<{ id: string; content: string }>;

  if (!Array.isArray(chunks) || chunks.length === 0) {
    return new Response(JSON.stringify({ message: 'Aucun chunk sans embedding', updated: 0 }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  let updated = 0;
  const errors: string[] = [];

  for (const chunk of chunks) {
    try {
      const resp = await fetch('https://openrouter.ai/api/v1/embeddings', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ model: EMBEDDING_MODEL, input: chunk.content.slice(0, 2000) }),
      });

      if (!resp.ok) {
        errors.push(`chunk ${chunk.id}: embedding API ${resp.status}`);
        continue;
      }

      const data = await resp.json();
      const vec = data?.data?.[0]?.embedding;
      if (!vec || !Array.isArray(vec)) {
        errors.push(`chunk ${chunk.id}: no embedding in response`);
        continue;
      }

      const vecStr = `[${vec.join(',')}]`;

      // Utiliser RPC execute_ddl pour mettre à jour car le client app schema
      // peut avoir des problèmes avec les colonnes vector
      const updateResp = await fetch(`${SUPABASE_URL}/rest/v1/rpc/execute_ddl`, {
        method: 'POST',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ddl_query: `UPDATE app.prep_chunks SET embedding = '${vecStr}'::vector WHERE id = '${chunk.id}'`,
        }),
      });
      const updateError = updateResp.ok ? null : { message: `DDL ${updateResp.status}` };

      if (updateError) {
        errors.push(`chunk ${chunk.id}: update failed: ${updateError.message}`);
      } else {
        updated++;
      }
    } catch (e) {
      errors.push(`chunk ${chunk.id}: ${(e as Error).message}`);
    }
  }

  return new Response(JSON.stringify({
    total_chunks: chunks.length,
    updated,
    errors: errors.slice(0, 10),
  }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
});
