// Supabase Edge Function: whiteboard-storyboard-smoke — DIAGNOSTIC UNIQUEMENT.
//
// Reproduit EXACTEMENT le trajet de generation de whiteboard-generate-storyboard
// (meme prompt, meme appel OpenRouter, meme validation — modules partages), mais :
//   - sans authentification etudiante, sans reservation ni debit de credits,
//   - sans creation de projet, sans ecriture en base.
// Elle repond un compte rendu : le storyboard etait-il valide, combien de scenes,
// quels beats, quel modele a repondu. C'est le moyen de tester la chaine LLM en
// production sans faire payer personne.
//
// Cout : un appel OpenRouter par invocation. A n'utiliser que pour le diagnostic.

//
// MODE CAPSULE (28/10/2026) : `{ "engine": "studio", "subject": "…" }` rejoue la
// génération d'une capsule 3D (getCapsulePrompt + validateCapsule, mêmes
// modules) et rend, scène par scène, le DÉCOR choisi, le foyer, les verbes, et
// le temps de réponse du modèle. C'est le banc du lot 3.
//
// RÉSERVÉE À LA CLÉ DE SERVICE : sans authentification, n'importe qui pourrait
// déclencher des appels payants. La passerelle vérifie la signature du jeton.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { getSystemPrompt } from '../whiteboard-generate-storyboard/prompt.ts';
import { getCapsulePrompt } from '../whiteboard-generate-storyboard/prompt_capsule.ts';
import { callWithCascade, stripCodeFences } from '../whiteboard-generate-storyboard/llm.ts';
import { validateStoryboard } from '../whiteboard-generate-storyboard/validate.ts';
import { validateCapsule } from '../whiteboard-generate-storyboard/validate_capsule.ts';
import { resoudreChimie } from '../whiteboard-generate-storyboard/chimie.ts';
import { appelerReel, type Etape, genererCapsuleEnCouches } from '../whiteboard-generate-storyboard/chaine_capsule.ts';
import type { Reglages, Role } from '../whiteboard-generate-storyboard/llm.ts';

function role(jeton: string): string {
  try { return JSON.parse(atob(jeton.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))).role ?? ''; }
  catch { return ''; }
}

/** MODE CHAÎNE (29/10/2026) : `{ "chaine": true, "roles": { "scenariste": ["…"] } }`
 *  fabrique la capsule en couches (chaine_capsule.ts) et rend, en plus, chaque
 *  étape (métier, modèle, temps, coût réel, essais) : c'est le banc des métiers. */
async function essaiCapsule(subject: string, complet = false, chaine = false, roles?: Partial<Record<Role, string[]>>, reglages?: Partial<Record<Role, Reglages>>): Promise<Record<string, unknown>> {
  const t0 = Date.now();
  let vc: ReturnType<typeof validateCapsule>;
  let model = '', tokens_output = 0, etapes: Etape[] = [], reprises: string[] = [], a_montrer: Record<string, unknown> = {};
  if (chaine) {
    try {
      const r = await genererCapsuleEnCouches(subject, appelerReel(roles, reglages));
      vc = r.vc; etapes = r.etapes; reprises = r.reprises;
      model = 'chaine'; tokens_output = etapes.reduce((s, e) => s + e.jetonsSortie, 0);
      for (const s of r.brut.scenes) a_montrer[String(s.id)] = s.a_montrer;
    } catch (e) { return { step: 'llm', ok: false, subject, detail: (e as Error).message?.slice(0, 300), ms_llm: Date.now() - t0 }; }
  } else {
    const messages = [{ role: 'system', content: getCapsulePrompt('simple_subject', 'scientific') }, { role: 'user', content: `Sujet : "${subject}"` }];
    let cascade;
    try { cascade = await callWithCascade(messages, 4500); }
    catch (e) { return { step: 'llm', ok: false, subject, detail: (e as Error).message?.slice(0, 300) }; }
    let parsed: unknown;
    try { parsed = JSON.parse(stripCodeFences(cascade.content)); }
    catch (e) { return { step: 'json_parse', ok: false, subject, ms_llm: Date.now() - t0, model: cascade.model, detail: (e as Error).message?.slice(0, 200) }; }
    vc = validateCapsule(parsed);
    model = cascade.model; tokens_output = cascade.usage.completion_tokens || 0;
  }
  const ms_llm = Date.now() - t0;
  if (!vc.valid) return { step: 'validate', ok: false, subject, ms_llm, model, detail: vc.error };
  // Même trajet que la production : la chimie résolue après la validation.
  const t1 = Date.now();
  try { await resoudreChimie(vc.capsule!, vc.corrections); }
  catch (e) { vc.corrections.push(`chimie non resolue : ${(e as Error).message?.slice(0, 120)}`); }
  const ms_chimie = Date.now() - t1;
  const scenes = (vc.capsule!.scenes as Record<string, unknown>[]).map((s) => {
    const gestes = (s.gestes as Record<string, unknown>[]).filter((g) => g.pour !== 'pod');
    return {
      id: s.id, decor: s.decor, foyer: s.foyer ?? null, flux: !!s.flux, intention: s.intention, sujet: s.sujet,
      verbes: gestes.map((g) => g.verbe),
      termes: gestes.filter((g) => g.verbe === 'convoquer').map((g) => (g.parametres as Record<string, unknown>).terme),
    };
  });
  return {
    step: 'done', ok: true, subject, model, ms_llm, ms_chimie,
    tokens_output, titre: vc.capsule!.titre, scenes, corrections: vc.corrections,
    ...(chaine ? { etapes, reprises, a_montrer, cout_usd: Math.round(etapes.reduce((s, e) => s + e.coutUsd, 0) * 1e5) / 1e5 } : {}),
    // `complet` : la capsule entière, pour la rejouer dans le lecteur (banc de la phase B).
    ...(complet ? { capsule: vc.capsule } : {}),
  };
}

