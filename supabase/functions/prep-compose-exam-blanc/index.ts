// Supabase Edge Function: prep-compose-exam-blanc
// Generates a complete multi-subject mock exam ("sujet blanc") using LLM + RAG context.
// The exam is stored as a self-contained JSON in prep_exam_blancs.
// Can be called by admin or by the cron to pre-generate exams.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';
const OPENROUTER_CHAT_MODEL = Deno.env.get('OPENROUTER_CHAT_MODEL') ?? '';

const ACTION_CODE = 'compose_exam';
const EDGE_FN = 'prep-compose-exam-blanc';
const TEXT_CASCADE = [
  { model: OPENROUTER_CHAT_MODEL || OPENROUTER_MODEL, tier: 'primary' },
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
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept,x-client-info',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

// ─── Question types ───────────────────────────────────────────────────
// "qcm" = multiple choice (4 options, auto-corrected)
// "open" = open-ended written answer (student types answer, AI-corrected later)
type QuestionType = 'qcm' | 'open';

interface SectionTemplate {
  subject: string;
  qcm: number;   // number of QCM questions
  open: number;   // number of open-ended questions
}

// ─── Exam templates per concours type ──────────────────────────────────
// Based on real BF concours format: 50-70 questions, 45-60 min
// Generic sections shared by ALL concours
const GENERIC_SECTIONS: SectionTemplate[] = [
  { subject: 'Culture Générale', qcm: 15, open: 2 },
  { subject: 'Actualités du Burkina Faso', qcm: 10, open: 1 },
  { subject: 'Français', qcm: 8, open: 2 },
];

// Specific sections per concours type
const SPECIFIC_SECTIONS: Record<string, SectionTemplate[]> = {
  TOUS: [
    { subject: 'Mathématiques', qcm: 5, open: 1 },
    { subject: 'Histoire-Géographie', qcm: 5, open: 1 },
    { subject: 'Informatique', qcm: 5, open: 0 },
  ],
  ENAREF: [
    { subject: 'Fiscalité', qcm: 8, open: 2 },
    { subject: 'Finances Publiques', qcm: 6, open: 1 },
    { subject: 'Comptabilité', qcm: 5, open: 1 },
    { subject: 'Économie Générale', qcm: 4, open: 1 },
  ],
  ADMIN_CIVIL: [
    { subject: 'Droit Constitutionnel', qcm: 8, open: 2 },
    { subject: 'Droit Administratif', qcm: 7, open: 2 },
    { subject: 'Institutions Politiques', qcm: 5, open: 1 },
  ],
  GREFFIERS: [
    { subject: 'Droit Civil', qcm: 8, open: 2 },
    { subject: 'Droit Pénal', qcm: 7, open: 2 },
    { subject: 'Procédure Civile', qcm: 5, open: 1 },
  ],
  GRH: [
    { subject: 'Droit du Travail', qcm: 8, open: 2 },
    { subject: 'GRH et Management', qcm: 7, open: 2 },
  ],
  DOUANE: [
    { subject: 'Fiscalité Douanière', qcm: 10, open: 2 },
    { subject: 'Économie Générale', qcm: 5, open: 1 },
  ],
  PARAMILITAIRE: [
    { subject: 'Tests Psychotechniques', qcm: 12, open: 0 },
    { subject: 'Mathématiques', qcm: 8, open: 1 },
  ],
  EDUCATION: [
    { subject: 'Pédagogie', qcm: 8, open: 2 },
    { subject: 'Didactique', qcm: 5, open: 1 },
    { subject: 'Mathématiques', qcm: 5, open: 1 },
  ],
};

function getExamTemplate(concoursType: string): SectionTemplate[] {
  const specific = SPECIFIC_SECTIONS[concoursType] ?? SPECIFIC_SECTIONS['TOUS'] ?? [];
  return [...GENERIC_SECTIONS, ...specific];
}

function computeDuration(template: SectionTemplate[]): number {
  // ~1 min per QCM, ~3 min per open question
  const totalQcm = template.reduce((s, t) => s + t.qcm, 0);
  const totalOpen = template.reduce((s, t) => s + t.open, 0);
  const rawMin = totalQcm * 1 + totalOpen * 3;
  // Round to nearest 5 min, clamp 45-90
  return Math.max(45, Math.min(90, Math.round(rawMin / 5) * 5));
}

// ─── LLM call (now uses cascade) ────────────────────────────────────────
async function callLLM(systemPrompt: string, userPrompt: string): Promise<string> {
  const result = await callWithCascade([{role:'system',content:systemPrompt},{role:'user',content:userPrompt}], 4096);
  return result.content;
}

// ─── Fetch RAG context for a subject ───────────────────────────────────
async function getSubjectContext(
  supabase: ReturnType<typeof createClient>,
  subjectName: string,
): Promise<string> {
  try {
    const { data } = await supabase.rpc('app_prep_get_rag_chunks_by_name', {
      p_subject_name: subjectName,
      p_concours_type: null,
      p_limit: 5,
      p_max_chars: 3000,
    });

    const fb = data as Record<string, unknown> | null;
    if (fb?.success && Array.isArray(fb.chunks) && (fb.chunks as any[]).length > 0) {
      const chunks = fb.chunks as Array<Record<string, unknown>>;
      let ctx = '';
      for (const c of chunks) {
        ctx += `${(c.content as string || '').slice(0, 500)}\n\n`;
      }
      return ctx;
    }
  } catch { /* ignore */ }
  return '';
}

// ─── Generate QCM questions for one section ───────────────────────────
async function generateQcmQuestions(
  supabase: ReturnType<typeof createClient>,
  subjectName: string,
  count: number,
  concoursType: string,
): Promise<any[]> {
  if (count <= 0) return [];
  const context = await getSubjectContext(supabase, subjectName);

  const systemPrompt = `Tu es un expert en création de QCM pour les concours de la fonction publique du Burkina Faso.
Tu dois générer des questions de qualité professionnelle, réalistes.

RÈGLES STRICTES :
1. Chaque question a exactement 4 options (A, B, C, D)
2. Une seule réponse correcte par question
3. Les distracteurs doivent être plausibles
4. Inclure une explication courte pour la bonne réponse
5. Répondre UNIQUEMENT en JSON valide, sans texte avant/après

Format JSON attendu :
{
  "questions": [
    {
      "question": "...",
      "explanation": "...",
      "choices": [
        {"label": "A", "text": "...", "is_correct": false},
        {"label": "B", "text": "...", "is_correct": true},
        {"label": "C", "text": "...", "is_correct": false},
        {"label": "D", "text": "...", "is_correct": false}
      ]
    }
  ]
}`;

  let userPrompt = `Génère ${count} questions QCM pour la matière "${subjectName}" dans le cadre d'un concours ${concoursType || 'de la fonction publique'} au Burkina Faso.
Les questions doivent être variées, couvrir différents aspects de la matière, et être de difficulté appropriée pour un concours.`;

  if (context) {
    userPrompt += `\n\nVoici des informations complémentaires pour t'inspirer :\n\n${context}`;
  }

  const raw = await callLLM(systemPrompt, userPrompt);

  try {
    const jsonMatch = raw.match(/\{[\s\S]*"questions"[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      if (Array.isArray(parsed.questions)) {
        return parsed.questions.slice(0, count).map((q: any) => ({
          question_type: 'qcm',
          question: q.question || '',
          explanation: q.explanation || '',
          choices: Array.isArray(q.choices)
            ? q.choices.slice(0, 4).map((c: any) => ({
                label: c.label || '',
                text: c.text || '',
                is_correct: !!c.is_correct,
              }))
            : [],
        }));
      }
    }
  } catch (e) {
    console.error(`JSON parse error for ${subjectName} QCM:`, e);
  }
  return [];
}

// ─── Generate open-ended (written) questions for one section ──────────
async function generateOpenQuestions(
  supabase: ReturnType<typeof createClient>,
  subjectName: string,
  count: number,
  concoursType: string,
): Promise<any[]> {
  if (count <= 0) return [];
  const context = await getSubjectContext(supabase, subjectName);

  const systemPrompt = `Tu es un expert en composition de sujets de concours pour la fonction publique du Burkina Faso.
Tu dois générer des questions rédactionnelles (réponse écrite) comme dans un vrai examen.

RÈGLES STRICTES :
1. Les questions doivent nécessiter une réponse rédigée (1 à 5 phrases)
2. Inclure un "corrigé type" (réponse attendue) pour chaque question
3. Varier les types : définition, explication, comparaison, cas pratique
4. Répondre UNIQUEMENT en JSON valide, sans texte avant/après

Format JSON attendu :
{
  "questions": [
    {
      "question": "Définissez le principe de légalité en droit administratif burkinabè.",
      "expected_answer": "Le principe de légalité signifie que l'administration est soumise au respect de la loi...",
      "points": 2
    }
  ]
}`;

  let userPrompt = `Génère ${count} questions rédactionnelles pour la matière "${subjectName}" dans le cadre d'un concours ${concoursType || 'de la fonction publique'} au Burkina Faso.
Les questions doivent être réalistes, comme dans un vrai sujet d'examen écrit.`;

  if (context) {
    userPrompt += `\n\nVoici des informations complémentaires pour t'inspirer :\n\n${context}`;
  }

  const raw = await callLLM(systemPrompt, userPrompt);

  try {
    const jsonMatch = raw.match(/\{[\s\S]*"questions"[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      if (Array.isArray(parsed.questions)) {
        return parsed.questions.slice(0, count).map((q: any) => ({
          question_type: 'open',
          question: q.question || '',
          expected_answer: q.expected_answer || q.corrige || '',
          points: q.points || 2,
          choices: [],
        }));
      }
    }
  } catch (e) {
    console.error(`JSON parse error for ${subjectName} open:`, e);
  }
  return [];
}

// ─── Main handler ──────────────────────────────────────────────────────
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !OPENROUTER_API_KEY) {
      return jsonResponse({ error: 'Configuration manquante' }, 500);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // Auth check — determine if admin or student
    const authHeader = req.headers.get('authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
    let userId = '';
    let isAdmin = false;
    if (jwt) {
      const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
        global: { headers: { Authorization: `Bearer ${jwt}` } },
      });
      const { data: ud } = await supabaseUser.auth.getUser(jwt);
      if (ud?.user) {
        userId = ud.user.id;
        isAdmin = ud.user.user_metadata?.role === 'admin';
      }
    }

    const body = await req.json().catch(() => ({}));
    const concoursType: string = (body.concours_type ?? 'TOUS').toString().trim().toUpperCase();
    const customTitle: string = (body.title ?? '').toString().trim();

    // Get exam template
    const template = getExamTemplate(concoursType);
    const totalExpected = template.reduce((sum, s) => sum + s.qcm + s.open, 0);
    const durationMin = computeDuration(template);

    // Determine title
    const concoursLabel: Record<string, string> = {
      TOUS: 'Concours Général',
      ENAREF: 'ENAREF',
      ADMIN_CIVIL: 'Administrateur Civil',
      GREFFIERS: 'Greffiers',
      GRH: 'GRH',
      DOUANE: 'Douane',
      PARAMILITAIRE: 'Paramilitaire',
      EDUCATION: 'Éducation',
      SANTE: 'Santé',
    };
    const label = concoursLabel[concoursType] || concoursType;
    const title = customTitle || `Sujet blanc — ${label}`;

    // Reserve credits (students only, admin skips)
    let reservationId = '';
    let creditCost = 0;
    if (userId && !isAdmin) {
      const { data: resData } = await supabase.rpc('app_student_reserve_credits', {
        p_action_code: ACTION_CODE, p_edge_function: EDGE_FN, p_student_id: userId,
      });
      const res = resData as Record<string, unknown> | null;
      if (!res?.success) {
        return jsonResponse({ error: 'insufficient_credits', balance: res?.balance ?? 0, cost: res?.cost ?? 0,
          message: `Crédits insuffisants. Il vous faut ${res?.cost??0} crédits (solde: ${res?.balance??0}).` }, 402);
      }
      reservationId = (res.reservation_id as string) || '';
      creditCost = (res.cost as number) || 0;
    }

    // Create exam record (status: generating)
    const { data: uuidData } = await supabase.rpc('admin_execute_sql', {
      p_sql: `SELECT gen_random_uuid() AS id`,
    });
    const examId = (uuidData as any)?.rows?.[0]?.id;
    if (!examId) {
      return jsonResponse({ error: 'Erreur interne: UUID' }, 500);
    }

    const esc = (s: string) => s.replace(/'/g, "''");

    await supabase.rpc('admin_execute_sql', {
      p_sql: `INSERT INTO app.prep_exam_blancs (id, title, concours_type, total_questions, duration_minutes, generation_status)
              VALUES ('${examId}', '${esc(title)}', '${esc(concoursType)}', ${totalExpected}, ${durationMin}, 'generating')`,
    });

    // Generate each section (QCM + open questions in parallel per section)
    const sections: Array<{
      subject_name: string;
      questions_count: number;
      qcm_count: number;
      open_count: number;
      questions: any[];
    }> = [];

    let successCount = 0;

    for (const section of template) {
      try {
        const totalForSection = section.qcm + section.open;
        console.log(`Generating ${totalForSection} questions (${section.qcm} QCM + ${section.open} open) for ${section.subject}...`);

        // Generate QCM and open questions in parallel
        const [qcmQuestions, openQuestions] = await Promise.all([
          generateQcmQuestions(supabase, section.subject, section.qcm, concoursType),
          generateOpenQuestions(supabase, section.subject, section.open, concoursType),
        ]);

        const allQuestions = [...qcmQuestions, ...openQuestions];

        sections.push({
          subject_name: section.subject,
          questions_count: allQuestions.length,
          qcm_count: qcmQuestions.length,
          open_count: openQuestions.length,
          questions: allQuestions,
        });
        successCount += allQuestions.length;
      } catch (secErr: any) {
        console.error(`Section ${section.subject} failed:`, secErr?.message);
        sections.push({
          subject_name: section.subject,
          questions_count: 0,
          qcm_count: 0,
          open_count: 0,
          questions: [],
        });
      }
    }

    // Update exam with sections
    const sectionsJson = JSON.stringify(sections).replace(/'/g, "''");
    await supabase.rpc('admin_execute_sql', {
      p_sql: `UPDATE app.prep_exam_blancs SET
                sections = '${sectionsJson}'::jsonb,
                total_questions = ${successCount},
                duration_minutes = ${durationMin},
                generation_status = '${successCount > 0 ? 'ready' : 'failed'}',
                is_published = ${successCount > 0 ? 'true' : 'false'},
                updated_at = now()
              WHERE id = '${examId}'`,
    });

    // Confirm or refund credits
    if (reservationId) {
      if (successCount > 0) {
        await supabase.rpc('app_student_confirm_credits', {
          p_reservation_id: reservationId, p_openrouter_cost_usd: 0,
          p_openrouter_model: 'cascade', p_tokens_input: 0, p_tokens_output: 0,
        });
      } else {
        await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      }
    }

    return jsonResponse({
      success: true,
      exam_id: examId,
      title,
      concours_type: concoursType,
      total_questions: successCount,
      duration_minutes: durationMin,
      sections_count: sections.length,
      credits_used: successCount > 0 ? creditCost : 0,
      sections_summary: sections.map(s => ({
        subject: s.subject_name,
        qcm: s.qcm_count,
        open: s.open_count,
        total: s.questions_count,
      })),
    });
  } catch (err: any) {
    console.error('prep-compose-exam-blanc error:', err);
    return jsonResponse(
      { error: 'internal_error', message: err?.message?.slice(0, 500) ?? 'unknown' },
      500,
    );
  }
});
