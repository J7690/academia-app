// Appel OpenRouter en cascade (modele principal puis modele de repli).
// Module separe pour etre reutilisable par la fonction de diagnostic
// whiteboard-storyboard-smoke, qui doit faire EXACTEMENT le meme appel que la
// production — sinon le diagnostic ne prouverait rien.

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';

const TEXT_CASCADE = [
  { model: OPENROUTER_MODEL, tier: 'primary' },
  { model: OPENROUTER_FALLBACK_MODEL, tier: 'fallback' },
].filter(m => m.model);

export interface CascadeResult { content: string; model: string; tier: string; usage: { prompt_tokens: number; completion_tokens: number; total_tokens: number }; costUsd: number; }

export async function callWithCascade(msgs: Array<{role:string;content:string}>, maxTok: number): Promise<CascadeResult> {
  const errs: string[] = [];
  for (const { model, tier } of TEXT_CASCADE) {
    if (!model) continue;
    try {
      const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method:'POST',
        headers:{ Authorization:`Bearer ${OPENROUTER_API_KEY}`, 'Content-Type':'application/json', Accept:'application/json' },
        body:JSON.stringify({ model, messages:msgs, temperature:0.35, max_tokens:maxTok })
      });
      if (!r.ok) { errs.push(`${model}(${r.status})`); continue; }
      const d = await r.json();
      const c = (d?.choices?.[0]?.message?.content??'').toString().trim();
      if (!c) { errs.push(`${model}:empty`); continue; }
      const u = d?.usage ?? {prompt_tokens:0,completion_tokens:0,total_tokens:0};
      const cost = tier==='free'?0:((u.prompt_tokens||0)*0.0000001+(u.completion_tokens||0)*0.0000004);
      return {content:c,model,tier,usage:u,costUsd:cost};
    } catch(e) { errs.push(`${model}:${(e as Error).message?.slice(0,60)}`); }
  }
  throw new Error(`All models failed: ${errs.join(' | ')}`);
}

// Les modeles enveloppent parfois leur JSON dans un bloc markdown malgre la consigne.
export function stripCodeFences(content: string): string {
  let s = content.trim();
  if (s.startsWith('```json')) s = s.slice(7);
  else if (s.startsWith('```')) s = s.slice(3);
  if (s.endsWith('```')) s = s.slice(0, -3);
  return s.trim();
}
