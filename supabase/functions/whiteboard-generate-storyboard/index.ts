// Supabase Edge Function: whiteboard-generate-storyboard
// v3 SPOT STUDIO (27/07/2026) : la video est REALISEE comme un spot moderne.
//   - narration PAR BLOC : la voix accompagne chaque bloc pendant qu'il s'ecrit
//     (contiguite temporelle de Mayer : ce qui s'affiche = ce qui se dit).
//   - beat par scene (hook|concept|example|exercise|correction|recap) : le moteur
//     de rendu adapte la mise en scene au role narratif.
//   - key_words par bloc : mots-cles pour la typographie cinetique (pop couleur).
//   - scene recap finale obligatoire : carte de synthese animee.
// Herite de v2.4 : emphasis cible, write_speed, recall, writing_style.
//
// NOTE : ce fichier avait diverge de la version reellement deployee (v35). Il est
// desormais aligne sur le deploiement, v2.4 comprise.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
// Validation extraite dans son propre module pour etre testable sans demarrer le
// serveur HTTP : voir validate_test.ts (regression de la panne du 27/07/2026).
import { validateStoryboard } from './validate.ts';
// Prompt et appel OpenRouter partages avec la fonction de diagnostic
// whiteboard-storyboard-smoke : une seule source de verite.
import { getSystemPrompt } from './prompt.ts';
import { getCapsulePrompt } from './prompt_capsule.ts';
import { validateCapsule } from './validate_capsule.ts';
import { callWithCascade, stripCodeFences, type CascadeResult } from './llm.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const ACTION_CODE = 'generate_storyboard';
const EDGE_FN = 'whiteboard-generate-storyboard';

const CORS_HEADERS: Record<string, string> = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept', 'Access-Control-Allow-Methods': 'POST,OPTIONS' };
function jsonResponse(data: unknown, status = 200): Response { return new Response(JSON.stringify(data), { status, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }); }


serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);
  try {
    const authHeader = req.headers.get('authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false }, global: { headers: { Authorization: `Bearer ${jwt}` } } });
    const { data: userData, error: userError } = await supabaseUser.auth.getUser(jwt);
    if (userError || !userData?.user) return jsonResponse({ error: 'not_authenticated' }, 401);
    const userId = userData.user.id;

    const body = await req.json();
    const mode = (body.mode ?? 'simple_subject').toString().trim();
    const subject = (body.subject ?? '').toString().trim();
    const content = (body.content ?? '').toString().trim();
    const renderer = (body.renderer ?? 'scientific').toString().trim();
    const theme = (body.theme ?? 'scientific').toString().trim();
    const narrationMode = (body.narration_mode ?? 'none').toString().trim();
    const engine = (body.engine ?? 'slideshow').toString().trim();
    // Style d'ecriture choisi par l'etudiant : manuscrit (defaut) ou machine.
    const writingStyle = (body.writing_style ?? '').toString().trim() === 'typed' ? 'typed' : 'handwriting';

    const { data: resData } = await supabase.rpc('app_student_reserve_credits', { p_action_code: ACTION_CODE, p_edge_function: EDGE_FN, p_student_id: userId });
    const res = resData as Record<string, unknown> | null;
    if (!res?.success) return jsonResponse({ error: 'insufficient_credits', balance: res?.balance ?? 0, cost: res?.cost ?? 0, message: `Credits insuffisants. Il vous faut ${res?.cost ?? 0} credits (solde: ${res?.balance ?? 0}).` }, 402);
    const reservationId = (res.reservation_id as string) || '';

    // DEUX PRODUITS, DEUX ECRITURES.
    //
    // Un tableau ecrit des mots et en entoure certains ; une animation 3D ne
    // peut RIEN ecrire : elle rend le propos en geometrie lumineuse. Faire
    // generer un storyboard de tableau puis le TRADUIRE cote serveur revenait
    // a faire deviner la forme a un adaptateur, a partir du type de bloc. La
    // capsule sortait coherente, mais aucune intention n'avait ete exprimee.
    //
    // Ce qui reste commun, et c'est l'essentiel : la NARRATION. Meme cours,
    // meme voix, meme cout en credits -- seule la mise en forme change.
    const pourAnimation = engine === 'studio';
    const systemPrompt = pourAnimation
      ? getCapsulePrompt(mode, renderer)
      : getSystemPrompt(mode, renderer, theme, narrationMode);
    let userPrompt = '';
    switch (mode) {
      case 'simple_subject': userPrompt = `Sujet : "${subject}"`; break;
      case 'full_text': userPrompt = `Sujet : "${subject}"\n\nTEXTE COMPLET :\n"${content}"`; break;
      case 'plan': userPrompt = `Sujet : "${subject}"\n\nPLAN :\n"${content}"`; break;
      case 'existing_course': userPrompt = `COURS ID : "${content}"\nSUJET : "${subject}"`; break;
    }
    const messages = [ { role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt } ];

    let cascadeResult: CascadeResult;
    try { cascadeResult = await callWithCascade(messages, 4500); }
    catch (e) { await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId }); return jsonResponse({ error: 'llm_error', detail: (e as Error).message?.slice(0, 300) }, 502); }

    const jsonToParse = stripCodeFences(cascadeResult.content);

    let parsed: unknown;
    try { parsed = JSON.parse(jsonToParse); }
    catch (e) { await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId }); return jsonResponse({ error: 'invalid_json', detail: (e as Error).message?.slice(0, 300), raw: cascadeResult.content.slice(0, 500) }, 500); }

    // ON NETTOIE, ON NE REJETTE PAS -- des deux cotes. Un refus fait perdre
    // a l'etudiant ses credits ET sa video ; on ne refuse donc que
    // l'irrecuperable, et ce refus declenche un remboursement.
    let sb: Record<string, unknown>;
    if (pourAnimation) {
      const vc = validateCapsule(parsed);
      if (!vc.valid) { await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId }); return jsonResponse({ error: 'invalid_capsule', detail: vc.error, raw: cascadeResult.content.slice(0, 500) }, 500); }
      sb = vc.capsule as Record<string, unknown>;
      sb.corrections = vc.corrections;
    } else {
      const validation = validateStoryboard(parsed);
      if (!validation.valid) { await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId }); return jsonResponse({ error: 'invalid_storyboard', detail: validation.error, raw: cascadeResult.content.slice(0, 500) }, 500); }
      sb = parsed as Record<string, unknown>;
    }
    sb.created_at = new Date().toISOString();
    sb.created_by = userId; sb.subject = subject; sb.renderer = renderer; sb.theme = theme; sb.narration_mode = narrationMode; sb.engine = engine;
    sb.writing_style = writingStyle;

    // La creation du projet est le SEUL resultat qui compte pour l'etudiant : si elle
    // echoue, on rembourse et on le dit, plutot que de repondre "success" avec un
    // project_data vide que l'application ne saurait pas exploiter.
    const { data: projectData, error: projectError } = await supabase.rpc('whiteboard_create_project', { p_student_id: userId, p_subject: subject, p_renderer_id: renderer, p_theme_id: theme, p_narration_mode: narrationMode, p_storyboard_json: sb });
    if (projectError || !projectData) {
      await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
      return jsonResponse({ error: 'project_creation_failed', detail: projectError?.message?.slice(0, 300) ?? 'no project returned' }, 500);
    }

    await supabase.rpc('app_student_confirm_credits', { p_reservation_id: reservationId, p_openrouter_cost_usd: cascadeResult.costUsd, p_openrouter_model: cascadeResult.model, p_tokens_input: cascadeResult.usage.prompt_tokens || 0, p_tokens_output: cascadeResult.usage.completion_tokens || 0 });

    // Journal d'observabilite : utile mais JAMAIS bloquant. Le cours existe et les
    // credits sont debites ; echouer ici afficherait une erreur a l'etudiant pour un
    // cours parfaitement genere. On journalise l'echec du journal, et on continue.
    try {
      const logSql = `INSERT INTO app.whiteboard_ai_generations ( created_by, generation_type, input_params, output_json, status, model_used, tokens_input, tokens_output, cost_usd ) VALUES ( '${userId}', 'storyboard', '${JSON.stringify(body).replace(/'/g, "''")}'::jsonb, '${JSON.stringify(sb).replace(/'/g, "''")}'::jsonb, 'validated', '${cascadeResult.model}', ${cascadeResult.usage.prompt_tokens || 0}, ${cascadeResult.usage.completion_tokens || 0}, ${cascadeResult.costUsd} )`;
      const { error: logError } = await supabase.rpc('admin_execute_sql', { p_sql: logSql });
      if (logError) console.error('[whiteboard-generate-storyboard] journal non ecrit:', logError.message);
    } catch (e) {
      console.error('[whiteboard-generate-storyboard] journal non ecrit:', (e as Error).message);
    }

    return jsonResponse({ success: true, storyboard_json: sb, project_data: projectData, credits_used: 15, model: cascadeResult.model, tokens_input: cascadeResult.usage.prompt_tokens || 0, tokens_output: cascadeResult.usage.completion_tokens || 0, cost_usd: cascadeResult.costUsd });
  } catch (e) {
    console.error('Error:', e);
    return jsonResponse({ error: 'internal_error', detail: (e as Error).message?.slice(0, 300) }, 500);
  }
});
