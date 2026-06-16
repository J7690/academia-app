// Supabase Edge Function: prep-scan-subject
// Pipeline: Image → OCR via Vision AI (Gemini) → Extract questions → Generate answers
// Used by students to scan exam papers and get AI-powered answers

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const ACTION_CODE = 'scan_correction';
const EDGE_FN = 'prep-scan-subject';

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

// ─── Step 1: OCR — Extract text from image using Vision AI ──────────
async function extractTextFromImage(imageBase64: string, mimeType: string): Promise<string> {
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
        {
          role: 'user',
          content: [
            {
              type: 'image_url',
              image_url: {
                url: `data:${mimeType};base64,${imageBase64}`,
              },
            },
            {
              type: 'text',
              text: `Tu es un expert OCR spécialisé dans les documents d'examen et de concours d'Afrique francophone.

INSTRUCTIONS :
1. Extrais TOUT le texte visible sur cette image de sujet d'examen/concours.
2. Conserve la numérotation des questions (1, 2, 3... ou Q1, Q2...).
3. Conserve les options de réponse (A, B, C, D) si c'est un QCM.
4. Conserve les titres, sections, et consignes.
5. Si le texte est à l'envers ou mal orienté, corrige l'orientation.
6. Si certaines parties sont floues, indique [illisible].
7. Retourne UNIQUEMENT le texte extrait, sans commentaire ni formatage markdown.`,
            },
          ],
        },
      ],
      temperature: 0,
      max_tokens: 8000,
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    errors.push(`${model} (${resp.status}): ${errText.slice(0, 100)}`);
    continue;
  }

  const data = await resp.json();
  const text = data?.choices?.[0]?.message?.content?.trim() ?? '';
  if (text) return text;
  errors.push(`${model}: empty content`);
  }

  throw new Error(`All models failed: ${errors.join(' | ')}`);
}

