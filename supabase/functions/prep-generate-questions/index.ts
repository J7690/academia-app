// Supabase Edge Function: prep-generate-questions
// RAG pipeline: semantic search indexed chunks → LLM generates QCM → inserts into prep_questions
// Uses same OPENROUTER_API_KEY as bobodo-chat and prep-tutor-chat.

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

    const body = await req.json();
    const concoursType = (body.concours_type ?? '').toString().trim();
    const subjectName = (body.subject_name ?? '').toString().trim();
    const subjectId = (body.subject_id ?? '').toString().trim() || null;
    const count = Math.min(Math.max(body.count ?? 10, 1), 30);
    const mode = (body.mode ?? 'similar').toString().trim(); // similar, exam_blanc, revision
    const bankId = (body.bank_id ?? '').toString().trim() || null;
    const difficulty = body.difficulty ?? null;

    // ── 1. Build a context query for semantic search ──────────────
    const contextQuery = `Questions QCM ${concoursType || 'concours'} ${subjectName || 'culture générale'} Burkina Faso`;

    // ── 2. Get embedding for the query ────────────────────────────
    const queryEmbedding = await getEmbedding(contextQuery);
    if (queryEmbedding.length === 0) {
      return jsonResponse({ error: 'embedding_failed' }, 500);
    }

    // ── 3. Semantic search for relevant chunks ────────────────────
    const { data: searchData } = await supabase.rpc('app_prep_semantic_search', {
      p_query_embedding: `[${queryEmbedding.join(',')}]`,
      p_subject_id: subjectId,
      p_concours_type: concoursType || null,
      p_limit: 15,
      p_threshold: 0.2,
    });

    let chunks: Array<{ content: string; concours_type?: string; year?: string; similarity?: number }> = [];
    if (searchData && typeof searchData === 'object') {
      const sd = searchData as Record<string, unknown>;
      if (sd.success && Array.isArray(sd.chunks)) {
        chunks = sd.chunks as typeof chunks;
      }
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
    } else {
      // mode === 'similar'
      userPrompt = `Génère ${count} nouvelles questions QCM pour le concours ${concoursType || 'de la fonction publique'} au Burkina Faso.
Matière : ${subjectName || 'Culture Générale'}.
Les questions doivent être du MÊME type, MÊME difficulté et MÊME domaine que les sujets réels.`;
    }

    // Add RAG context if chunks available
    if (chunks.length > 0) {
      userPrompt += `\n\nVoici des extraits de VRAIS sujets de concours pour t'inspirer (NE PAS copier, mais créer des questions similaires) :\n\n`;
      for (const chunk of chunks.slice(0, 10)) {
        const src = chunk.concours_type && chunk.year
          ? ` [Source: ${chunk.concours_type} ${chunk.year}]`
          : '';
        userPrompt += `---${src}\n${chunk.content.slice(0, 500)}\n\n`;
      }
    }

    if (difficulty) {
      userPrompt += `\nNiveau de difficulté cible : ${difficulty}/5.`;
    }

    // ── 5. Call the LLM ───────────────────────────────────────────
    const rawResponse = await callLLM(systemPrompt, userPrompt);

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
    });
  } catch (err: any) {
    console.error('prep-generate-questions error:', err);
    return jsonResponse(
      { error: 'internal_error', message: err?.message?.slice(0, 500) ?? 'unknown' },
      500,
    );
  }
});
