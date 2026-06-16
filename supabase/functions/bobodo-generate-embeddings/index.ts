// Edge Function pour générer les embeddings des fiches Bobodo
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_EMBEDDING_MODEL = Deno.env.get('OPENROUTER_EMBEDDING_MODEL') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    db: { schema: 'app' },
  });

  try {
    // Récupérer toutes les fiches sans embeddings
    const { data: fiches, error: fetchError } = await supabase
      .from('bobodo_knowledge')
      .select('id, title, content')
      .is('embedding', null)
      .is('is_active', true);

    if (fetchError) {
      throw new Error(`Erreur récupération fiches: ${fetchError.message}`);
    }

    if (!fiches || fiches.length === 0) {
      return new Response(JSON.stringify({
        success: true,
        message: 'Aucune fiche sans embedding à traiter',
        processed: 0,
        updated: 0,
        failed: 0,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log(`${fiches.length} fiches sans embedding à traiter`);

    let updated = 0;
    let failed = 0;

    for (const fiche of fiches) {
      try {
        const text = `${fiche.title}\n\n${fiche.content}`;
        
        // Générer l'embedding
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

        if (!resp.ok) {
          const body = await resp.text();
          console.error(`Erreur embedding pour fiche ${fiche.id}: ${body}`);
          failed++;
          continue;
        }

        const data = await resp.json();
        const arr = Array.isArray(data?.data) ? data.data : null;
        
        if (!arr || !arr.length) {
          console.error(`Pas d'embedding retourné pour fiche ${fiche.id}`);
          failed++;
          continue;
        }

        const first = arr[0] as { embedding?: unknown };
        const rawVec = (first?.embedding as unknown) as unknown[] | undefined;
        
        if (!Array.isArray(rawVec) || !rawVec.length) {
          console.error(`Format embedding invalide pour fiche ${fiche.id}`);
          failed++;
          continue;
        }

        // Normaliser le vecteur
        const normalized = rawVec.map((x) => {
          const v = typeof x === 'number' ? x : Number(x);
          if (!Number.isFinite(v)) return 0;
          return Number(v.toFixed(8));
        });

        const inner = normalized.join(',');
        const vecText = `[${inner}]`;

        // Mettre à jour la fiche
        const { error: updateError } = await supabase
          .from('bobodo_knowledge')
          .update({ embedding: vecText })
          .eq('id', fiche.id);

        if (updateError) {
          console.error(`Erreur mise à jour fiche ${fiche.id}: ${updateError.message}`);
          failed++;
        } else {
          updated++;
          console.log(`Embedding généré pour: ${fiche.title}`);
        }

      } catch (error) {
        console.error(`Erreur traitement fiche ${fiche.id}:`, error);
        failed++;
      }
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Génération embeddings terminée',
      processed: fiches.length,
      updated,
      failed,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Erreur globale:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
