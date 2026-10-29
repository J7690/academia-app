// La capsule fabriquée EN COUCHES — un métier par appel (29/10/2026).
//
// POURQUOI. Jusqu'ici, un seul appel au modèle faisait tout à la fois : pédagogue,
// scénariste, illustrateur, décorateur. La consigne atteignait 17 600 caractères et
// chaque lot (phénomènes, chimie) l'allongeait encore. Jocelyn a demandé une chaîne
// où chaque acte est confié à l'agent qualifié pour lui. La littérature va dans le
// même sens : Code2Video (planificateur, codeur, critique) fait +40 % face à une
// génération d'un seul trait ; TheoremExplainAgent et MovieAgent séparent aussi les
// rôles. Détail : docs/STUDIO_3D_CHAINE_EN_COUCHES_2026-10-29.md.
//
// LES COUCHES
//   1. scénariste   : le cours (scènes, voix, décor, intention) et, pour chaque scène,
//                     ce qu'il faut MONTRER (`a_montrer`). Aucune coordonnée.
//   2. illustrateur : une scène à la fois, toutes en parallèle : les gestes.
//   3. contrôleur   : du CODE, pas un modèle. La validation existante, puis une
//                     reprise ciblée des seules scènes en défaut, une fois.
// La règle reste : l'IA choisit, notre code calcule et vérifie.

import { appelerRole, type Reglages, type ResultatRole, type Role, stripCodeFences } from "./llm.ts";
import { INTRO_CAPSULE, SECTION_DECOR, SECTION_EXEMPLES, SECTION_GESTES, SECTION_LIMITES } from "./prompt_capsule.ts";
import { TERMES_OBJETS, validateCapsule } from "./validate_capsule.ts";

type Messages = Array<{ role: string; content: string }>;
export type Appeler = (role: Role, msgs: Messages, maxTok: number) => Promise<ResultatRole>;
export type Etape = { couche: string; scene?: string; model: string; ms: number; coutUsd: number; jetonsSortie: number; essais: string[] };

// ── Couche 1 : le scénariste ────────────────────────────────────────────────
export const CONSIGNE_SCENARISTE = INTRO_CAPSULE.replace(
  "Tu ne choisis pas une forme dans une liste : tu DÉCRIS la scène, en coordonnées.\nLe moteur exécute ta description telle quelle.",
  "Tu es le PÉDAGOGUE et le SCÉNARISTE. Tu écris le cours et tu dis, scène par\nscène, ce qu'il faut montrer. D'autres que toi fabriqueront les images.",
) + SECTION_DECOR + `
════════ CE QUE LE MOTEUR SAIT MONTRER ════════

• des OBJETS RÉELS, et seulement ces ${TERMES_OBJETS.length} : ${TERMES_OBJETS.join(", ")}
• des PHÉNOMÈNES qui bougent : flamme, eau qui coule, pluie, souffle d'air ou de
  chaleur, éclair
• la CHIMIE exacte : une réaction qui s'écrit et s'équilibre, une molécule réelle
• des FLÈCHES et des ÉTIQUETTES qui désignent, du TEXTE en volume
• des FORMES fabriquées (squelettes, volumes tournés, plaques découpées)

════════ CE QUE TU RENDS ════════

UNIQUEMENT ce JSON :

{
  "titre": "titre court et concret",
  "ambiance": "savane",
  "scenes": [
    { "id": "s1", "decor": "gestes", "intention": "processus",
      "sujet": "ce que la scène montre, en 3 à 6 mots",
      "narration": "Ce que la voix dit. Phrases courtes, ton d'enseignant.",
      "duree_s": 14,
      "a_montrer": ["flamme", "souffle d'oxygène", "réaction CH4 + O2 -> CO2 + H2O", "arbre"] }
  ]
}

(« foyer », « flux » et « plan » s'ajoutent quand le décor les demande.)

════════ L'AMBIANCE DE LA CAPSULE ════════

Une seule pour toute la capsule : la couleur et le lointain qui situent le cours.
   nuit     bleu nuit, sans lointain — le corps humain, la santé, la technologie,
            l'électricité, l'informatique
   savane   ambre du soir, baobabs et soleil couchant — l'histoire, la géographie,
            la société, l'économie, le Burkina et l'Afrique, l'eau et le climat
   foret    vert, lisière d'arbres — le vivant : plantes, animaux, écologie,
            agriculture, alimentation
   cosmos   violet, étoiles et planète — la physique, la chimie, l'astronomie,
            l'énergie
   ardoise  gris craie — les mathématiques, la logique, les langues
Choisis d'après la MATIÈRE du sujet ; en cas de doute, nuit.

════════ CE QUI FAIT UN BON COURS ════════

• 4 à 6 scènes, du simple au complexe, UNE idée par scène. Une accroche concrète
  au début, l'essentiel à retenir à la fin.
• Budget de parole : 250 mots au total. La voix commande la durée.
• « a_montrer » : 2 à 5 éléments CONCRETS, pris dans CE QUE DIT LA NARRATION de la
  scène, et que le moteur sait montrer (liste ci-dessus). Pour une réaction, écris
  « réaction » suivie de l'équation sans coefficients. Un objet réel : son terme
  exact de la liste.
• Deux scènes ne montrent jamais la même chose : change l'objet, le phénomène ou
  l'échelle.
• Une idée abstraite se montre par une métaphore visuelle, ou par le mot écrit.`;

