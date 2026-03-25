// Supabase Edge Function: prep-grade-assignment
// AI-assisted grading: analyzes student submission against assignment content + RAG context.
// Used by teachers to get AI correction suggestions before final grading.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? 'google/gemini-2.0-flash-001';
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

function escapeSql(text: string): string {
  return text.replace(/'/g, "''");
}

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
    const submissionId = (body.submission_id ?? '').toString().trim();
    if (!submissionId) {
      return jsonResponse({ error: 'submission_id required' }, 400);
    }

    // 1. Get submission + assignment details
    const { data: subData } = await supabase.rpc('admin_execute_sql', {
      p_sql: `SELECT s.*, a.title AS assignment_title, a.description AS assignment_description, a.content AS assignment_content, a.max_score, a.concours_type, a.subject_name, a.assignment_type FROM app.prep_assignment_submissions s JOIN app.prep_assignments a ON a.id = s.assignment_id WHERE s.id = '${escapeSql(submissionId)}' LIMIT 1`,
    });

    const sd = subData as Record<string, unknown> | null;
    if (!sd?.ok || !Array.isArray(sd.rows) || sd.rows.length === 0) {
      return jsonResponse({ error: 'submission_not_found' }, 404);
    }

    const submission = sd.rows[0] as Record<string, unknown>;
    const studentAnswer = JSON.stringify(submission.answer_content ?? '');
    const assignmentContent = JSON.stringify(submission.assignment_content ?? '');
    const assignmentTitle = (submission.assignment_title ?? '').toString();
    const assignmentDesc = (submission.assignment_description ?? '').toString();
    const maxScore = (submission.max_score as number) ?? 20;
    const concoursType = (submission.concours_type ?? '').toString();
    const subjectName = (submission.subject_name ?? '').toString();

    // 2. Build correction prompt
    const systemPrompt = `Tu es un correcteur expert pour les concours de la fonction publique du Burkina Faso.
Tu dois corriger la copie d'un étudiant de manière détaillée et bienveillante.

RÈGLES :
1. Attribue une note sur ${maxScore}
2. Pour chaque question/réponse, indique si c'est correct ou incorrect
3. Fournis l'explication correcte pour chaque erreur
4. Donne des conseils d'amélioration
5. Sois encourageant même si la note est basse
6. Réponds en JSON valide

FORMAT JSON :
{"score":15,"max_score":${maxScore},"correction":"Correction détaillée...","explanation":"Explication générale...","strengths":["Point fort 1","Point fort 2"],"weaknesses":["Point faible 1"],"advice":"Conseil pour s'améliorer"}`;

    const userPrompt = `EXERCICE : ${assignmentTitle}
${assignmentDesc ? `Description : ${assignmentDesc}` : ''}
${concoursType ? `Concours : ${concoursType}` : ''}
${subjectName ? `Matière : ${subjectName}` : ''}

CONTENU DE L'EXERCICE :
${assignmentContent}

RÉPONSE DE L'ÉTUDIANT :
${studentAnswer}

Corrige cette copie. Attribue une note sur ${maxScore} et fournis une correction détaillée.`;

    // 3. Call LLM
    const llmResp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
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
        temperature: 0.3,
        max_tokens: 4000,
      }),
    });

    if (!llmResp.ok) {
      const errText = await llmResp.text();
      return jsonResponse({ error: 'llm_error', detail: errText.slice(0, 500) }, 502);
    }

    const llmData = await llmResp.json();
    const rawReply = llmData?.choices?.[0]?.message?.content?.trim() ?? '';

    // 4. Parse JSON
    let grading: Record<string, unknown>;
    try {
      const jsonMatch = rawReply.match(/\{[\s\S]*"score"[\s\S]*\}/);
      grading = JSON.parse(jsonMatch ? jsonMatch[0] : rawReply);
    } catch {
      grading = { score: null, correction: rawReply, explanation: '' };
    }

    const aiScore = typeof grading.score === 'number' ? Math.min(maxScore, Math.max(0, grading.score as number)) : null;
    const aiCorrection = (grading.correction ?? rawReply).toString();
    const aiExplanation = (grading.explanation ?? '').toString();

    // 5. Update submission with AI grading
    const updateSql = `UPDATE app.prep_assignment_submissions SET ai_score = ${aiScore ?? 'NULL'}, ai_correction = '${escapeSql(aiCorrection.slice(0, 10000))}', ai_explanation = '${escapeSql(aiExplanation.slice(0, 5000))}' WHERE id = '${escapeSql(submissionId)}'`;
    await supabase.rpc('admin_execute_sql', { p_sql: updateSql });

    return jsonResponse({
      success: true,
      submission_id: submissionId,
      ai_score: aiScore,
      max_score: maxScore,
      correction: aiCorrection,
      explanation: aiExplanation,
      strengths: grading.strengths ?? [],
      weaknesses: grading.weaknesses ?? [],
      advice: grading.advice ?? '',
    });
  } catch (err: any) {
    console.error('prep-grade-assignment error:', err);
    return jsonResponse({ error: 'internal_error', message: err?.message?.slice(0, 500) ?? 'unknown' }, 500);
  }
});
