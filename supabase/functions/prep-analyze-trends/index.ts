// Supabase Edge Function: prep-analyze-trends
// Analyzes indexed chunks to detect recurring topics → generates probability predictions.
// Uses same OPENROUTER_API_KEY as other prep functions.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

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

async function callLLM(systemPrompt: string, userPrompt: string, maxTokens = 6000): Promise<string> {
  const modelsToTry = [OPENROUTER_MODEL, OPENROUTER_FALLBACK_MODEL].filter(m => m);
  const errors: string[] = [];
  
  for (const model of modelsToTry) {
    const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.3,
        max_tokens: maxTokens,
      }),
    });
    if (!resp.ok) {
      const text = await resp.text();
      errors.push(`${model} (${resp.status}): ${text.slice(0, 100)}`);
      continue;
    }
    const data = await resp.json();
    const content = (data?.choices?.[0]?.message?.content ?? '').toString().trim();
    if (content) return content;
    errors.push(`${model}: empty content`);
  }
  
  throw new Error(`All models failed: ${errors.join(' | ')}`);
}

function escapeSql(text: string): string {
  return text.replace(/'/g, "''");
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

    // Allow service_role key (for cron jobs / admin calls)
    const isServiceRole = jwt === SUPABASE_SERVICE_ROLE_KEY;
    if (!isServiceRole) {
      const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
        global: { headers: { Authorization: `Bearer ${jwt}` } },
      });
      const { data: userData, error: userError } = await supabaseUser.auth.getUser(jwt);
      if (userError || !userData?.user) {
        return jsonResponse({ error: 'not_authenticated' }, 401);
      }
    }

    const body = await req.json();
    const concoursType = (body.concours_type ?? '').toString().trim() || null;
    const targetYear = (body.target_year ?? new Date().getFullYear() + 1).toString();

    // ── 1. Gather all indexed chunks grouped by year + concours ───
    const { data: chunksData } = await supabase.rpc('admin_execute_sql', {
      p_sql: `SELECT c.content, c.concours_type, c.subject_name, c.year, c.chunk_type, c.question_number FROM app.prep_doc_chunks c JOIN app.prep_source_documents d ON d.id = c.source_document_id WHERE d.status IN ('indexed','validated','published') ${concoursType ? `AND c.concours_type = '${escapeSql(concoursType)}'` : ''} ORDER BY c.year DESC, c.chunk_index LIMIT 200`,
    });

    let chunks: Array<Record<string, unknown>> = [];
    const cd = chunksData as Record<string, unknown> | null;
    if (cd?.ok && Array.isArray(cd.rows)) {
      chunks = cd.rows as Array<Record<string, unknown>>;
    }

    // ── 2. Also gather existing questions (manually added + AI generated) ──
    const { data: questionsData } = await supabase.rpc('admin_execute_sql', {
      p_sql: `SELECT q.question, q.subject, q.concours_type, q.difficulty, q.content FROM app.prep_questions q WHERE q.is_published = true ${concoursType ? `AND q.concours_type = '${escapeSql(concoursType)}'` : ''} ORDER BY q.created_at DESC LIMIT 100`,
    });

    let questions: Array<Record<string, unknown>> = [];
    const qd = questionsData as Record<string, unknown> | null;
    if (qd?.ok && Array.isArray(qd.rows)) {
      questions = qd.rows as Array<Record<string, unknown>>;
    }

    const totalContent = chunks.length + questions.length;
    if (totalContent === 0) {
      return jsonResponse({
        success: true,
        message: 'No content to analyze yet. Upload and index documents first.',
        topics_created: 0,
        predictions_created: 0,
      });
    }

    // ── 3. Build analysis prompt ──────────────────────────────────
    const systemPrompt = `Tu es un analyste expert en concours de la fonction publique du Burkina Faso.
Tu analyses les sujets d'examen des années précédentes pour identifier les thèmes récurrents et prédire les sujets probables pour les prochaines sessions.

RÈGLES :
1. Identifie les thèmes principaux qui apparaissent dans les sujets
2. Pour chaque thème, évalue la fréquence d'apparition
3. Détecte les cycles (certains sujets reviennent tous les 2-3 ans)
4. Prends en compte l'actualité du Burkina Faso
5. Attribue un score de probabilité (0-100)
6. Fournis un raisonnement court pour chaque prédiction
7. Réponds UNIQUEMENT en JSON valide

FORMAT JSON REQUIS :
{"topics":[{"name":"Nom du thème","category":"droit|economie|culture_gen|actualites|finances|fiscalite|admin|autre","description":"Description courte","predictions":[{"concours_type":"ENAREF|ADMIN_CIVIL|DOUANE|GREFFIERS|TOUS","probability_score":85,"frequency_count":4,"last_appeared_year":"2024","cycle_years":2.0,"reasoning":"Explication courte"}]}]}`;

    let userPrompt = `Analyse les contenus suivants issus de vrais sujets de concours du Burkina Faso et identifie les thèmes récurrents avec leurs probabilités pour ${targetYear}.\n\n`;

    // Add chunks context
    if (chunks.length > 0) {
      userPrompt += `=== EXTRAITS DE SUJETS INDEXÉS (${chunks.length} chunks) ===\n\n`;
      const yearGroups: Record<string, string[]> = {};
      for (const c of chunks.slice(0, 100)) {
        const key = `${c.concours_type || 'TOUS'} ${c.year || '?'}`;
        if (!yearGroups[key]) yearGroups[key] = [];
        yearGroups[key].push((c.content as string || '').slice(0, 300));
      }
      for (const [key, texts] of Object.entries(yearGroups)) {
        userPrompt += `--- ${key} (${texts.length} extraits) ---\n`;
        for (const t of texts.slice(0, 5)) {
          userPrompt += `${t}\n`;
        }
        userPrompt += '\n';
      }
    }

    // Add questions context
    if (questions.length > 0) {
      userPrompt += `\n=== QUESTIONS EXISTANTES (${questions.length}) ===\n\n`;
      const subjGroups: Record<string, string[]> = {};
      for (const q of questions.slice(0, 50)) {
        const key = `${q.subject || 'Autre'}/${q.concours_type || 'TOUS'}`;
        if (!subjGroups[key]) subjGroups[key] = [];
        subjGroups[key].push((q.question as string || q.content as string || '').slice(0, 200));
      }
      for (const [key, texts] of Object.entries(subjGroups)) {
        userPrompt += `--- ${key} (${texts.length} questions) ---\n`;
        for (const t of texts.slice(0, 3)) {
          userPrompt += `• ${t}\n`;
        }
        userPrompt += '\n';
      }
    }

    userPrompt += `\nGénère les prédictions pour ${targetYear}. Identifie au moins 10 thèmes principaux avec leurs scores de probabilité.`;

    // ── 4. Call LLM ───────────────────────────────────────────────
    const rawResponse = await callLLM(systemPrompt, userPrompt);

    // Parse JSON
    let jsonStr = rawResponse;
    const jsonMatch = rawResponse.match(/\{[\s\S]*"topics"[\s\S]*\}/);
    if (jsonMatch) jsonStr = jsonMatch[0];

    type PredictionEntry = {
      concours_type: string;
      probability_score: number;
      frequency_count: number;
      last_appeared_year: string;
      cycle_years: number;
      reasoning: string;
    };

    type TopicEntry = {
      name: string;
      category: string;
      description: string;
      predictions: PredictionEntry[];
    };

    let parsed: { topics: TopicEntry[] };
    try {
      parsed = JSON.parse(jsonStr);
    } catch {
      return jsonResponse({ error: 'invalid_json', raw: rawResponse.slice(0, 1000) }, 500);
    }

    if (!parsed.topics || !Array.isArray(parsed.topics)) {
      return jsonResponse({ error: 'no_topics', raw: rawResponse.slice(0, 500) }, 500);
    }

    // ── 5. Upsert topics + predictions into DB ────────────────────
    let topicsCreated = 0;
    let predictionsCreated = 0;

    for (const topic of parsed.topics) {
      const topicName = (topic.name ?? '').toString().trim();
      if (!topicName) continue;

      const category = (topic.category ?? 'autre').toString().trim();
      const description = (topic.description ?? '').toString().trim();

      // Upsert topic
      const { data: topicResult } = await supabase.rpc('admin_execute_sql', {
        p_sql: `INSERT INTO app.prep_topics (name, category, description) VALUES ('${escapeSql(topicName)}', '${escapeSql(category)}', '${escapeSql(description)}') ON CONFLICT (name) DO UPDATE SET category = '${escapeSql(category)}', description = '${escapeSql(description)}' RETURNING id`,
      });

      const tr = topicResult as Record<string, unknown> | null;
      let topicId: string | null = null;
      if (tr?.ok && Array.isArray(tr.rows) && tr.rows.length > 0) {
        topicId = ((tr.rows[0] as Record<string, unknown>).id as string) ?? null;
        topicsCreated++;
      }

      if (!topicId) continue;

      // Insert predictions for this topic
      const predictions = Array.isArray(topic.predictions) ? topic.predictions : [];
      for (const pred of predictions) {
        const ct = (pred.concours_type ?? 'TOUS').toString().trim();
        const score = typeof pred.probability_score === 'number' ? Math.min(100, Math.max(0, pred.probability_score)) : 50;
        const freq = typeof pred.frequency_count === 'number' ? pred.frequency_count : 0;
        const lastYear = (pred.last_appeared_year ?? '').toString().trim();
        const cycle = typeof pred.cycle_years === 'number' ? pred.cycle_years : 0;
        const reasoning = (pred.reasoning ?? '').toString().trim();

        const predSql = `INSERT INTO app.prep_topic_predictions (topic_id, concours_type, target_year, probability_score, frequency_count, last_appeared_year, cycle_years, reasoning) VALUES ('${topicId}', '${escapeSql(ct)}', '${escapeSql(targetYear)}', ${score}, ${freq}, '${escapeSql(lastYear)}', ${cycle}, '${escapeSql(reasoning)}') ON CONFLICT (topic_id, concours_type, target_year) DO UPDATE SET probability_score = ${score}, frequency_count = ${freq}, last_appeared_year = '${escapeSql(lastYear)}', cycle_years = ${cycle}, reasoning = '${escapeSql(reasoning)}', updated_at = now()`;

        const { data: predResult } = await supabase.rpc('admin_execute_sql', { p_sql: predSql });
        const pr = predResult as Record<string, unknown> | null;
        if (pr?.ok) predictionsCreated++;
      }
    }

    return jsonResponse({
      success: true,
      target_year: targetYear,
      concours_type: concoursType,
      content_analyzed: { chunks: chunks.length, questions: questions.length },
      topics_created: topicsCreated,
      predictions_created: predictionsCreated,
    });
  } catch (err: any) {
    console.error('prep-analyze-trends error:', err);
    return jsonResponse(
      { error: 'internal_error', message: err?.message?.slice(0, 500) ?? 'unknown' },
      500,
    );
  }
});