const CORS_HEADERS: Record<string, string> = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept', 'Access-Control-Allow-Methods': 'POST,OPTIONS' };
function jsonResponse(data: unknown, status = 200): Response { return new Response(JSON.stringify(data), { status, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }); }

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);
  const jeton = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '').trim();
  if (role(jeton) !== 'service_role') return jsonResponse({ error: 'service_role_requis' }, 403);
  try {
    const body = await req.json().catch(() => ({}));
    // `{ "engine": "etat" }` : les interrupteurs que la PRODUCTION lit (29/10/2026).
    // Les secrets valent pour toutes les fonctions du projet ; ce client ne peut pas
    // les lire dans le tableau de bord. On dit s'ils sont poses, jamais leur valeur.
    if (body.engine === 'etat') {
      const v = Deno.env.get('CAPSULE_CHAINE');
      // La chaine est allumee par defaut ; seul CAPSULE_CHAINE=0 la coupe (index.ts).
      return jsonResponse({ capsule_chaine_present: v !== undefined, chaine_coupee_par_secret: v === '0', openrouter_roles_present: !!Deno.env.get('OPENROUTER_ROLES') });
    }
    const subject =typeof body.subject === 'string' && body.subject.trim() ? body.subject.trim() : 'La Loi Normale Centree Reduite';
    if (body.engine === 'studio') {
      const roles = body.roles && typeof body.roles === 'object' ? body.roles as Partial<Record<Role, string[]>> : undefined;
      const reglages = body.reglages && typeof body.reglages === 'object' ? body.reglages as Partial<Record<Role, Reglages>> : undefined;
      return jsonResponse(await essaiCapsule(subject.slice(0, 200), body.complet === true, body.chaine === true, roles, reglages));
    }
    const renderer = typeof body.renderer === 'string' ? body.renderer : 'notebook';
    const theme = typeof body.theme === 'string' ? body.theme : 'notebook';

    const t0 = Date.now();
    const systemPrompt = getSystemPrompt('simple_subject', renderer, theme, 'tts');
    const messages = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: `Sujet : "${subject}"` },
    ];

    let cascade;
    try { cascade = await callWithCascade(messages, 4500); }
    catch (e) { return jsonResponse({ step: 'llm', ok: false, detail: (e as Error).message?.slice(0, 300) }, 200); }

    const raw = stripCodeFences(cascade.content);
    let parsed: unknown;
    try { parsed = JSON.parse(raw); }
    catch (e) { return jsonResponse({ step: 'json_parse', ok: false, model: cascade.model, detail: (e as Error).message?.slice(0, 200), raw_head: cascade.content.slice(0, 400) }, 200); }

    const validation = validateStoryboard(parsed);
    if (!validation.valid) return jsonResponse({ step: 'validate', ok: false, model: cascade.model, detail: validation.error, raw_head: cascade.content.slice(0, 400) }, 200);

    // Compte rendu : assez pour juger la qualite, sans renvoyer 60 Ko de JSON.
    const sb = parsed as Record<string, unknown>;
    const scenes = sb.scenes as Record<string, unknown>[];
    const summary = scenes.map((s) => ({
      order: s.order,
      beat: s.beat ?? null,
      title: s.title,
      blocks: (s.blocks as unknown[]).length,
      has_scene_narration: typeof s.narration === 'string' && (s.narration as string).length > 0,
      block_narrations: (s.blocks as Record<string, unknown>[]).filter(b => typeof b.narration === 'string' && (b.narration as string).length > 0).length,
    }));
    return jsonResponse({
      step: 'done', ok: true,
      model: cascade.model, tier: cascade.tier,
      elapsed_ms: Date.now() - t0,
      tokens_input: cascade.usage.prompt_tokens || 0,
      tokens_output: cascade.usage.completion_tokens || 0,
      scene_count: scenes.length,
      first_beat: scenes[0]?.beat ?? null,
      last_beat: scenes[scenes.length - 1]?.beat ?? null,
      scenes: summary,
    });
  } catch (e) {
    return jsonResponse({ step: 'internal', ok: false, detail: (e as Error).message?.slice(0, 300) }, 500);
  }
});
