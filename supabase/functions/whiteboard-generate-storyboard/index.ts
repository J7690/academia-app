// Supabase Edge Function: whiteboard-generate-storyboard
// Smart Whiteboard Content Agent - Generates Storyboard JSON via OpenRouter
// Reuses pattern from prep-generate-questions with Storyboard-specific validation

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const ACTION_CODE = 'generate_storyboard';
const EDGE_FN = 'whiteboard-generate-storyboard';

const TEXT_CASCADE = [
  { model: OPENROUTER_MODEL, tier: 'primary' },
  { model: OPENROUTER_FALLBACK_MODEL, tier: 'fallback' },
].filter(m => m.model);

interface CascadeResult {
  content: string;
  model: string;
  tier: string;
  usage: { prompt_tokens: number; completion_tokens: number; total_tokens: number };
  costUsd: number;
}

async function callWithCascade(
  msgs: Array<{role:string;content:string}>,
  maxTok: number
): Promise<CascadeResult> {
  const errs: string[] = [];
  for (const { model, tier } of TEXT_CASCADE) {
    if (!model) continue;
    try {
      const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method:'POST',
        headers:{
          Authorization:`Bearer ${OPENROUTER_API_KEY}`,
          'Content-Type':'application/json',
          Accept:'application/json'
        },
        body:JSON.stringify({
          model,
          messages:msgs,
          temperature:0.2,
          max_tokens:maxTok
        })
      });
      if (!r.ok) { errs.push(`${model}(${r.status})`); continue; }
      const d = await r.json();
      const c = (d?.choices?.[0]?.message?.content??'').toString().trim();
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

// ─── Validation Function (PHASE_D3A21_GENERATION_CONTRACT_LOCK.md) ───────
function validateStoryboard(json: unknown): { valid: boolean; error?: string } {
  if (!json || typeof json !== 'object') {
    return { valid: false, error: 'Not an object' };
  }
  
  const sb = json as Record<string, unknown>;
  
  // Champs obligatoires
  const required = ['version', 'created_at', 'created_by', 'subject', 'renderer', 'theme', 'narration_mode', 'export_settings', 'scenes'];
  for (const field of required) {
    if (!(field in sb)) {
      return { valid: false, error: `Missing field: ${field}` };
    }
  }
  
  // Version
  if (sb.version !== '1.0') {
    return { valid: false, error: 'Invalid version' };
  }
  
  // Renderer
  if (sb.renderer !== 'scientific' && sb.renderer !== 'notebook') {
    return { valid: false, error: 'Invalid renderer' };
  }
  
  // Theme
  if (sb.theme !== 'scientific' && sb.theme !== 'notebook') {
    return { valid: false, error: 'Invalid theme' };
  }
  
  // Narration mode
  if (sb.narration_mode !== 'none' && sb.narration_mode !== 'tts' && sb.narration_mode !== 'userRecording') {
    return { valid: false, error: 'Invalid narration_mode' };
  }
  
  // Scenes
  if (!Array.isArray(sb.scenes)) {
    return { valid: false, error: 'scenes is not an array' };
  }
  
  if (sb.scenes.length === 0) {
    return { valid: false, error: 'scenes is empty' };
  }
  
  if (sb.scenes.length > 20) {
    return { valid: false, error: 'scenes too many (max 20)' };
  }
  
  // Chaque scène
  for (const scene of sb.scenes) {
    if (!scene || typeof scene !== 'object') {
      return { valid: false, error: 'Invalid scene' };
    }
    
    const s = scene as Record<string, unknown>;
    
    // Champs scène obligatoires
    const sceneRequired = ['id', 'order', 'title', 'duration_ms', 'blocks'];
    for (const field of sceneRequired) {
      if (!(field in s)) {
        return { valid: false, error: `Scene missing field: ${field}` };
      }
    }
    
    // Blocks
    if (!Array.isArray(s.blocks)) {
      return { valid: false, error: 'Scene blocks is not an array' };
    }
    
    if (s.blocks.length === 0) {
      return { valid: false, error: 'Scene blocks is empty' };
    }
    
    if (s.blocks.length > 10) {
      return { valid: false, error: 'Scene blocks too many (max 10)' };
    }
    
    // Chaque bloc
    for (const block of s.blocks) {
      if (!block || typeof block !== 'object') {
        return { valid: false, error: 'Invalid block' };
      }
      
      const b = block as Record<string, unknown>;
      
      // Champs bloc obligatoires
      const blockRequired = ['id', 'type', 'content', 'order', 'visible'];
      for (const field of blockRequired) {
        if (!(field in b)) {
          return { valid: false, error: `Block missing field: ${field}` };
        }
      }
      
      // Style optionnel avec valeur par défaut
      if (!('style' in b) || b.style === null || b.style === undefined) {
        (b as Record<string, unknown>).style = {
          fontSize: 16,
          fontWeight: 'normal',
          color: '#000000',
        };
      }
      
      // Type valide
      const validTypes = ['title', 'paragraph', 'formula', 'definition', 'exercise', 'correction'];
      if (!validTypes.includes(b.type as string)) {
        return { valid: false, error: `Invalid block type: ${b.type}` };
      }
      
      // Contenu non vide
      if (!b.content || (b.content as string).trim().length === 0) {
        return { valid: false, error: 'Block content is empty' };
      }
    }
  }
  
  // Taille JSON
  const jsonStr = JSON.stringify(sb);
  if (jsonStr.length > 100000) {
    return { valid: false, error: 'Storyboard too large (max 100KB)' };
  }
  
  return { valid: true };
}

// ─── System Prompts per Mode ───────────────────────────────────────────────
function getSystemPrompt(mode: string, renderer: string, theme: string, narrationMode: string): string {
  const basePrompt = `Tu es un expert en création de Storyboards pédagogiques pour le Smart Whiteboard Academia.

Ton rôle est de générer un Storyboard JSON valide qui sera utilisé pour créer une vidéo pédagogique.

RÈGLES STRICTES :
1. Le Storyboard doit être conforme au format JSON version "1.0"
2. Structure le contenu en 5-10 scènes
3. Chaque scène contient 3-6 blocs
4. Utilise les types de blocs appropriés (title, paragraph, formula, definition, exercise, correction)
5. Adapte le contenu au renderer "${renderer}" et au thème "${theme}"
6. narration_mode DOIT être exactement "${narrationMode}" (valeurs acceptées: none, tts, userRecording)

FORMAT JSON REQUIS :
{
  "version": "1.0",
  "created_at": "iso8601",
  "created_by": "uuid",
  "subject": "...",
  "renderer": "${renderer}",
  "theme": "${theme}",
  "narration_mode": "...",
  "export_settings": {
    "format": "mp4",
    "resolution": {"width": 1080, "height": 1920},
    "frame_rate": 30,
    "video_codec": "h264",
    "audio_codec": "aac"
  },
  "scenes": [
    {
      "id": "uuid",
      "order": 0,
      "title": "...",
      "duration_ms": 5000,
      "transition": {},
      "blocks": [
        {
          "id": "uuid",
          "type": "title|paragraph|formula|definition|exercise|correction",
          "content": "...",
          "order": 0,
          "visible": true,
          "animation": {},
          "position": {},
          "style": {}
        }
      ]
    }
  ]
}

RÉPONSE :
Réponds UNIQUEMENT avec le JSON valide, sans markdown, sans commentaire.`;

  switch (mode) {
    case 'simple_subject':
      return basePrompt + `

MODE A : SUJET SIMPLE
Génère un Storyboard JSON valide pour le sujet fourni.
Structure le contenu de manière pédagogique :
- Introduction au sujet
- Définitions clés
- Exemples concrets
- Exercice d'application
- Correction`;

    case 'full_text':
      return basePrompt + `

MODE B : TEXTE COMPLET
Génère un Storyboard JSON valide à partir du texte complet fourni.
Structure le contenu en scènes basées sur le texte :
- Résumé du texte
- Points clés
- Définitions importantes
- Exemples du texte
- Exercice basé sur le texte
- Correction`;

    case 'plan':
      return basePrompt + `

MODE C : PLAN
Génère un Storyboard JSON valide à partir du plan structuré fourni.
Structure le contenu en scènes basées sur le plan (une scène par section) :
- Développe chaque section du plan en détail
- Ajoute des exemples pour chaque section
- Inclut un exercice d'application
- Fournis la correction`;

    case 'existing_course':
      return basePrompt + `

MODE D : COURS EXISTANT
Génère un Storyboard JSON valide à partir du cours existant.
Structure le contenu en scènes basées sur le cours :
- Résumé du cours
- Points clés du cours
- Définitions importantes
- Exemples du cours
- Exercice basé sur le cours
- Correction`;

    default:
      return basePrompt;
  }
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
    const mode = (body.mode ?? 'simple_subject').toString().trim();
    const subject = (body.subject ?? '').toString().trim();
    const content = (body.content ?? '').toString().trim();
    const renderer = (body.renderer ?? 'scientific').toString().trim();
    const theme = (body.theme ?? 'scientific').toString().trim();
    const narrationMode = (body.narration_mode ?? 'none').toString().trim();

    // ── 1. Reserve credits ───────────────────────────────────────────────
    const { data: resData } = await supabase.rpc('app_student_reserve_credits', {
      p_action_code: ACTION_CODE,
      p_edge_function: EDGE_FN,
      p_student_id: userId,
    });
    const res = resData as Record<string, unknown> | null;
    if (!res?.success) {
      return jsonResponse({ 
        error: 'insufficient_credits', 
        balance: res?.balance ?? 0, 
        cost: res?.cost ?? 0,
        message: `Crédits insuffisants. Il vous faut ${res?.cost ?? 0} crédits (solde: ${res?.balance ?? 0}).` 
      }, 402);
    }
    const reservationId = (res.reservation_id as string) || '';

    // ── 2. Build prompt ─────────────────────────────────────────────────
    const systemPrompt = getSystemPrompt(mode, renderer, theme, narrationMode);
    
    let userPrompt = '';
    switch (mode) {
      case 'simple_subject':
        userPrompt = `Sujet : "${subject}"`;
        break;
      case 'full_text':
        userPrompt = `Sujet : "${subject}"\n\nTEXTE COMPLET :\n"${content}"`;
        break;
      case 'plan':
        userPrompt = `Sujet : "${subject}"\n\nPLAN :\n"${content}"`;
        break;
      case 'existing_course':
        userPrompt = `COURS ID : "${content}"\nSUJET : "${subject}"`;
        break;
    }

    const messages = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ];

    // ── 3. Call LLM with cascade ─────────────────────────────────────────
    let cascadeResult: CascadeResult;
    try {
      cascadeResult = await callWithCascade(messages, 4000);
    } catch (e) {
      await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      return jsonResponse({ error: 'llm_error', detail: (e as Error).message?.slice(0, 300) }, 502);
    }

    const rawResponse = cascadeResult.content;

    // ── 4. Clean markdown backticks and parse JSON ─────────────────────
    let jsonToParse = rawResponse.trim();
    
    // Remove markdown code blocks if present
    if (jsonToParse.startsWith('```json')) {
      jsonToParse = jsonToParse.slice(7);
    } else if (jsonToParse.startsWith('```')) {
      jsonToParse = jsonToParse.slice(3);
    }
    
    if (jsonToParse.endsWith('```')) {
      jsonToParse = jsonToParse.slice(0, -3);
    }
    
    jsonToParse = jsonToParse.trim();

    let parsed: unknown;
    try {
      parsed = JSON.parse(jsonToParse);
    } catch (e) {
      await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      return jsonResponse({ 
        error: 'invalid_json', 
        detail: (e as Error).message?.slice(0, 300), 
        raw: rawResponse.slice(0, 500) 
      }, 500);
    }

    // ── 5. Validate Storyboard (PHASE_D3A21_GENERATION_CONTRACT_LOCK.md) ─────
    const validation = validateStoryboard(parsed);
    if (!validation.valid) {
      await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      return jsonResponse({ 
        error: 'invalid_storyboard', 
        detail: validation.error,
        raw: rawResponse.slice(0, 500) 
      }, 500);
    }

    // ── 6. Inject metadata ─────────────────────────────────────────────────
    const sb = parsed as Record<string, unknown>;
    sb.created_at = new Date().toISOString();
    sb.created_by = userId;
    sb.subject = subject;
    sb.renderer = renderer;
    sb.theme = theme;
    sb.narration_mode = narrationMode;

    // ── 7. Store in Supabase ───────────────────────────────────────────────
    const { data: projectData } = await supabase.rpc('whiteboard_create_project', {
      p_student_id: userId,
      p_subject: subject,
      p_renderer_id: renderer,
      p_theme_id: theme,
      p_narration_mode: narrationMode,
      p_storyboard_json: sb,
    });

    // ── 8. Confirm credits ────────────────────────────────────────────────
    await supabase.rpc('app_student_confirm_credits', {
      p_reservation_id: reservationId,
      p_openrouter_cost_usd: cascadeResult.costUsd,
      p_openrouter_model: cascadeResult.model,
      p_tokens_input: cascadeResult.usage.prompt_tokens || 0,
      p_tokens_output: cascadeResult.usage.completion_tokens || 0,
    });

    // ── 9. Log generation ─────────────────────────────────────────────────
    const logSql = `
      INSERT INTO app.whiteboard_ai_generations (
        created_by,
        generation_type,
        input_params,
        output_json,
        status,
        model_used,
        tokens_input,
        tokens_output,
        cost_usd
      ) VALUES (
        '${userId}',
        'storyboard',
        '${JSON.stringify(body).replace(/'/g, "''")}'::jsonb,
        '${JSON.stringify(sb).replace(/'/g, "''")}'::jsonb,
        'validated',
        '${cascadeResult.model}',
        ${cascadeResult.usage.prompt_tokens || 0},
        ${cascadeResult.usage.completion_tokens || 0},
        ${cascadeResult.costUsd}
      )
    `.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();

    await supabase.rpc('admin_execute_sql', { p_sql: logSql });

    // ── 10. Return success ────────────────────────────────────────────────
    return jsonResponse({
      success: true,
      storyboard_json: sb,
      project_data: projectData,
      credits_used: 15,
      model: cascadeResult.model,
      tokens_input: cascadeResult.usage.prompt_tokens || 0,
      tokens_output: cascadeResult.usage.completion_tokens || 0,
      cost_usd: cascadeResult.costUsd,
    });

  } catch (e) {
    console.error('Error:', e);
    return jsonResponse({ 
      error: 'internal_error', 
      detail: (e as Error).message?.slice(0, 300) 
    }, 500);
  }
});