// ── Couche 2 : l'illustrateur ────────────────────────────────────────────────
export const CONSIGNE_ILLUSTRATEUR = `Tu es l'ILLUSTRATEUR d'une capsule vidéo 3D pédagogique. On te donne UNE scène
déjà écrite : sa narration, son intention, son décor et la liste de ce qu'il faut
montrer. Tu la FABRIQUES avec les gestes ci-dessous, en coordonnées. Le moteur
exécute ta description telle quelle.

` + SECTION_GESTES + SECTION_LIMITES + SECTION_EXEMPLES + `
════════ CE QUE TU RENDS ════════

UNIQUEMENT ce JSON : { "gestes": [ { "verbe": "...", "role": "sujet", "parametres": { ... } } ] }

• Montre CHAQUE élément de « a_montrer », avec le geste le plus juste.
• 2 à 5 gestes. En décor corps : pas de « convoquer », au plus un mot (ecrire).
  En décor gouttes : 0 à 2 gestes.
• Ne recopie pas les autres scènes du cours : elles te sont données pour que tu
  fasses AUTRE CHOSE.`;

const JSON_SUR = (texte: string): Record<string, unknown> => JSON.parse(stripCodeFences(texte));

function etape(couche: string, r: ResultatRole, scene?: string): Etape {
  return { couche, scene, model: r.model, ms: r.ms, coutUsd: r.coutUsd, jetonsSortie: r.jetonsSortie, essais: r.essais };
}

async function illustrer(appeler: Appeler, s: Record<string, unknown>, autres: string[], defauts: string[] = []) {
  const demande = {
    scene: { id: s.id, decor: s.decor, foyer: s.foyer, intention: s.intention, sujet: s.sujet, narration: s.narration, a_montrer: s.a_montrer },
    autres_scenes_du_cours: autres,
    ...(defauts.length ? { defauts_a_corriger: defauts } : {}),
  };
  const r = await appeler("illustrateur", [
    { role: "system", content: CONSIGNE_ILLUSTRATEUR },
    { role: "user", content: JSON.stringify(demande) },
  ], 4000);
  const gestes = JSON_SUR(r.content).gestes;
  return { gestes: Array.isArray(gestes) ? gestes : [], r };
}

// ── Couche 3 : le contrôleur (du code) ──────────────────────────────────────
/** Les défauts de chaque scène, lus dans les corrections de la validation et dans
 *  la capsule elle-même. Une scène sans défaut n'est pas reprise. */
