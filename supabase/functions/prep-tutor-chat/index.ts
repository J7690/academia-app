// Supabase Edge Function: prep-tutor-chat
// AI Tutor for "Préparation Concours" module.
// Reuses the same OPENROUTER_API_KEY as bobodo-chat.
// Specialized system prompt for Burkina Faso public service competitive exams (ENAREF, Admin Civil, Douane, Greffiers, etc.).

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const EMBEDDING_MODEL = 'openai/text-embedding-3-small';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

// Default system prompt — can be overridden from td_ai_config table
const DEFAULT_SYSTEM_PROMPT =
  "Tu es un tuteur expert en préparation aux concours de la fonction publique du Burkina Faso " +
  "(ENAREF, Administrateurs Civils, Douane, Greffiers, ENS, Éducation, Santé, Agriculture, Eaux et Forêts, GRH, Paramilitaire). " +
  "Tu expliques les concepts pas à pas, tu proposes des exercices, tu corriges les erreurs avec bienveillance. " +
  "Tu t'adaptes au niveau de l'étudiant. Langue : français. Contexte : système administratif et éducatif burkinabè. " +
  "Tu peux aider en : culture générale, actualités du Burkina Faso, droit (constitutionnel, administratif, civil, pénal, fiscal, du travail), " +
  "économie générale, finances publiques, fiscalité, comptabilité, français, tests psychotechniques, " +
  "mathématiques, sciences naturelles, informatique, GRH et management, pédagogie. " +
  "Quand tu donnes une réponse à un exercice, montre le raisonnement étape par étape. " +
  "Si l'étudiant fait une erreur, corrige-le avec bienveillance en expliquant pourquoi. " +
  "Utilise des exemples concrets du contexte burkinabè quand c'est pertinent (institutions, lois, géographie du Burkina Faso). " +
  "Adapte la longueur de ta réponse : courte pour les questions simples, détaillée pour les exercices et explications.";

type ChatMessage = { role: 'user' | 'assistant' | 'system'; content: string };

async function callOpenRouter(
  messages: ChatMessage[],
  maxTokens = 2048,
): Promise<string> {
  if (!OPENROUTER_API_KEY || !OPENROUTER_MODEL) {
    throw new Error('OPENROUTER_API_KEY or OPENROUTER_MODEL not configured');
  }

  const payload = {
    model: OPENROUTER_MODEL,
    messages,
    temperature: 0.7,
    top_p: 0.95,
    max_tokens: maxTokens,
  };

  const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`OpenRouter error (status=${resp.status}): ${text.slice(0, 500)}`);
  }

  const data = await resp.json();
  const choices = Array.isArray(data?.choices) ? data.choices : null;
  if (!choices || !choices.length) {
    throw new Error('OpenRouter: no choices returned');
  }

  const content = (choices[0]?.message?.content ?? '').toString().trim();
  if (!content) {
    throw new Error('OpenRouter: empty content');
  }

  return content;
}

async function loadSystemPrompt(
  supabaseService: ReturnType<typeof createClient>,
): Promise<string> {
  try {
    const { data, error } = await supabaseService.rpc('app_prep_get_ai_config');
    if (error) {
      console.error('app_prep_get_ai_config error', error.message);
      return DEFAULT_SYSTEM_PROMPT;
    }
    const config = data as Record<string, unknown> | null;
    if (!config) return DEFAULT_SYSTEM_PROMPT;

    const prompt = (config['system_prompt'] ?? '').toString().trim();
    return prompt || DEFAULT_SYSTEM_PROMPT;
  } catch (e) {
    console.error('loadSystemPrompt error', e);
    return DEFAULT_SYSTEM_PROMPT;
  }
}

async function loadConversationHistory(
  supabaseService: ReturnType<typeof createClient>,
  conversationId: string,
  maxMessages = 12,
): Promise<ChatMessage[]> {
  if (!conversationId) return [];

  try {
    const { data, error } = await supabaseService.rpc('app_prep_list_ai_messages', {
      p_conversation_id: conversationId,
    });

    if (error) {
      console.error('app_prep_list_ai_messages error', error.message);
      return [];
    }

    let rows: any[] = [];
    if (Array.isArray(data)) {
      rows = data;
    } else if (data && typeof data === 'object') {
      // JSONB array returned as single value
      if (Array.isArray((data as any))) rows = data as any[];
    }

    const history: ChatMessage[] = [];
    for (const raw of rows) {
      const row = raw as Record<string, unknown>;
      const role = (row.role ?? '').toString();
      const content = (row.content ?? '').toString().trim();
      if (!content) continue;

      if (role === 'user') {
        history.push({ role: 'user', content });
      } else if (role === 'assistant') {
        history.push({ role: 'assistant', content });
      }
    }

    // Keep only the last N messages for context window
    if (history.length > maxMessages) {
      return history.slice(history.length - maxMessages);
    }

    return history;
  } catch (e) {
    console.error('loadConversationHistory error', e);
    return [];
  }
}

