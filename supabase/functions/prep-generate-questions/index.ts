// Supabase Edge Function: prep-generate-questions
// RAG pipeline: semantic search indexed chunks → LLM generates QCM → inserts into prep_questions
// Uses same OPENROUTER_API_KEY as bobodo-chat and prep-tutor-chat.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';
const OPENROUTER_EMBEDDING_MODEL = Deno.env.get('OPENROUTER_EMBEDDING_MODEL') ?? 'openai/text-embedding-3-small';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const ACTION_CODE = 'generate_qcm';
const EDGE_FN = 'prep-generate-questions';
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
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

// ─── Generate embedding for a text query ──────────────────────────────
async function getEmbedding(text: string): Promise<number[]> {
  const resp = await fetch('https://openrouter.ai/api/v1/embeddings', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ model: EMBEDDING_MODEL, input: [text] }),
  });

  if (!resp.ok) {
    throw new Error(`Embedding failed: ${resp.status}`);
  }

  const data = await resp.json();
  return data?.data?.[0]?.embedding ?? [];
}

// ─── Call LLM to generate questions ───────────────────────────────────
async function callLLM(systemPrompt: string, userPrompt: string): Promise<string> {
  const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: OPENROUTER_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.7,
      max_tokens: 8000,
    }),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`LLM error (${resp.status}): ${text.slice(0, 500)}`);
  }

  const data = await resp.json();
  return data?.choices?.[0]?.message?.content?.trim() ?? '';
}

