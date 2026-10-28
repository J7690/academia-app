// La logique pure de studio-voix, testable sans serveur ni réseau (voix_test.ts).

export const MAX_CARACTERES = 1200;      // la limite de whiteboard-tts, gardée identique
export const PARALLELE_MAX = 8;          // au-delà, on attend : une capsule a 4 à 6 scènes

export interface SceneAVoixer { rang: number; id: string; texte: string; }

/** La capsule d'un manifeste. En base, `studio_creer_travail_etudiant` la range
 *  sous `storyboard`, à côté de `discipline` et `project_id` ; l'appel interne
 *  peut la passer telle quelle. Mesuré le 28/10 sur le travail 54da352d : lire
 *  `manifeste.scenes` donnait 0 scène, donc « aucune narration ». */
export function capsuleDuManifeste(manifeste: unknown): { scenes?: unknown[] } | null {
  const m = manifeste as { storyboard?: unknown; scenes?: unknown } | null;
  if (m && typeof m.storyboard === 'object' && m.storyboard !== null) return m.storyboard as { scenes?: unknown[] };
  return (m as { scenes?: unknown[] }) ?? null;
}

/** Les scènes qui ont quelque chose à dire, dans l'ordre. Une scène sans
 *  narration n'est pas une erreur : elle sera jouée en silence, et le lecteur le dit. */
export function scenesAVoixer(manifeste: unknown): SceneAVoixer[] {
  const scenes = capsuleDuManifeste(manifeste)?.scenes;
  if (!Array.isArray(scenes)) return [];
  const out: SceneAVoixer[] = [];
  scenes.forEach((s, rang) => {
    const sc = s as { id?: unknown; narration?: unknown };
    const texte = typeof sc?.narration === 'string' ? sc.narration.trim() : '';
    if (!texte) return;
    const id = typeof sc.id === 'string' && /^[A-Za-z0-9_-]{1,40}$/.test(sc.id) ? sc.id : `s${rang + 1}`;
    out.push({ rang, id, texte: texte.slice(0, MAX_CARACTERES) });
  });
  return out;
}

/** Le chemin d'une voix dans le bucket. Sous `capsules/` : c'est la seule
 *  racine que la politique d'écriture du bucket studio-visuel accepte
 *  (ETAT §4.7 — trois semaines de refus perdus pour l'avoir ignoré). */
export function cheminVoix(jobId: string, sceneId: string): string {
  if (!/^[0-9a-f-]{36}$/i.test(jobId)) throw new Error('job_id invalide');
  if (!/^[A-Za-z0-9_-]{1,40}$/.test(sceneId)) throw new Error('scene_id invalide');
  return `capsules/voix/${jobId.toLowerCase()}/${sceneId}.mp3`;
}

/** Exécute `travail` sur chaque élément, au plus `max` à la fois, et rend la
 *  main à `chaque` dès qu'un élément aboutit — dans l'ordre d'ARRIVÉE, pas de
 *  départ : c'est ce qui permet au lecteur de jouer la scène 1 sans attendre la 5. */
export async function enParallele<T, R>(
  elements: T[], max: number, travail: (e: T) => Promise<R>, chaque: (e: T, r: R) => void,
): Promise<void> {
  let suivant = 0;
  const ouvrier = async () => {
    while (suivant < elements.length) {
      const e = elements[suivant++];
      chaque(e, await travail(e));
    }
  };
  await Promise.all(Array.from({ length: Math.min(max, elements.length) }, ouvrier));
}
