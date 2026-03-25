// Supabase Edge Function: td-tutor-chat
// AI Tutor for TD (Travaux Dirigés) module — SEPARATE from prep-tutor-chat.
// Uses td_ai_config for system prompt, td_doc_chunks for RAG semantic search.
// Adapted to Burkina Faso university system (UJK, UNB, UTS, UCAO, etc.)

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

const DEFAULT_SYSTEM_PROMPT =
  "Tu es un tuteur expert en cours d'appui universitaire au Burkina Faso. " +
  "Tu aides les étudiants des universités burkinabè (Joseph Ki-Zerbo, Nazi Boni, Norbert Zongo, Thomas Sankara, Aube Nouvelle, etc.) " +
  "dans TOUTES les filières : mathématiques, physique, chimie, biologie, droit, économie, gestion, comptabilité SYSCOHADA, " +
  "sciences humaines, lettres, langues, informatique, médecine, pharmacie, sciences de l'ingénieur, agronomie. " +
  "Tu utilises la méthode socratique : tu ne donnes JAMAIS la réponse directement. " +
  "Tu guides l'étudiant pas à pas en posant des questions orientées. " +
  "Si l'étudiant bloque, tu donnes un indice progressif. " +
  "À la fin, tu fournis la correction détaillée + la méthodologie. " +
  "Langue : français. Contexte : système LMD burkinabè.";

type ChatMessage = { role: 'user' | 'assistant' | 'system'; content: string };

async function callOpenRouter(messages: ChatMessage[], maxTokens = 2048): Promise<string> {
  if (!OPENROUTER_API_KEY || !OPENROUTER_MODEL) throw new Error('OPENROUTER not configured');
  const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${OPENROUTER_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: OPENROUTER_MODEL, messages, temperature: 0.7, top_p: 0.95, max_tokens: maxTokens }),
  });
  if (!resp.ok) throw new Error(`OpenRouter error: ${resp.status}`);
  const data = await resp.json();
  return data?.choices?.[0]?.message?.content?.trim() ?? '';
}

async function loadSystemPrompt(supabase: ReturnType<typeof createClient>): Promise<string> {
  try {
    // Load from td_ai_config (SEPARATE from prep_ai_config)
    const { data } = await supabase.rpc('admin_execute_sql', {
      p_sql: "SELECT config_value FROM app.td_ai_config WHERE config_key = 'system_prompt' LIMIT 1",
    });
    const d = data as Record<string, unknown> | null;
    if (d?.ok && Array.isArray(d.rows) && d.rows.length > 0) {
      return (d.rows[0] as Record<string, unknown>).config_value as string || DEFAULT_SYSTEM_PROMPT;
    }
  } catch {}
  return DEFAULT_SYSTEM_PROMPT;
}

async function loadConversationHistory(supabase: ReturnType<typeof createClient>, convId: string): Promise<ChatMessage[]> {
  try {
    // Load from td_ai_messages (SEPARATE from prep_ai_messages)
    const { data } = await supabase.rpc('admin_execute_sql', {
      p_sql: `SELECT role, content FROM app.td_ai_messages WHERE conversation_id = '${convId}' ORDER BY created_at DESC LIMIT 20`,
    });
    const d = data as Record<string, unknown> | null;
    if (d?.ok && Array.isArray(d.rows)) {
      return (d.rows as Array<Record<string, unknown>>).reverse().map((r) => ({
        role: (r.role as string) === 'assistant' ? 'assistant' : 'user',
        content: r.content as string,
      }));
    }
  } catch {}
  return [];
}