// ─── Main handler ─────────────────────────────────────────────────────
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const authHeader = req.headers.get('authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // Verify auth
    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data: userData, error: userError } = await supabaseUser.auth.getUser(jwt);
    if (userError || !userData?.user) {
      return jsonResponse({ error: 'not_authenticated' }, 401);
    }
    const userId = userData.user.id;

    const body = await req.json();
    const concoursType = (body.concours_type ?? '').toString().trim();
    const subjectName = (body.subject_name ?? '').toString().trim();
    const subjectId = (body.subject_id ?? '').toString().trim() || null;
    const count = Math.min(Math.max(body.count ?? 10, 1), 30);
    const mode = (body.mode ?? 'similar').toString().trim(); // similar, exam_blanc, revision, adaptive
    const bankId = (body.bank_id ?? '').toString().trim() || null;
    const difficulty = body.difficulty ?? null;

    // ── 1. Build a context query for semantic search ──────────────
    const contextQuery = `Questions QCM ${concoursType || 'concours'} ${subjectName || 'culture générale'} Burkina Faso`;

    // ── 2. Get embedding for the query ────────────────────────────
    let queryEmbedding: number[] = [];
    try {
      queryEmbedding = await getEmbedding(contextQuery);
    } catch (embErr) {
      console.error('Embedding failed (will try fallback):', embErr);
    }

    // ── 3. Semantic search for relevant chunks ────────────────────
    let chunks: Array<{ content: string; concours_type?: string; year?: string; similarity?: number; doc_type?: string }> = [];

    if (queryEmbedding.length > 0) {
      const { data: searchData } = await supabase.rpc('app_prep_semantic_search', {
        p_query_embedding: `[${queryEmbedding.join(',')}]`,
        p_subject_id: subjectId,
        p_concours_type: concoursType || null,
        p_limit: 15,
        p_threshold: 0.2,
      });

      if (searchData && typeof searchData === 'object') {
        const sd = searchData as Record<string, unknown>;
        if (sd.success && Array.isArray(sd.chunks)) {
          chunks = sd.chunks as typeof chunks;
        }
      }
    }

    // ── 3b. Fallback RAG: keyword-based chunks (no embeddings needed) ──
    // If semantic search found nothing, try fetching chunks by subject name.
    // This allows pasted text (without embeddings) to be used immediately.
    if (chunks.length === 0 && (subjectName || subjectId)) {
      try {
        const { data: fallbackResult } = await supabase.rpc(
          'app_prep_get_rag_chunks_by_name',
          {
            p_subject_name: subjectName || null,
            p_concours_type: concoursType || null,
            p_limit: 10,
            p_max_chars: 10000,
          },
        );

        const fb = fallbackResult as Record<string, unknown> | null;
        if (fb?.success && Array.isArray(fb.chunks) && (fb.chunks as any[]).length > 0) {
          chunks = (fb.chunks as any[]).map((c: any) => ({
            content: c.content ?? '',
            concours_type: c.concours_type ?? undefined,
            year: c.year ?? undefined,
            doc_type: c.doc_type ?? undefined,
          }));
        }
      } catch (fbErr) {
        console.error('RAG fallback failed (non-blocking):', fbErr);
      }
    }

    // ── 3c. Fetch trend predictions to guide question generation ────
    let trendContext = '';
    try {
      const { data: predData } = await supabase.rpc('admin_execute_sql', {
        p_sql: `SELECT t.name AS topic, t.category, tp.probability_score, tp.frequency_count, tp.last_appeared_year, tp.cycle_years, tp.reasoning FROM app.prep_topic_predictions tp JOIN app.prep_topics t ON t.id = tp.topic_id WHERE tp.probability_score >= 50 ${concoursType ? `AND (tp.concours_type = '${concoursType.replace(/'/g, "''")}' OR tp.concours_type = 'TOUS')` : ''} ORDER BY tp.probability_score DESC LIMIT 10`,
      });
      const pd = predData as Record<string, unknown> | null;
      if (pd?.ok && Array.isArray(pd.rows) && (pd.rows as any[]).length > 0) {
        const predictions = pd.rows as Array<Record<string, unknown>>;
        trendContext = '\n\n=== THÈMES À FORTE PROBABILITÉ (analyse des tendances) ===\n';
        trendContext += 'Ces thèmes ont une forte probabilité de tomber au prochain concours. PRIORISE-les dans tes questions :\n\n';
        for (const p of predictions) {
          trendContext += `• ${p.topic} (probabilité: ${p.probability_score}%) — ${p.reasoning || ''}\n`;
        }
        trendContext += '\nGénère AU MOINS 30% des questions sur ces thèmes prioritaires.\n';
        console.log(`[trends] Injected ${predictions.length} trend predictions into prompt`);
      }
    } catch (trendErr) {
      console.error('Trend predictions fetch failed (non-blocking):', trendErr);
    }

    // ── 3d. Fetch recent relevant actualities for context ────────────
    let actualityContext = '';
    try {
      const { data: actData } = await supabase.rpc('admin_execute_sql', {
        p_sql: `SELECT title, LEFT(scoring_reason, 200) AS reason, relevance_score FROM app.prep_news_articles WHERE is_concours_relevant = true AND relevance_score >= 0.5 ORDER BY published_at DESC LIMIT 5`,
      });
      const ad = actData as Record<string, unknown> | null;
      if (ad?.ok && Array.isArray(ad.rows) && (ad.rows as any[]).length > 0) {
        const articles = ad.rows as Array<Record<string, unknown>>;
        actualityContext = '\n\n=== ACTUALITÉS RÉCENTES PERTINENTES CONCOURS ===\n';
        actualityContext += 'Ces actualités récentes du Burkina Faso sont susceptibles de tomber au concours :\n\n';
        for (const a of articles) {
          actualityContext += `• ${a.title} (pertinence: ${a.relevance_score})\n`;
        }
        actualityContext += '\nIntègre ces actualités dans tes questions de Culture Générale / Actualités BF si pertinent.\n';
      }
    } catch (actErr) {
      console.error('Actuality fetch failed (non-blocking):', actErr);
    }

    // ── 4. Build the LLM prompt ───────────────────────────────────
    const systemPrompt = `Tu es un expert en création de QCM pour les concours de la fonction publique du Burkina Faso.
Tu dois générer des questions de qualité professionnelle, réalistes, similaires aux vrais sujets de concours.

RÈGLES STRICTES :
1. Chaque question a exactement 4 options (A, B, C, D)
2. Une seule réponse correcte par question
3. Les distracteurs (mauvaises réponses) doivent être plausibles
4. Fournis une explication détaillée pour chaque bonne réponse
5. Adapte la difficulté au niveau du concours
6. Utilise le contexte du Burkina Faso (institutions, lois, géographie)
7. Réponds UNIQUEMENT en JSON valide, sans markdown, sans commentaire

FORMAT JSON REQUIS :
{"questions":[{"question":"...","options":["A. ...","B. ...","C. ...","D. ..."],"correct_index":0,"explanation":"...","difficulty":1,"subject":"..."}]}`;

    let userPrompt = '';

    if (mode === 'exam_blanc') {
      userPrompt = `Compose un examen blanc complet de ${count} QCM pour le concours ${concoursType || 'de la fonction publique'} au Burkina Faso.
Matière principale : ${subjectName || 'Culture Générale'}.
Mélange les niveaux de difficulté (facile, moyen, difficile).
Les questions doivent couvrir les thèmes classiques de ce type de concours.`;
    } else if (mode === 'revision') {
      userPrompt = `Génère ${count} questions de révision ciblée en "${subjectName || 'Culture Générale'}" pour le concours ${concoursType || 'de la fonction publique'} au Burkina Faso.
Commence par des questions faciles puis augmente progressivement la difficulté.
Concentre-toi sur les concepts fondamentaux qui reviennent fréquemment aux concours.`;
    } else if (mode === 'adaptive') {
      // Mode adaptatif : récupérer l'analyse des faiblesses
      let weaknessAnalysis: any = null;
      try {
        const { data: weaknessData } = await supabase.rpc('app_prep_get_weakness_analysis');
        weaknessAnalysis = weaknessData;
      } catch (e) {
        console.error('Error fetching weakness analysis:', e);
      }

      if (weaknessAnalysis && weaknessAnalysis.weakest_subjects && weaknessAnalysis.weakest_subjects.length > 0) {
        const weakest = weaknessAnalysis.weakest_subjects[0];
        userPrompt = `Mode Adaptatif : L'étudiant a des difficultés en "${weakest.subject_name}" (taux de réussite: ${weakest.success_rate}%).
Il a répondu à ${weakest.total_questions} questions avec ${weakest.correct_answers} bonnes réponses.
Difficulté recommandée : ${weakest.recommended_difficulty}/5.

Génère ${count} questions QCM adaptées pour l'aider à progresser :
1. Utilise un niveau de difficulté approprié (${weakest.recommended_difficulty}/5)
2. Commence par renforcer les bases si le taux de réussite est < 50%
3. Fournis des explications très détaillées et pédagogiques
4. Évite les pièges trop complexes, l'objectif est d'apprendre
5. Cible les concepts clés de "${weakest.subject_name}" pour le concours ${concoursType || 'de la fonction publique'} au Burkina Faso`;
      } else {
        // Pas de données de faiblesse, mode découverte
        userPrompt = `Mode Adaptatif Initial : Génère ${count} questions variées en "${subjectName || 'Culture Générale'}" pour évaluer le niveau de l'étudiant.
Mélange les difficultés (1 à 4/5) pour identifier ses forces et faiblesses.
Concours : ${concoursType || 'de la fonction publique'} au Burkina Faso.`;
      }
    } else {
      // mode === 'similar'
      userPrompt = `Génère ${count} nouvelles questions QCM pour le concours ${concoursType || 'de la fonction publique'} au Burkina Faso.
Matière : ${subjectName || 'Culture Générale'}.
Les questions doivent être du MÊME type, MÊME difficulté et MÊME domaine que les sujets réels.`;
    }

    // Add RAG context if chunks available
    if (chunks.length > 0) {
      userPrompt += `\n\nVoici des informations complémentaires pour t'inspirer (NE PAS copier, mais créer des questions originales basées sur ces connaissances) :\n\n`;
      for (const chunk of chunks.slice(0, 10)) {
        userPrompt += `---\n${chunk.content.slice(0, 500)}\n\n`;
      }
    }

    // Inject trend predictions into prompt
    if (trendContext) {
      userPrompt += trendContext;
    }

    // Inject recent actualities into prompt
    if (actualityContext) {
      userPrompt += actualityContext;
    }

    if (difficulty) {
      userPrompt += `\nNiveau de difficulté cible : ${difficulty}/5.`;
    }

    // ── 5. Reserve credits ─────────────────────────────────────────
    const { data: resData } = await supabase.rpc('app_student_reserve_credits', {
      p_action_code: ACTION_CODE, p_edge_function: EDGE_FN, p_student_id: userId,
    });
    const res = resData as Record<string, unknown> | null;
    if (!res?.success) {
      return jsonResponse({ error: 'insufficient_credits', balance: res?.balance ?? 0, cost: res?.cost ?? 0,
        message: `Crédits insuffisants. Il vous faut ${res?.cost??0} crédits (solde: ${res?.balance??0}).` }, 402);
    }
    const reservationId = (res.reservation_id as string) || '';

    // ── 5b. Call the LLM with cascade ──────────────────────────────
    let cascadeResult: CascadeResult;
    try {
      cascadeResult = await callWithCascade([{role:'system',content:systemPrompt},{role:'user',content:userPrompt}], 8000);
    } catch (e) {
      await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      return jsonResponse({ error: 'llm_error', detail: (e as Error).message?.slice(0,300) }, 502);
    }

    // ── 5c. Confirm credits ────────────────────────────────────────
    await supabase.rpc('app_student_confirm_credits', {
      p_reservation_id: reservationId, p_openrouter_cost_usd: cascadeResult.costUsd,
      p_openrouter_model: cascadeResult.model, p_tokens_input: cascadeResult.usage.prompt_tokens||0,
      p_tokens_output: cascadeResult.usage.completion_tokens||0,
    });

    const rawResponse = cascadeResult.content;

    // ── 6. Parse JSON response ────────────────────────────────────
    // Try to extract JSON from the response (sometimes LLMs wrap in markdown)
    let jsonStr = rawResponse;
    const jsonMatch = rawResponse.match(/\{[\s\S]*"questions"[\s\S]*\}/);
    if (jsonMatch) {
      jsonStr = jsonMatch[0];
    }

    let parsed: { questions: Array<{
      question: string;
      options: string[];
      correct_index: number;
      explanation: string;
      difficulty?: number;
      subject?: string;
    }> };

    try {
      parsed = JSON.parse(jsonStr);
    } catch {
      return jsonResponse({
        error: 'invalid_json',
        raw: rawResponse.slice(0, 1000),
      }, 500);
    }

    if (!parsed.questions || !Array.isArray(parsed.questions) || parsed.questions.length === 0) {
      return jsonResponse({ error: 'no_questions_generated', raw: rawResponse.slice(0, 500) }, 500);
    }

    // ── 7. Insert questions into prep_questions ───────────────────
    let insertedCount = 0;
    const insertedIds: string[] = [];

    for (const q of parsed.questions) {
      const qText = (q.question ?? '').toString().trim();
      if (!qText) continue;

      const options = Array.isArray(q.options) ? q.options : [];
      if (options.length < 2) continue;

      // Clean option labels (remove "A. ", "B. " etc.)
      const cleanedOptions = options.map((o: string) => o.replace(/^[A-D]\.\s*/, '').trim());

      const correctIdx = typeof q.correct_index === 'number' ? q.correct_index : 0;
      const explanation = (q.explanation ?? '').toString().trim();
      const diff = q.difficulty ?? 2;
      const subj = q.subject || subjectName || 'Culture Générale';

      const optionsJson = JSON.stringify(cleanedOptions).replace(/'/g, "''");
      const escapedQ = qText.replace(/'/g, "''");
      const escapedExpl = explanation.replace(/'/g, "''");
      const escapedSubj = subj.replace(/'/g, "''");

      // Insert question
      const insertSql = `
        INSERT INTO app.prep_questions (
          ${subjectId ? `subject_id,` : ''} ${bankId ? `bank_id,` : ''}
          question, content, options, correct_index, explanation,
          difficulty, subject, concours_type,
          question_type, level, source, is_published, is_active
        ) VALUES (
          ${subjectId ? `'${subjectId}',` : ''} ${bankId ? `'${bankId}',` : ''}
          '${escapedQ}', '${escapedQ}', '${optionsJson}'::jsonb, ${correctIdx}, '${escapedExpl}',
          ${diff}, '${escapedSubj}', ${concoursType ? `'${concoursType}'` : 'NULL'},
          'mcq', 'beginner', 'ai_generated', true, true
        ) RETURNING id
      `.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();

      try {
        const { data: insertResult } = await supabase.rpc('admin_execute_sql', { p_sql: insertSql });
        const ir = insertResult as Record<string, unknown> | null;
        if (ir && ir.ok && Array.isArray(ir.rows) && ir.rows.length > 0) {
          const questionId = (ir.rows[0] as Record<string, unknown>).id as string;
          insertedIds.push(questionId);

          // Insert choices
          for (let i = 0; i < cleanedOptions.length; i++) {
            const label = String.fromCharCode(65 + i); // A, B, C, D
            const choiceText = cleanedOptions[i].replace(/'/g, "''");
            const isCorrect = i === correctIdx;
            const choiceSql = `INSERT INTO app.prep_question_choices (question_id, choice_label, choice_text, is_correct, sort_order) VALUES ('${questionId}', '${label}', '${choiceText}', ${isCorrect}, ${i})`;
            await supabase.rpc('admin_execute_sql', { p_sql: choiceSql });
          }

          insertedCount++;
        }
      } catch (e) {
        console.error(`Failed to insert question: ${qText.slice(0, 50)}`, e);
      }
    }

    // ── 8. Log generation in prep_ai_generations ──────────────────
    const genLogSql = `
      INSERT INTO app.prep_ai_generations (
        created_by, subject_id, generation_type, input_params, output_json, status
      ) VALUES (
        '${userData.user.id}',
        ${subjectId ? `'${subjectId}'` : 'NULL'},
        'mcq',
        '${JSON.stringify({ concours_type: concoursType, subject_name: subjectName, count, mode, chunks_used: chunks.length }).replace(/'/g, "''")}'::jsonb,
        '${JSON.stringify(parsed).replace(/'/g, "''")}'::jsonb,
        'validated'
      )
    `.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();

    await supabase.rpc('admin_execute_sql', { p_sql: genLogSql });

    return jsonResponse({
      success: true,
      generated_count: parsed.questions.length,
      inserted_count: insertedCount,
      inserted_ids: insertedIds,
      chunks_used: chunks.length,
      mode,
      credits_used: res.cost,
      model: cascadeResult.model,
    });
  } catch (err: any) {
    console.error('prep-generate-questions error:', err);
    return jsonResponse(
      { error: 'internal_error', message: err?.message?.slice(0, 500) ?? 'unknown' },
      500,
    );
  }
});