export function defautsParScene(capsule: Record<string, unknown>, corrections: string[]): Map<string, string[]> {
  const out = new Map<string, string[]>();
  const noter = (id: string, d: string) => out.set(id, [...(out.get(id) || []), d]);
  for (const c of corrections) {
    const m = c.match(/^(s\d+)[.:]/);
    if (!m) continue;
    if (/aucun geste exploitable|hors bibliotheque|reaction .* (ecartee|illisible)|verbe inconnu|image identique|sans « de »|illisible, ecartee/.test(c)) noter(m[1], c);
  }
  for (const s of (capsule.scenes as Record<string, unknown>[]) ?? []) {
    const gestes = ((s.gestes as Record<string, unknown>[]) ?? []).filter((g) => g.pour !== "pod");
    if (s.decor === "gestes" && gestes.length < 2) noter(String(s.id), `${s.id}: seulement ${gestes.length} geste(s), il en faut 2 à 5`);
  }
  return out;
}

/** La chaîne complète. `appeler` est injectable : les tests la jouent sans réseau. */
export async function genererCapsuleEnCouches(sujet: string, appeler: Appeler) {
  const etapes: Etape[] = [];
  // 1. Le scénariste.
  const r1 = await appeler("scenariste", [
    { role: "system", content: CONSIGNE_SCENARISTE },
    { role: "user", content: `Sujet : "${sujet}"` },
  ], 6000);
  etapes.push(etape("scenariste", r1));
  const plan = JSON_SUR(r1.content);
  const scenes = (Array.isArray(plan.scenes) ? plan.scenes : []).slice(0, 6) as Record<string, unknown>[];
  if (!scenes.length) throw new Error("le scénariste n'a rendu aucune scène");
  scenes.forEach((s, i) => { s.id = String(s.id || `s${i + 1}`); });
  const resume = (s: Record<string, unknown>) => `${s.id} : ${s.sujet} — montre ${(s.a_montrer as string[] | undefined)?.join(", ") || "?"}`;

  // 2. L'illustrateur, toutes les scènes en parallèle. Un échec d'une scène ne
  //    perd pas le cours : la scène part sans geste et la validation écrit son sujet.
  const faites = await Promise.all(scenes.map(async (s) => {
    try {
      const { gestes, r } = await illustrer(appeler, s, scenes.filter((x) => x !== s).map(resume));
      etapes.push(etape("illustrateur", r, String(s.id)));
      return gestes;
    } catch (e) {
      etapes.push({ couche: "illustrateur", scene: String(s.id), model: "—", ms: 0, coutUsd: 0, jetonsSortie: 0, essais: [(e as Error).message.slice(0, 160)] });
      return [];
    }
  }));
  const brut: { titre: unknown; ambiance: unknown; scenes: Record<string, unknown>[] } =
    { titre: plan.titre, ambiance: plan.ambiance, scenes: scenes.map((s, i) => ({ ...s, gestes: faites[i] })) };

  // 3. Le contrôleur : valider, puis reprendre UNE fois les scènes en défaut.
  let vc = validateCapsule(brut);
  const reprises: string[] = [];
  if (vc.valid) {
    const defauts = defautsParScene(vc.capsule!, vc.corrections);
    if (defauts.size) {
      await Promise.all([...defauts.entries()].map(async ([id, liste]) => {
        const i = brut.scenes.findIndex((s) => s.id === id);
        if (i < 0) return;
        try {
          const { gestes, r } = await illustrer(appeler, brut.scenes[i], brut.scenes.filter((_, k) => k !== i).map(resume), liste);
          etapes.push(etape("reprise", r, id));
          if (gestes.length) { brut.scenes[i] = { ...brut.scenes[i], gestes }; reprises.push(id); }
        } catch { /* la scène garde sa première version */ }
      }));
      if (reprises.length) vc = validateCapsule(brut);
    }
  }
  return { vc, brut, etapes, reprises };
}

/** L'appel réel, par métier. `roles` et `reglages` remplacent modèles, effort de
 *  raisonnement et budget de sortie sans redéploiement (banc). */
export const appelerReel = (roles?: Partial<Record<Role, string[]>>, reglages?: Partial<Record<Role, Reglages>>): Appeler =>
  (role, msgs, maxTok) => appelerRole(role, msgs, maxTok, roles, 0.35, reglages?.[role]);