async function saveMessage(
  supabaseService: ReturnType<typeof createClient>,
  conversationId: string,
  role: string,
  content: string,
): Promise<void> {
  try {
    const { error } = await supabaseService.rpc('app_prep_save_ai_message', {
      p_conversation_id: conversationId,
      p_role: role,
      p_content: content,
      p_tokens_used: 0,
    });
    if (error) {
      console.error(`app_prep_save_ai_message (${role}) error`, error.message);
    }
  } catch (e) {
    console.error(`saveMessage (${role}) error`, e);
  }
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    // ─── Auth ────────────────────────────────────────────────────
    const authHeader = req.headers.get('authorization') ?? req.headers.get('Authorization');
    const apiKeyHeader = req.headers.get('apikey');

    if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
      return new Response(JSON.stringify({ error: 'Authorization Bearer manquant' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    const jwt = authHeader.split(' ', 2)[1]?.trim();
    if (!jwt) {
      return new Response(JSON.stringify({ error: 'JWT invalide' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    if (!apiKeyHeader) {
      return new Response(JSON.stringify({ error: 'apikey manquante' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: 'Supabase backend non configuré' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    // Supabase clients
    const supabaseForUser = createClient(SUPABASE_URL, apiKeyHeader, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const supabaseService = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ─── Parse body ──────────────────────────────────────────────
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== 'object') {
      return new Response(JSON.stringify({ error: 'Payload JSON invalide' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    const message = ((body as any).message ?? '').toString().trim();
    const conversationId = ((body as any).conversation_id ?? '').toString().trim();
    const subject = ((body as any).subject ?? '').toString().trim();

    if (!message) {
      return new Response(JSON.stringify({ error: 'Le message ne peut pas être vide.' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    // ─── Load system prompt from config ──────────────────────
    const systemPrompt = await loadSystemPrompt(supabaseService);

    // ─── Load conversation history ─────────────────────────
    const history = conversationId
      ? await loadConversationHistory(supabaseService, conversationId)
      : [];

    // ─── RAG: Semantic search for relevant chunks ───────────
    let ragContext = '';
    try {
      // Generate embedding for the user message
      const embResp = await fetch('https://openrouter.ai/api/v1/embeddings', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ model: EMBEDDING_MODEL, input: [message] }),
      });

      if (embResp.ok) {
        const embData = await embResp.json();
        const embedding = embData?.data?.[0]?.embedding;

        if (Array.isArray(embedding) && embedding.length > 0) {
          const { data: searchResult } = await supabaseService.rpc('app_prep_semantic_search', {
            p_query_embedding: `[${embedding.join(',')}]`,
            p_subject_id: null,
            p_concours_type: null,
            p_limit: 5,
            p_threshold: 0.3,
          });

          const sr = searchResult as Record<string, unknown> | null;
          if (sr?.success && Array.isArray(sr.chunks)) {
            const chunks = sr.chunks as Array<Record<string, unknown>>;
            if (chunks.length > 0) {
              ragContext = '\n\n=== CONTEXTE DES VRAIS SUJETS DE CONCOURS ===\n';
              ragContext += 'Utilise ces extraits de sujets réels pour enrichir ta réponse. Cite les sources quand pertinent.\n\n';
              for (const chunk of chunks) {
                const src = chunk.concours_type && chunk.year
                  ? ` [${chunk.concours_type} ${chunk.year}]`
                  : chunk.original_filename
                    ? ` [${chunk.original_filename}]`
                    : '';
                ragContext += `---${src}\n${(chunk.content as string || '').slice(0, 600)}\n\n`;
              }
            }
          }
        }
      }
    } catch (ragErr) {
      console.error('RAG search failed (non-blocking):', ragErr);
    }

    // ─── Build messages array ──────────────────────────────
    const messages: ChatMessage[] = [];

    // System prompt with subject context + RAG context
    let finalSystemPrompt = systemPrompt;
    if (subject) {
      finalSystemPrompt += `\n\nL'étudiant travaille actuellement sur la matière : ${subject}. Adapte tes réponses en conséquence.`;
    }
    if (ragContext) {
      finalSystemPrompt += ragContext;
      finalSystemPrompt += '\nQuand tu utilises ces extraits, indique la source (ex: "D\'après le sujet ENAREF 2023..."). Si l\'extrait ne correspond pas à la question, ignore-le.';
    }
    messages.push({ role: 'system', content: finalSystemPrompt });

    // History
    for (const h of history) {
      messages.push(h);
    }

    // New user message
    messages.push({ role: 'user', content: message });

    // ─── Call OpenRouter ─────────────────────────────────────────
    let reply: string;
    try {
      reply = await callOpenRouter(messages, 2048);
    } catch (e) {
      console.error('prep-tutor-chat OpenRouter error', e);
      return new Response(
        JSON.stringify({
          error: 'Erreur IA',
          detail: (e as Error).message ?? 'unknown',
        }),
        {
          status: 502,
          headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
        },
      );
    }

    // ─── Save messages to Supabase ───────────────────────────────
    if (conversationId) {
      // Save user message then assistant reply (fire-and-forget style but awaited)
      await saveMessage(supabaseService, conversationId, 'user', message);
      await saveMessage(supabaseService, conversationId, 'assistant', reply);
    }

    // ─── Response ────────────────────────────────────────────────
    return new Response(JSON.stringify({ reply }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
    });
  } catch (e) {
    console.error('prep-tutor-chat unexpected error', e);
    return new Response(
      JSON.stringify({ error: 'Erreur interne', detail: (e as Error).message ?? 'unknown' }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      },
    );
  }
});