// ─── Step 2: Generate answers for extracted questions ────────────────
async function generateAnswers(
  extractedText: string,
  concoursType?: string,
): Promise<string> {
  const contextInfo = concoursType
    ? `Ce sujet provient d'un concours de type "${concoursType}" au Burkina Faso.`
    : `Ce sujet provient d'un concours/examen d'Afrique francophone.`;

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
        {
          role: 'system',
          content: `Tu es un professeur expert qui corrige des sujets de concours de la fonction publique du Burkina Faso et d'Afrique francophone. ${contextInfo}

RÈGLES :
1. Réponds à CHAQUE question du sujet, dans l'ordre.
2. Pour les QCM : indique la bonne réponse (A, B, C ou D) puis explique pourquoi.
3. Pour les questions ouvertes : donne une réponse structurée et complète.
4. Fournis des explications pédagogiques claires et détaillées.
5. Cite les références légales, dates, ou formules pertinentes.
6. Adapte ton niveau au type de concours.
7. Structure ta réponse avec des numéros correspondant aux questions.
8. Utilise le format markdown pour la lisibilité.`,
        },
        {
          role: 'user',
          content: `Voici le sujet extrait d'une photo. Corrige-le en donnant les réponses détaillées à chaque question :\n\n${extractedText}`,
        },
      ],
      temperature: 0.3,
      max_tokens: 12000,
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    errors.push(`${model} (${resp.status}): ${errText.slice(0, 100)}`);
    continue;
  }

  const data = await resp.json();
  const content = data?.choices?.[0]?.message?.content?.trim() ?? '';
  if (content) return content;
  errors.push(`${model}: empty content`);
  }

  throw new Error(`All models failed: ${errors.join(' | ')}`);
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
    // Auth check
    const authHeader = req.headers.get('authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();

    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    const { data: userData, error: userError } = await supabaseUser.auth.getUser(jwt);
    if (userError || !userData?.user) {
      return jsonResponse({ error: 'not_authenticated' }, 401);
    }
    const userId = userData.user.id;

    const supabaseService = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    const body = await req.json();
    const imageBase64: string = (body.image_base64 ?? '').toString();
    const mimeType: string = (body.mime_type ?? 'image/jpeg').toString();
    const concoursType: string | undefined = body.concours_type?.toString() || undefined;
    const mode: string = (body.mode ?? 'full').toString(); // 'ocr_only' or 'full'

    if (!imageBase64) {
      return jsonResponse({ error: 'image_base64 required' }, 400);
    }

    // Limit image size (max ~10MB base64)
    if (imageBase64.length > 14_000_000) {
      return jsonResponse({ error: 'image_too_large', max_size: '10MB' }, 400);
    }

    // ── Reserve credits ───────────────────────────────────────────
    const { data: resData } = await supabaseService.rpc('app_student_reserve_credits', {
      p_action_code: ACTION_CODE, p_edge_function: EDGE_FN, p_student_id: userId,
    });
    const res = resData as Record<string, unknown> | null;
    if (!res?.success) {
      return jsonResponse({ error: 'insufficient_credits', balance: res?.balance ?? 0, cost: res?.cost ?? 0,
        message: `Crédits insuffisants. Il vous faut ${res?.cost??0} crédits (solde: ${res?.balance??0}).` }, 402);
    }
    const reservationId = (res.reservation_id as string) || '';

    // ── Step 1: OCR ─────────────────────────────────────────────
    let extractedText: string;
    try {
      extractedText = await extractTextFromImage(imageBase64, mimeType);
    } catch (ocrErr) {
      await supabaseService.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      return jsonResponse({ error: 'ocr_failed', detail: (ocrErr as Error).message?.slice(0, 300) }, 502);
    }

    if (!extractedText || extractedText.length < 20) {
      await supabaseService.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      return jsonResponse({
        success: false,
        error: 'extraction_empty',
        message: 'Impossible de lire le texte sur cette image. Essayez avec une photo plus nette.',
      }, 400);
    }

    // If OCR only mode, return extracted text
    if (mode === 'ocr_only') {
      return jsonResponse({
        success: true,
        mode: 'ocr_only',
        extracted_text: extractedText,
        text_length: extractedText.length,
      });
    }

    // ── Step 2: Generate answers ────────────────────────────────
    let answers: string;
    try {
      answers = await generateAnswers(extractedText, concoursType);
    } catch (genErr) {
      await supabaseService.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      return jsonResponse({ error: 'answer_generation_failed', detail: (genErr as Error).message?.slice(0, 300) }, 502);
    }

    if (!answers || answers.length < 20) {
      return jsonResponse({
        success: true,
        extracted_text: extractedText,
        answers: null,
        error_detail: 'answer_generation_failed',
      });
    }

    // ── Confirm credits ───────────────────────────────────────────
    await supabaseService.rpc('app_student_confirm_credits', {
      p_reservation_id: reservationId, p_openrouter_cost_usd: 0, // Vision cost tracked separately
      p_openrouter_model: 'google/gemini-2.5-flash', p_tokens_input: 0, p_tokens_output: 0,
    });

    // ── Step 3: Log the scan (optional, for analytics) ────────────
    try {
      await supabaseService.rpc('admin_execute_sql', {
        p_sql: `INSERT INTO app.prep_scan_logs (student_id, extracted_text, answers, concours_type, created_at)
                VALUES ('${userData.user.id}', ${escapeSql(extractedText.slice(0, 10000))}, ${escapeSql(answers.slice(0, 20000))}, ${concoursType ? `'${concoursType}'` : 'NULL'}, now())`.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim(),
      });
    } catch (logErr) {
      // Non-critical: don't fail if logging fails
      console.error('Scan log failed:', logErr);
    }

    return jsonResponse({
      success: true,
      extracted_text: extractedText,
      answers: answers,
      text_length: extractedText.length,
      answers_length: answers.length,
      credits_used: res.cost,
    });
  } catch (err: any) {
    console.error('prep-scan-subject error:', err);
    return jsonResponse(
      { error: 'internal_error', message: err?.message?.slice(0, 500) ?? 'unknown' },
      500,
    );
  }
});

function escapeSql(text: string): string {
  return `$txt$${text.replace(/\$txt\$/g, '$$txt$$')}$txt$`;
}
