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

// ── Un modele par METIER (29/10/2026) ─────────────────────────────────────────
// La chaine en couches (chaine_capsule.ts) confie chaque acte a un modele choisi
// pour lui. Choix fait sur le catalogue REEL d'OpenRouter le 29/10/2026 (457
// modeles, /api/v1/models ; tous les candidats a 100 % de disponibilite sur 30 min,
// /api/v1/models/<id>/endpoints) et sur des classements externes : Claude en tete
// de l'ecriture (LMArena, ecriture creative), Flash et Haiku pour le JSON rapide et
// peu cher. Le verdict final appartient au BANC, sur notre tache : c'est pourquoi
// chaque appel accepte une liste de remplacement (`roles`), sans redeploiement.
// Detail et sources : docs/STUDIO_3D_CHAINE_EN_COUCHES_2026-10-29.md.
export type Role = 'scenariste' | 'illustrateur' | 'realisateur';
export const ROLES_PAR_DEFAUT: Record<Role, string[]> = {
  // Ecrire un cours : pedagogie, francais, narration. Le modele le mieux classe en
  // ecriture a un prix raisonnable pour 1 a 2 000 jetons par capsule.
  scenariste: ['anthropic/claude-sonnet-5.5', 'google/gemini-3.8-flash', 'openai/gpt-6.1-sol'],
  // Traduire une phrase en gestes et coordonnees : JSON strict, vite, une scene a la
  // fois et en parallele. BANC DU 29/10 (5 sujets) : Haiku sans raisonnement rend une
  // scene en 1,4 a 2,5 s, autant de gestes que Flash, pour un huitieme du prix ; Flash
  // (raisonnement « low ») mettait 3 a 5 s, et 16 a 20 s pour une scene sur six —
  // attente cote fournisseur, pas ecriture (220 a 340 jetons dans les deux cas).
  // Flash passe donc en DERNIER recours ; DeepSeek, second, a repondu en 1,4 s la
  // seule fois ou il a servi (une mesure, pas une moyenne).
  illustrateur: ['anthropic/claude-haiku-5.5', 'deepseek/deepseek-v4.1-flash', 'google/gemini-3.8-flash'],
  // Choisir des plans dans une liste fermee : court, tres rapide, tres peu cher.
  realisateur: ['anthropic/claude-haiku-5.5', 'openai/gpt-6-luna'],
};

/** Les modeles d'un role : liste de l'appel, sinon secret OPENROUTER_ROLES, sinon defaut. */
export function modelesDuRole(role: Role, remplacement?: Partial<Record<Role, string[]>>): string[] {
  if (remplacement?.[role]?.length) return remplacement[role]!;
  try {
    const env = JSON.parse(Deno.env.get('OPENROUTER_ROLES') || '{}') as Partial<Record<Role, string[]>>;
    if (env[role]?.length) return env[role]!;
  } catch { /* secret illisible : on garde le defaut */ }
  return ROLES_PAR_DEFAUT[role];
}

export interface ResultatRole { content: string; model: string; ms: number; jetonsEntree: number; jetonsSortie: number; jetonsRaisonnement?: number; coutUsd: number; essais: string[] }

/** Reglages d'un appel. Le banc les change sans redeploiement. */
export type Reglages = { effort?: 'none' | 'low' | 'medium' | 'high'; maxTok?: number; delaiMs?: number };

// L'illustrateur traduit, il ne reflechit pas : sans raisonnement il va trois fois plus
// vite (banc du 29/10). Le delai coupe un appel coince et passe au modele suivant.
export const REGLAGES_PAR_DEFAUT: Record<Role, Reglages> = {
  scenariste: { effort: 'low', delaiMs: 40000 },
  illustrateur: { effort: 'none', delaiMs: 15000 },
  realisateur: { effort: 'none', delaiMs: 15000 },
};

