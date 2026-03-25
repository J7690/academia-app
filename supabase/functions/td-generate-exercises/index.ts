// Supabase Edge Function: td-generate-exercises
// RAG pipeline: td_doc_chunks semantic search → LLM generates university-style exercises → td_questions
// SEPARATE from prep-generate-questions (which targets prep_questions for concours)

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? 'google/gemini-2.0-flash-001';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const EMBEDDING_MODEL = 'openai/text-embedding-3-small';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  try {
    const authHeader = req.headers.get('authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    const { data: userData } = await createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false }, global: { headers: { Authorization: `Bearer ${jwt}` } },
    }).auth.getUser(jwt);
    if (!userData?.user) return jsonResponse({ error: 'not_authenticated' }, 401);

    const body = await req.json();
    const subject = (body.subject ?? '').toString().trim();
    const university = (body.university ?? '').toString().trim();
    const studyYear = (body.study_year ?? '').toString().trim();
    const count = Math.min(Math.max(body.count ?? 10, 1), 30);
    const mode = (body.mode ?? 'exercise').toString().trim();
    const bankId = (body.bank_id ?? '').toString().trim() || null;

    // 1. Embedding for semantic search
    const contextQuery = `Exercices ${subject || 'universitaires'} ${university || ''} ${studyYear || ''} Burkina Faso`;
    const embResp = await fetch('https://openrouter.ai/api/v1/embeddings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${OPENROUTER_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: EMBEDDING_MODEL, input: [contextQuery] }),
    });

    let chunks: Array<Record<string, unknown>> = [];
    if (embResp.ok) {
      const embData = await embResp.json();
      const embedding = embData?.data?.[0]?.embedding;
      if (Array.isArray(embedding) && embedding.length > 0) {
        // Search in td_doc_chunks (SEPARATE from prep_doc_chunks)
        const { data: searchData } = await supabase.rpc('app_td_semantic_search', {
          p_query_embedding: `[${embedding.join(',')}]`,
          p_subject: subject || null,
          p_university: university || null,
          p_limit: 15,
          p_threshold: 0.2,
        });
        const sd = searchData as Record<string, unknown> | null;
        if (sd?.success && Array.isArray(sd.chunks)) {
          chunks = sd.chunks as Array<Record<string, unknown>>;
        }
      }
    }

    // 2. Build LLM prompt
    const systemPrompt = `Tu es un expert en création d'exercices universitaires pour le Burkina Faso.
Tu génères des exercices de qualité académique, adaptés au système LMD burkinabè.

RÈGLES :
1. Les exercices doivent correspondre au niveau universitaire (L1, L2, L3, Master)
2. Pour les QCM : 4 options, 1 seule correcte, distracteurs plausibles
3. Pour les exercices ouverts : énoncé clair + correction détaillée avec méthodologie
4. Adapte au contexte burkinabè (exemples locaux, institutions BF, SYSCOHADA pour la compta, etc.)
5. Fournis TOUJOURS la correction détaillée pas à pas
6. Réponds UNIQUEMENT en JSON valide

FORMAT JSON :
{"exercises":[{"question":"...","options":["A. ...","B. ...","C. ...","D. ..."],"correct_index":0,"explanation":"...","difficulty":2,"subject":"..."}]}`;

    let userPrompt = '';
    if (mode === 'td_session') {
      userPrompt = `Compose une feuille de TD complète de ${count} exercices en "${subject || 'matière universitaire'}" pour des étudiants ${studyYear || 'L1-L2'} au Burkina Faso. Mélange QCM et questions de réflexion. Progression de difficulté croissante.`;
    } else if (mode === 'exam') {
      userPrompt = `Compose un sujet d'examen de ${count} questions en "${subject || 'matière'}" niveau ${studyYear || 'L2'}, style université burkinabè. QCM + exercices ouverts avec barème.`;
    } else {
      userPrompt = `Génère ${count} exercices en "${subject || 'matière universitaire'}" adaptés au niveau ${studyYear || 'L1-L2'} des universités du Burkina Faso.`;
    }

    if (chunks.length > 0) {
      userPrompt += `\n\nVoici des extraits de VRAIS cours/sujets universitaires BF pour t'inspirer :\n\n`;
      for (const chunk of chunks.slice(0, 10)) {
        const src = chunk.university ? ` [${chunk.university}]` : '';
        userPrompt += `---${src}\n${(chunk.content as string || '').slice(0, 500)}\n\n`;
      }
    }

    // 3. Call LLM
    const llmResp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${OPENROUTER_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: OPENROUTER_MODEL, messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }], temperature: 0.7, max_tokens: 8000 }),
    });
    if (!llmResp.ok) return jsonResponse({ error: 'llm_error', status: llmResp.status }, 502);

    const llmData = await llmResp.json();
    const rawResponse = llmData?.choices?.[0]?.message?.content?.trim() ?? '';

    // 4. Parse JSON
    let jsonStr = rawResponse;
    const jsonMatch = rawResponse.match(/\{[\s\S]*"exercises"[\s\S]*\}/);
    if (jsonMatch) jsonStr = jsonMatch[0];

    let parsed: { exercises: Array<{ question: string; options?: string[]; correct_index?: number; explanation: string; difficulty?: number; subject?: string }> };
    try { parsed = JSON.parse(jsonStr); } catch { return jsonResponse({ error: 'invalid_json', raw: rawResponse.slice(0, 1000) }, 500); }
    if (!parsed.exercises?.length) return jsonResponse({ error: 'no_exercises' }, 500);

    // 5. Get or use bank ID
    let targetBankId = bankId;
    if (!targetBankId) {
      const { data: bData } = await supabase.rpc('admin_execute_sql', {
        p_sql: "SELECT id FROM app.td_question_banks WHERE title = 'Contenu Universitaire BF' LIMIT 1",
      });
      const bd = bData as Record<string, unknown> | null;
      if (bd?.ok && Array.isArray(bd.rows) && bd.rows.length > 0) {
        targetBankId = (bd.rows[0] as Record<string, unknown>).id as string;
      }
    }

    // 6. Insert into td_questions (SEPARATE from prep_questions)
    let insertedCount = 0;
    for (const ex of parsed.exercises) {
      const qText = (ex.question ?? '').toString().trim();
      if (!qText) continue;
      const options = Array.isArray(ex.options) ? ex.options.map((o: string) => o.replace(/^[A-D]\.\s*/, '').trim()) : [];
      const correctIdx = typeof ex.correct_index === 'number' ? ex.correct_index : 0;
      const explanation = (ex.explanation ?? '').toString().trim();
      const diff = ex.difficulty ?? 2;
      const subj = ex.subject || subject || 'Universitaire';

      const escapedQ = qText.replace(/'/g, "''");
      const escapedExpl = explanation.replace(/'/g, "''");
      const escapedSubj = subj.replace(/'/g, "''");
      const optionsJson = JSON.stringify(options).replace(/'/g, "''");

      const insertSql = `INSERT INTO app.td_questions (${targetBankId ? `bank_id,` : ''} question_type, content, options, correct_index, explanation, difficulty, subject, is_active) VALUES (${targetBankId ? `'${targetBankId}',` : ''} 'mcq', '${escapedQ}', '${optionsJson}'::jsonb, ${correctIdx}, '${escapedExpl}', ${diff}, '${escapedSubj}', true)`;

      try {
        const { data: ir } = await supabase.rpc('admin_execute_sql', { p_sql: insertSql.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim() });
        if ((ir as Record<string, unknown>)?.ok) insertedCount++;
      } catch {}
    }

    return jsonResponse({
      success: true,
      generated_count: parsed.exercises.length,
      inserted_count: insertedCount,
      chunks_used: chunks.length,
      mode,
      target: 'td_questions',
    });
  } catch (err: any) {
    console.error('td-generate-exercises error:', err);
    return jsonResponse({ error: 'internal_error', message: err?.message?.slice(0, 500) }, 500);
  }
});
