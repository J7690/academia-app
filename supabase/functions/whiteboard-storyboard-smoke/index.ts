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

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { getSystemPrompt } from '../whiteboard-generate-storyboard/prompt.ts';
import { callWithCascade, stripCodeFences } from '../whiteboard-generate-storyboard/llm.ts';
import { validateStoryboard } from '../whiteboard-generate-storyboard/validate.ts';

const CORS_HEADERS: Record<string, string> = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept', 'Access-Control-Allow-Methods': 'POST,OPTIONS' };
function jsonResponse(data: unknown, status = 200): Response { return new Response(JSON.stringify(data), { status, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }); }

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);
  try {
    const body = await req.json().catch(() => ({}));
    const subject = typeof body.subject === 'string' && body.subject.trim() ? body.subject.trim() : 'La Loi Normale Centree Reduite';
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