async function saveMessage(supabase: ReturnType<typeof createClient>, convId: string, role: string, content: string): Promise<void> {
  try {
    // Save to td_ai_messages (SEPARATE)
    await supabase.rpc('admin_execute_sql', {
      p_sql: `INSERT INTO app.td_ai_messages (conversation_id, role, content, tokens_used) VALUES ('${convId}', '${role}', '${content.replace(/'/g, "''")}', 0)`,
    });
  } catch {}
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== 'POST') return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });

  try {
    const authHeader = req.headers.get('authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
    const apiKeyHeader = req.headers.get('apikey') ?? SUPABASE_SERVICE_ROLE_KEY;

    const supabaseService = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const supabaseUser = createClient(SUPABASE_URL, apiKeyHeader, { global: { headers: { Authorization: `Bearer ${jwt}` } } });

    const { data: userData } = await supabaseUser.auth.getUser(jwt);
    if (!userData?.user) return new Response(JSON.stringify({ error: 'not_authenticated' }), { status: 401, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });

    const body = await req.json().catch(() => null);
    if (!body) return new Response(JSON.stringify({ error: 'invalid_body' }), { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });

    const message = ((body as any).message ?? '').toString().trim();
    const conversationId = ((body as any).conversation_id ?? '').toString().trim();
    const subject = ((body as any).subject ?? '').toString().trim();
    if (!message) return new Response(JSON.stringify({ error: 'empty_message' }), { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });

    const systemPrompt = await loadSystemPrompt(supabaseService);
    const history = conversationId ? await loadConversationHistory(supabaseService, conversationId) : [];

    // RAG: Semantic search in td_doc_chunks (SEPARATE from prep_doc_chunks)
    let ragContext = '';
    try {
      const embResp = await fetch('https://openrouter.ai/api/v1/embeddings', {
        method: 'POST',
        headers: { Authorization: `Bearer ${OPENROUTER_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: EMBEDDING_MODEL, input: [message] }),
      });
      if (embResp.ok) {
        const embData = await embResp.json();
        const embedding = embData?.data?.[0]?.embedding;
        if (Array.isArray(embedding) && embedding.length > 0) {
          // Call td_semantic_search (SEPARATE RPC)
          const { data: searchResult } = await supabaseService.rpc('app_td_semantic_search', {
            p_query_embedding: `[${embedding.join(',')}]`,
            p_subject: subject || null,
            p_university: null,
            p_limit: 5,
            p_threshold: 0.3,
          });
          const sr = searchResult as Record<string, unknown> | null;
          if (sr?.success && Array.isArray(sr.chunks) && (sr.chunks as unknown[]).length > 0) {
            ragContext = '\n\n=== CONTEXTE PÉDAGOGIQUE (cours et sujets universitaires BF) ===\n';
            ragContext += 'Utilise ces extraits pour enrichir ta réponse. Cite les sources quand pertinent.\n\n';
            for (const chunk of sr.chunks as Array<Record<string, unknown>>) {
              const src = chunk.university ? ` [${chunk.university}]` : chunk.original_filename ? ` [${chunk.original_filename}]` : '';
              ragContext += `---${src}\n${(chunk.content as string || '').slice(0, 600)}\n\n`;
            }
          }
        }
      }
    } catch (ragErr) {
      console.error('TD RAG search failed (non-blocking):', ragErr);
    }

    // Build messages
    const messages: ChatMessage[] = [];
    let finalSystemPrompt = systemPrompt;
    if (subject) finalSystemPrompt += `\n\nL'étudiant travaille sur : ${subject}. Adapte tes réponses.`;
    if (ragContext) {
      finalSystemPrompt += ragContext;
      finalSystemPrompt += '\nQuand tu utilises ces extraits, indique la source. Si non pertinent, ignore-les.';
    }
    messages.push({ role: 'system', content: finalSystemPrompt });
    for (const h of history) { messages.push(h); }
    messages.push({ role: 'user', content: message });

    const reply = await callOpenRouter(messages, 2048);

    if (conversationId) {
      await saveMessage(supabaseService, conversationId, 'user', message);
      await saveMessage(supabaseService, conversationId, 'assistant', reply);
    }

    return new Response(JSON.stringify({ reply }), { status: 200, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });
  } catch (e) {
    console.error('td-tutor-chat error:', e);
    return new Response(JSON.stringify({ error: 'internal_error', detail: (e as Error).message?.slice(0, 500) }), { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });
  }
});
