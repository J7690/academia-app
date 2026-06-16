// Supabase Edge Function: td-generate-exercises
// RAG pipeline: td_doc_chunks semantic search → LLM generates university-style exercises → td_questions
// SEPARATE from prep-generate-questions (which targets prep_questions for concours)

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';
const OPENROUTER_EMBEDDING_MODEL = Deno.env.get('OPENROUTER_EMBEDDING_MODEL') ?? 'openai/text-embedding-3-small';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const ACTION_CODE = 'generate_qcm';
const EDGE_FN = 'td-generate-exercises';
const TEXT_CASCADE = [
  { model: OPENROUTER_MODEL, tier: 'primary' },
  { model: OPENROUTER_FALLBACK_MODEL, tier: 'fallback' },
].filter(m => m.model);
interface CascadeResult { content: string; model: string; tier: string; usage: { prompt_tokens: number; completion_tokens: number; total_tokens: number }; costUsd: number; }
async function callWithCascade(msgs: Array<{role:string;content:string}>, maxTok: number): Promise<CascadeResult> {
  const errs: string[] = [];
  for (const { model, tier } of TEXT_CASCADE) {
    if (!model) continue;
    try {
      const r = await fetch('https://openrouter.ai/api/v1/chat/completions', { method:'POST', headers:{Authorization:`Bearer ${OPENROUTER_API_KEY}`,'Content-Type':'application/json',Accept:'application/json'}, body:JSON.stringify({model,messages:msgs,temperature:0.7,max_tokens:maxTok}) });
      if (!r.ok) { errs.push(`${model}(${r.status})`); continue; }
      const d = await r.json(); const c = (d?.choices?.[0]?.message?.content??'').toString().trim();
      if (!c) { errs.push(`${model}:empty`); continue; }
      const u = d?.usage ?? {prompt_tokens:0,completion_tokens:0,total_tokens:0};
      const cost = tier==='free'?0:((u.prompt_tokens||0)*0.0000001+(u.completion_tokens||0)*0.0000004);
      console.log(`[cascade] OK: ${model} (${tier}) ${u.total_tokens}tok $${cost.toFixed(6)}`);
      return {content:c,model,tier,usage:u,costUsd:cost};
    } catch(e) { errs.push(`${model}:${(e as Error).message?.slice(0,60)}`); }
  }
  throw new Error(`All models failed: ${errs.join(' | ')}`);
}

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

    const userId = userData.user.id;
    const body = await req.json();
    const subject = (body.subject ?? '').toString().trim();
    const university = (body.university ?? '').toString().trim();
    const studyYear = (body.study_year ?? '').toString().trim();
    const field = (body.field ?? '').toString().trim();
    const semester = (body.semester ?? '').toString().trim();
    const count = Math.min(Math.max(body.count ?? 10, 1), 30);
    const mode = (body.mode ?? 'exercise').toString().trim();
    const bankId = (body.bank_id ?? '').toString().trim() || null;
    const totalPoints = body.total_points ?? 20;
    const durationMinutes = body.duration_minutes ?? 60;
    const assignmentTitle = (body.title ?? '').toString().trim();

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

    const fieldInfo = field ? `, filière ${field}` : '';
    const semesterInfo = semester ? `, semestre ${semester}` : '';
    const levelInfo = studyYear || 'L1-L2';

    let userPrompt = '';
    if (mode === 'td_session') {
      userPrompt = `Compose une feuille de TD complète de ${count} exercices en "${subject || 'matière universitaire'}" pour des étudiants ${levelInfo}${fieldInfo}${semesterInfo} au Burkina Faso. Mélange QCM et questions de réflexion. Progression de difficulté croissante. Barème total : ${totalPoints} points. Durée indicative : ${durationMinutes} minutes.`;
    } else if (mode === 'exam') {
      userPrompt = `Compose un sujet d'examen de ${count} questions en "${subject || 'matière'}" niveau ${levelInfo}${fieldInfo}${semesterInfo}, style université burkinabè. QCM + exercices ouverts avec barème. Total : ${totalPoints} points. Durée : ${durationMinutes} minutes.`;
    } else {
      userPrompt = `Génère ${count} exercices en "${subject || 'matière universitaire'}" adaptés au niveau ${levelInfo}${fieldInfo}${semesterInfo} des universités du Burkina Faso.`;
    }

    if (chunks.length > 0) {
      userPrompt += `\n\nVoici des extraits de VRAIS cours/sujets universitaires BF pour t'inspirer :\n\n`;
      for (const chunk of chunks.slice(0, 10)) {
        const src = chunk.university ? ` [${chunk.university}]` : '';
        userPrompt += `---${src}\n${(chunk.content as string || '').slice(0, 500)}\n\n`;
      }
    }

    // 3. Reserve credits
    const { data: resData } = await supabase.rpc('app_student_reserve_credits', {
      p_action_code: ACTION_CODE, p_edge_function: EDGE_FN, p_student_id: userId,
    });
    const res = resData as Record<string, unknown> | null;
    if (!res?.success) {
      return jsonResponse({ error: 'insufficient_credits', balance: res?.balance ?? 0, cost: res?.cost ?? 0,
        message: `Crédits insuffisants. Il vous faut ${res?.cost??0} crédits (solde: ${res?.balance??0}).` }, 402);
    }
    const reservationId = (res.reservation_id as string) || '';

    // 3b. Call LLM with cascade
    let cascadeResult: CascadeResult;
    try {
      cascadeResult = await callWithCascade([{role:'system',content:systemPrompt},{role:'user',content:userPrompt}], 8000);
    } catch (e) {
      await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      return jsonResponse({ error: 'llm_error', detail: (e as Error).message?.slice(0,300) }, 502);
    }

    // 3c. Confirm credits
    await supabase.rpc('app_student_confirm_credits', {
      p_reservation_id: reservationId, p_openrouter_cost_usd: cascadeResult.costUsd,
      p_openrouter_model: cascadeResult.model, p_tokens_input: cascadeResult.usage.prompt_tokens||0,
      p_tokens_output: cascadeResult.usage.completion_tokens||0,
    });

    const rawResponse = cascadeResult.content;

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

    // 6. Insert into td_questions with new columns
    let insertedCount = 0;
    const fieldSql = field ? `'${field.replace(/'/g, "''")}'` : 'NULL';
    const yearSql = studyYear ? `'${studyYear.replace(/'/g, "''")}'` : 'NULL';
    const semSql = semester ? `'${semester.replace(/'/g, "''")}'` : 'NULL';

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

      const cols = [
        targetBankId ? 'bank_id,' : '',
        'question_type, content, options, correct_index, explanation, difficulty, subject, is_active,',
        'field, study_year, semester, generation_mode, generated_by',
      ].join(' ');
      const vals = [
        targetBankId ? `'${targetBankId}',` : '',
        `'mcq', '${escapedQ}', '${optionsJson}'::jsonb, ${correctIdx}, '${escapedExpl}', ${diff}, '${escapedSubj}', true,`,
        `${fieldSql}, ${yearSql}, ${semSql}, '${mode}', '${userId}'`,
      ].join(' ');

      const insertSql = `INSERT INTO app.td_questions (${cols}) VALUES (${vals})`;
      try {
        const { data: ir } = await supabase.rpc('admin_execute_sql', { p_sql: insertSql.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim() });
        if ((ir as Record<string, unknown>)?.ok) insertedCount++;
      } catch {}
    }

    // 7. Save as a generated assignment (devoir type)
    let assignmentId: string | null = null;
    if (mode === 'exam' || mode === 'td_session') {
      const aTitle = assignmentTitle || `${mode === 'exam' ? 'Devoir type' : 'Feuille TD'} — ${subject || 'Universitaire'} ${studyYear || ''} ${semester || ''}`.trim();
      const escapedTitle = aTitle.replace(/'/g, "''");
      const questionsJsonStr = JSON.stringify(parsed.exercises).replace(/'/g, "''");

      const assignSql = `INSERT INTO app.td_generated_assignments (student_id, title, subject, field, study_year, semester, mode, question_count, total_points, duration_minutes, questions_json, status) VALUES ('${userId}', '${escapedTitle}', '${(subject || 'Universitaire').replace(/'/g, "''")}', ${fieldSql}, ${yearSql}, ${semSql}, '${mode}', ${parsed.exercises.length}, ${totalPoints}, ${durationMinutes}, '${questionsJsonStr}'::jsonb, 'generated') RETURNING id`;

      try {
        const { data: aData } = await supabase.rpc('admin_execute_sql', { p_sql: assignSql.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim() });
        const ad = aData as Record<string, unknown> | null;
        if (ad?.ok && Array.isArray(ad.rows) && ad.rows.length > 0) {
          assignmentId = (ad.rows[0] as Record<string, unknown>).id as string;
        }
      } catch (e) {
        console.error('Failed to save generated assignment:', e);
      }
    }

    return jsonResponse({
      success: true,
      generated_count: parsed.exercises.length,
      inserted_count: insertedCount,
      chunks_used: chunks.length,
      mode,
      target: 'td_questions',
      assignment_id: assignmentId,
      exercises: parsed.exercises,
      total_points: totalPoints,
      duration_minutes: durationMinutes,
      credits_used: res.cost,
      model: cascadeResult.model,
    });
  } catch (err: any) {
    console.error('td-generate-exercises error:', err);
    return jsonResponse({ error: 'internal_error', message: err?.message?.slice(0, 500) }, 500);
  }
});