/** Un acte confie a son metier : modeles essayes dans l'ordre, JSON exige, cout REEL
 *  (celui qu'OpenRouter facture, `usage.include`). Chaque echec est garde dans `essais`.
 *
 *  UN JSON TRONQUE OU ILLISIBLE PASSE AU MODELE SUIVANT. Premier essai reel du 29/10 :
 *  le scenariste a rendu un JSON coupe au 2 445e caractere apres 22 s — le budget de
 *  sortie (3 000) consomme en partie par le raisonnement du modele. Toute la chaine
 *  echouait sur une seule reponse incomplete. */
export async function appelerRole(
  role: Role, msgs: Array<{ role: string; content: string }>, maxTok: number,
  remplacement?: Partial<Record<Role, string[]>>, temperature = 0.35, reglages: Reglages = {},
): Promise<ResultatRole> {
  const essais: string[] = [];
  const regl = { ...REGLAGES_PAR_DEFAUT[role], ...reglages };
  const appeler = (model: string, effort: string, signal: AbortSignal) =>
    fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST', signal,
      headers: { Authorization: `Bearer ${OPENROUTER_API_KEY}`, 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ model, messages: msgs, temperature, max_tokens: regl.maxTok ?? maxTok,
        response_format: { type: 'json_object' }, usage: { include: true },
        ...(effort === 'none' ? { reasoning: { enabled: false } } : { reasoning: { effort } }) }),
    });
  // `ms` compte TOUS les essais, pas seulement celui qui a repondu : mesure du 29/10,
  // une reprise annoncee a 1,4 s en avait pris pres de 20 (deux modeles echoues avant).
  const t0 = Date.now();
  for (const model of modelesDuRole(role, remplacement)) {
    const ctrl = new AbortController();
    const minuterie = setTimeout(() => ctrl.abort(), regl.delaiMs ?? 30000);
    try {
      let r = await appeler(model, regl.effort ?? 'low', ctrl.signal);
      // Certains modeles refusent qu'on coupe leur raisonnement (mesure du 29/10 :
      // gemini-3.8-flash, 400 « Reasoning is mandatory for this endpoint »). On ne
      // perd pas le modele pour autant : on le rappelle avec un raisonnement court.
      if (!r.ok && r.status === 400 && regl.effort === 'none') {
        const texte = await r.text();
        if (/reasoning is mandatory/i.test(texte)) { essais.push(`${model}: raisonnement obligatoire, rappel en low`); r = await appeler(model, 'low', ctrl.signal); }
        else { essais.push(`${model}(400) ${texte.slice(0, 80)}`); continue; }
      }
      if (!r.ok) { essais.push(`${model}(${r.status}) ${(await r.text()).slice(0, 80)}`); continue; }
      const d = await r.json();
      const choix = d?.choices?.[0];
      const c = (choix?.message?.content ?? '').toString().trim();
      const u = d?.usage ?? {};
      const raisonnement = u.completion_tokens_details?.reasoning_tokens || 0;
      if (!c) { essais.push(`${model}:vide`); continue; }
      if (choix?.finish_reason === 'length') { essais.push(`${model}:tronque (${u.completion_tokens} jetons dont ${raisonnement} de raisonnement)`); continue; }
      try { JSON.parse(stripCodeFences(c)); }
      catch (e) { essais.push(`${model}:json (${(e as Error).message.slice(0, 50)})`); continue; }
      return { content: c, model, ms: Date.now() - t0, jetonsEntree: u.prompt_tokens || 0, jetonsSortie: u.completion_tokens || 0,
        jetonsRaisonnement: raisonnement, coutUsd: Number(u.cost) || 0, essais };
    } catch (e) {
      essais.push(ctrl.signal.aborted ? `${model}: delai de ${regl.delaiMs ?? 30000} ms depasse` : `${model}:${(e as Error).message?.slice(0, 60)}`);
    } finally { clearTimeout(minuterie); }
  }
  throw new Error(`role ${role} : tous les modeles ont echoue : ${essais.join(' | ')}`);
}

// Les modeles enveloppent parfois leur JSON dans un bloc markdown malgre la consigne.
export function stripCodeFences(content: string): string {
  let s = content.trim();
  if (s.startsWith('```json')) s = s.slice(7);
  else if (s.startsWith('```')) s = s.slice(3);
  if (s.endsWith('```')) s = s.slice(0, -3);
  return s.trim();
}
