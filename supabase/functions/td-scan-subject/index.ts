// Supabase Edge Function: td-scan-subject
// Pipeline: Image → OCR via Vision AI (Gemini) → Extract TD exercises → Generate answers
// Used by students to scan TD exercises and get AI-powered solutions

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const ACTION_CODE = 'scan_correction';
const EDGE_FN = 'td-scan-subject';

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
              image_url: { url: `data:${mimeType};base64,${imageBase64}` },
            },
            {
              type: 'text',
              text: `Tu es un expert OCR spécialisé dans les documents académiques (exercices, TD, examens).

INSTRUCTIONS :
1. Extrais TOUT le texte visible sur cette image d'exercice/TD.
2. Conserve la numérotation des exercices et questions.
3. Conserve les formules mathématiques, schémas décrits, et tableaux.
4. Si le texte est à l'envers ou mal orienté, corrige l'orientation.
5. Si certaines parties sont floues, indique [illisible].
6. Retourne UNIQUEMENT le texte extrait, sans commentaire.`,
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

async function generateSolutions(
  extractedText: string,
  fieldName?: string,
  level?: string,
): Promise<string> {
  const contextParts: string[] = [];
  if (fieldName) contextParts.push(`Matière/Filière : ${fieldName}`);
  if (level) contextParts.push(`Niveau : ${level}`);
  const contextInfo = contextParts.length > 0 ? contextParts.join('. ') + '.' : '';

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
          content: `Tu es un professeur expert qui résout des exercices de TD (travaux dirigés) universitaires et de lycée. ${contextInfo}

RÈGLES :
1. Résous CHAQUE exercice/question du TD, dans l'ordre.
2. Détaille chaque étape du raisonnement.
3. Pour les maths/physique : montre les calculs étape par étape.
4. Pour les sciences : explique les concepts et lois utilisés.
5. Pour le droit/économie : cite les articles et principes pertinents.
6. Fournis la réponse finale clairement identifiée.
7. Si un exercice est incomplet ou illisible, indique-le.
8. Utilise le format markdown pour la lisibilité (titres, gras, listes).`,
        },
        {
          role: 'user',
          content: `Voici un exercice/TD extrait d'une photo. Résous-le en détaillant chaque étape :\n\n${extractedText}`,
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
    const fieldName: string | undefined = body.field_name?.toString() || undefined;
    const level: string | undefined = body.level?.toString() || undefined;
    const mode: string = (body.mode ?? 'full').toString();

    if (!imageBase64) {
      return jsonResponse({ error: 'image_base64 required' }, 400);
    }

    if (imageBase64.length > 14_000_000) {
      return jsonResponse({ error: 'image_too_large', max_size: '10MB' }, 400);
    }

    // Reserve credits
    const { data: resData } = await supabaseService.rpc('app_student_reserve_credits', {
      p_action_code: ACTION_CODE, p_edge_function: EDGE_FN, p_student_id: userId,
    });
    const res = resData as Record<string, unknown> | null;
    if (!res?.success) {
      return jsonResponse({ error: 'insufficient_credits', balance: res?.balance ?? 0, cost: res?.cost ?? 0,
        message: `Crédits insuffisants. Il vous faut ${res?.cost??0} crédits (solde: ${res?.balance??0}).` }, 402);
    }
    const reservationId = (res.reservation_id as string) || '';

    // Step 1: OCR
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
        message: 'Impossible de lire le texte. Essayez avec une photo plus nette.',
      }, 400);
    }

    if (mode === 'ocr_only') {
      return jsonResponse({
        success: true,
        mode: 'ocr_only',
        extracted_text: extractedText,
        text_length: extractedText.length,
      });
    }

    // Step 2: Generate solutions
    let solutions: string;
    try {
      solutions = await generateSolutions(extractedText, fieldName, level);
    } catch (genErr) {
      await supabaseService.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      return jsonResponse({ error: 'solution_generation_failed', detail: (genErr as Error).message?.slice(0, 300) }, 502);
    }

    // Confirm credits
    await supabaseService.rpc('app_student_confirm_credits', {
      p_reservation_id: reservationId, p_openrouter_cost_usd: 0,
      p_openrouter_model: 'google/gemini-2.5-flash', p_tokens_input: 0, p_tokens_output: 0,
    });

    // Step 3: Log
    try {
      await supabaseService.rpc('execute_ddl', {
        ddl_query: `INSERT INTO app.td_scan_logs (student_id, extracted_text, solutions, field_name, level, created_at)
                VALUES ('${userData.user.id}', $txt$${extractedText.slice(0, 10000)}$txt$, $txt$${(solutions || '').slice(0, 20000)}$txt$, ${fieldName ? `'${fieldName}'` : 'NULL'}, ${level ? `'${level}'` : 'NULL'}, now())`,
      });
    } catch (logErr) {
      console.error('TD scan log failed:', logErr);
    }

    return jsonResponse({
      success: true,
      extracted_text: extractedText,
      solutions: solutions,
      text_length: extractedText.length,
      solutions_length: solutions?.length ?? 0,
      credits_used: res.cost,
    });
  } catch (err: any) {
    console.error('td-scan-subject error:', err);
    return jsonResponse(
      { error: 'internal_error', message: err?.message?.slice(0, 500) ?? 'unknown' },
      500,
    );
  }
});
