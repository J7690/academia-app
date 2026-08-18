// Validation d'une capsule 3D DECRITE — on nettoie, on ne remplace plus.
//
// CE QUI CHANGE, ET C'ETAIT LA PIECE MAITRESSE DU DEFAUT.
// La version precedente contenait :
//
//     if (!ARCHETYPES.includes(archetype)) {
//       corrections.push(`${id}:archetype_${archetype}_remplace_par_reseau`);
//
// Toute forme qu'elle ne connaissait pas devenait `reseau`. Meme si le modele
// avait propose une forme adaptee au sujet, elle etait remplacee AVANT que le
// moteur ne la voie. C'est la cause mecanique, verifiee le 12/08, du fait que
// « la sociologie » et « la germination » donnaient la meme video.
//
// Desormais on valide une COMPOSITION : chaque geste nomme un verbe et porte
// des coordonnees. On corrige ce qui est corrigeable -- une coordonnee hors
// bornes, une valeur manquante -- et on ECARTE ce qui ne l'est pas, en le
// disant. On ne substitue jamais une forme a une autre.
//
// LA CONTRAINTE DU PROJET RESTE : « on nettoie, on ne rejette pas ». Rejeter
// ferait perdre a l'etudiant ses credits ET sa video. Mais nettoyer n'a jamais
// voulu dire se taire : chaque correction est nommee et remonte avec la capsule.

export const INTENTIONS = [
  "objet", "processus", "comparaison", "structure", "echelle", "flux",
] as const;

export const VERBES = [
  "silhouetter", "revolutionner", "extruder", "sculpter", "napper", "ecrire",
] as const;

const BASES = ["ovoide", "sphere", "galet", "goutte", "lentille"] as const;

const MAX_SCENES = 6;
const MAX_GESTES = 8;
const MIN_DUREE = 4;
const MAX_DUREE = 25;
// 120 s ET NON 150. A 150, l'ecretage etait du CODE MORT : six scenes au
// maximum, vingt-cinq secondes chacune, le total plafonnait deja a 150 par
// construction. La borne ne pouvait donc jamais se declencher -- defaut trouve
// par le test le 12/08, qui l'a exige et ne l'a jamais vue agir.
// L'invite vise 60 a 110 secondes ; 120 laisse une marge sans laisser passer
// une capsule de deux minimum et demie que personne ne regardera jusqu'au bout.
const MAX_TOTAL_S = 120;
const BORNE = 12;          // au-dela, l'objet sort du cadre
const MAX_POINTS = 120;    // un squelette plus long est illisible et lent

type Resultat = {
  valid: boolean;
  capsule?: Record<string, unknown>;
  error?: string;
  corrections: string[];
};

const nombre = (v: unknown, defaut: number): number => {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : defaut;
};

const borner = (n: number, min: number, max: number) =>
  Math.min(max, Math.max(min, n));

/** Un point [x,y,z] borne. Rend null si irrecuperable. */
function point3(v: unknown): [number, number, number] | null {
  if (!Array.isArray(v) || v.length < 3) return null;
  const p: number[] = [];
  for (let i = 0; i < 3; i++) {
    const n = Number(v[i]);
    if (!Number.isFinite(n)) return null;
    p.push(borner(n, -BORNE * 4, BORNE * 4));
  }
  return [p[0], p[1], p[2]];
}

function point2(v: unknown): [number, number] | null {
  if (!Array.isArray(v) || v.length < 2) return null;
  const a = Number(v[0]), b = Number(v[1]);
  if (!Number.isFinite(a) || !Number.isFinite(b)) return null;
  return [borner(a, -BORNE * 4, BORNE * 4), borner(b, -BORNE * 4, BORNE * 4)];
}

/** Valide UN geste. Rend null s'il est inexploitable — et dit pourquoi. */
function validerGeste(brut: unknown, id: string, rang: number,
                      corr: string[]): Record<string, unknown> | null {
  if (!brut || typeof brut !== "object") {
    corr.push(`${id}.g${rang}: geste illisible, ecarte`);
    return null;
  }
  const g = brut as Record<string, unknown>;
  const verbe = String(g.verbe ?? "").trim();

  if (!(VERBES as readonly string[]).includes(verbe)) {
    // ON N'INVENTE PAS DE REMPLACANT. Un verbe inconnu est un geste qu'on ne
    // sait pas faire ; le dire vaut mieux que de dessiner autre chose.
    corr.push(`${id}.g${rang}: verbe inconnu « ${verbe || "absent"} », geste ecarte`);
    return null;
  }

  const pIn = (g.parametres ?? {}) as Record<string, unknown>;
  const p: Record<string, unknown> = {};
  const role = g.role === "sujet" ? "sujet" : "structure";

  if (verbe === "silhouetter") {
    const brutSeg = Array.isArray(pIn.segments) ? pIn.segments : [];
    const chaines: [number, number, number][][] = [];
    let total = 0;
    for (const chaine of brutSeg) {
      if (!Array.isArray(chaine)) continue;
      const propre: [number, number, number][] = [];
      for (const pt of chaine) {
        const q = point3(pt);
        if (q && total < MAX_POINTS) { propre.push(q); total++; }
      }
      if (propre.length >= 2) chaines.push(propre);
      else if (propre.length === 1 && chaines.length) chaines.push(propre);
    }
    if (!chaines.length) {
      corr.push(`${id}.g${rang}: silhouetter sans squelette exploitable, ecarte`);
      return null;
    }
    p.segments = chaines;
    const rayons = Array.isArray(pIn.rayons)
      ? pIn.rayons.map((r) => borner(nombre(r, 0.3), 0.03, 2.0))
      : borner(nombre(pIn.rayons, 0.3), 0.03, 2.0);
    p.rayons = rayons;
    p.lisser = borner(Math.round(nombre(pIn.lisser, 1)), 0, 2);
    p.nom = String(pIn.nom ?? `forme_${rang}`).slice(0, 40);

  } else if (verbe === "revolutionner") {
    const profil: [number, number][] = [];
    for (const pt of (Array.isArray(pIn.profil) ? pIn.profil : [])) {
      const q = point2(pt);
      if (q) profil.push([Math.max(0, q[0]), q[1]]);   // rayon jamais negatif
    }
    if (profil.length < 2) {
      corr.push(`${id}.g${rang}: revolutionner avec ${profil.length} point(s), ecarte`);
      return null;
    }
    p.profil = profil.slice(0, MAX_POINTS);
    p.tours = borner(Math.round(nombre(pIn.tours, 40)), 8, 64);
    // `position` MANQUAIT ICI, et elle seule permet de poser deux objets de
    // revolution COTE A COTE. Le profil est [rayon, hauteur] : il exprime un
    // decalage vertical, jamais lateral. Sans elle, deux `revolutionner` d'une
    // meme scene naissaient tous deux a l'origine, exactement superposes --
    // donc une scene d'intention `comparaison` batie sur deux colonnes ou deux
    // recipients ne montrait qu'une seule masse au centre.
    // Le parametre existait deja en aval (composer_scene.py, academia3d.py) :
    // c'est le filtre qui le supprimait, et sans rien inscrire dans `corr`.
    p.position = point3(pIn.position) ?? [0, 0, 0];
    p.nom = String(pIn.nom ?? `revolution_${rang}`).slice(0, 40);

  } else if (verbe === "extruder") {
    const contour: [number, number][] = [];
    for (const pt of (Array.isArray(pIn.contour) ? pIn.contour : [])) {
      const q = point2(pt);
      if (q) contour.push(q);
    }
    if (contour.length < 3) {
      corr.push(`${id}.g${rang}: extruder avec ${contour.length} point(s), ecarte`);
      return null;
    }
    p.contour = contour.slice(0, MAX_POINTS);
    p.epaisseur = borner(nombre(pIn.epaisseur, 0.25), 0.02, 3.0);
    p.position = point3(pIn.position) ?? [0, 0, 0];
    p.nom = String(pIn.nom ?? `extrude_${rang}`).slice(0, 40);

  } else if (verbe === "sculpter") {
    let base = String(pIn.base ?? "ovoide");
    if (!(BASES as readonly string[]).includes(base)) {
      corr.push(`${id}.g${rang}: base « ${base} » inconnue, ramenee a ovoide`);
      base = "ovoide";
    }
    p.base = base;
    p.echelle = borner(nombre(pIn.echelle, 1.0), 0.1, 8.0);
    p.facettes = borner(Math.round(nombre(pIn.facettes, 1)), 1, 3);
    p.position = point3(pIn.position) ?? [0, 0, 0];
    p.deformation = borner(nombre(pIn.deformation, 0.0), 0, 0.35);
    p.graine = borner(Math.round(nombre(pIn.graine, rang)), 0, 9999);

  } else if (verbe === "napper") {
    p.cote = borner(nombre(pIn.cote, 190), 20, 260);
    p.pas = borner(Math.round(nombre(pIn.pas, 46)), 12, 80);
    p.amplitude = borner(nombre(pIn.amplitude, 1.8), 0, 5);

  } else if (verbe === "ecrire") {
    const texte = String(pIn.texte ?? "").trim();
    if (!texte) {
      corr.push(`${id}.g${rang}: ecrire sans texte, ecarte`);
      return null;
    }
    p.texte = texte.slice(0, 60);
    p.taille = borner(nombre(pIn.taille, 1.2), 0.4, 2.5);
    p.position = point3(pIn.position) ?? [0, 0, 0];
  }

  return { verbe, role, parametres: p };
}

export function validateCapsule(brut: unknown): Resultat {
  const corrections: string[] = [];
  if (!brut || typeof brut !== "object") {
    return { valid: false, error: "capsule illisible", corrections };
  }
  const src = brut as Record<string, unknown>;
  const scenesBrutes = Array.isArray(src.scenes) ? src.scenes : [];
  if (!scenesBrutes.length) {
    // REFUS EXPLICITE : sans scene il n'y a rien a rendre, et le credit doit
    // etre rembourse plutot que de facturer un vide.
    return { valid: false, error: "aucune scene", corrections };
  }

  const scenes: Record<string, unknown>[] = [];
  for (let i = 0; i < Math.min(scenesBrutes.length, MAX_SCENES); i++) {
    const s = (scenesBrutes[i] ?? {}) as Record<string, unknown>;
    const id = String(s.id ?? `s${i + 1}`);

    let intention = String(s.intention ?? "").trim();
    if (!(INTENTIONS as readonly string[]).includes(intention)) {
      corr(corrections, `${id}: intention « ${intention || "absente"} » inconnue, ramenee a objet`);
      intention = "objet";
    }

    const gestes: Record<string, unknown>[] = [];
    const brutGestes = Array.isArray(s.gestes) ? s.gestes : [];
    for (let g = 0; g < Math.min(brutGestes.length, MAX_GESTES); g++) {
      const propre = validerGeste(brutGestes[g], id, g, corrections);
      if (propre) gestes.push(propre);
    }

    const narration = String(s.narration ?? "").trim();
    const sujet = String(s.sujet ?? "").trim();

    if (!gestes.length) {
      // AUCUN GESTE N'A TENU. On ne remplace pas par une forme generique : on
      // ecrit le sujet. C'est la degradation, et elle est nommee.
      if (!sujet && !narration) {
        corr(corrections, `${id}: scene vide, ecartee`);
        continue;
      }
      gestes.push({
        verbe: "ecrire", role: "sujet",
        parametres: { texte: (sujet || narration).slice(0, 60), taille: 1.2,
                      position: [0, 0, 0] },
      });
      corr(corrections, `${id}: aucun geste exploitable, repli sur le texte`);
    }

    scenes.push({
      id, intention, sujet, narration, gestes,
      duree_s: borner(nombre(s.duree_s, 12), MIN_DUREE, MAX_DUREE),
    });
  }

  if (!scenes.length) {
    return { valid: false, error: "aucune scene exploitable", corrections };
  }

  // Ecretage proportionnel : la cible est un format court, 60 a 110 s.
  const total = scenes.reduce((t, s) => t + (s.duree_s as number), 0);
  if (total > MAX_TOTAL_S) {
    const f = MAX_TOTAL_S / total;
    for (const s of scenes) {
      s.duree_s = Math.max(MIN_DUREE, Math.round((s.duree_s as number) * f));
    }
    corr(corrections, `duree totale ${Math.round(total)}s ecretee a ${MAX_TOTAL_S}s`);
  }

  const muettes = scenes.filter((s) => !String(s.narration).trim()).length;
  if (muettes === scenes.length) {
    return { valid: false, error: "capsule entierement muette", corrections };
  }

  signalerRepetitions(scenes, corrections);

  return {
    valid: true,
    capsule: {
      titre: String(src.titre ?? "").slice(0, 120),
      format: { largeur: 1080, hauteur: 1920, fps: 25 },
      scenes,
      corrections,
    },
    corrections,
  };
}

function corr(liste: string[], message: string): void {
  liste.push(message);
}

/** L'empreinte d'une scene : ses gestes et leurs coordonnees, rien d'autre.
 *
 * On ignore deliberement `nom`, `role`, la narration et le sujet : deux scenes
 * qui montrent exactement la meme geometrie sont deux fois la meme image, meme
 * si la voix dit autre chose et meme si les objets ont ete rebaptises. C'est
 * l'IMAGE qu'on compare, pas l'intention.
 */
function empreinte(scene: Record<string, unknown>): string {
  const gestes = (scene.gestes as Record<string, unknown>[]) ?? [];
  return gestes.map((g) => {
    const p = { ...(g.parametres as Record<string, unknown> ?? {}) };
    delete p.nom;
    return `${g.verbe}(${JSON.stringify(p)})`;
  }).join("|");
}

/** NOMME les scenes qui refont la precedente. On ne rejette JAMAIS.
 *
 * POURQUOI. La validation examinait chaque scene isolement : une capsule dont
 * les six scenes portent les memes gestes aux memes coordonnees la traversait
 * avec `corrections.length === 0`.
 *
 * Mesure du 14/08, capsule « Poussee d'Archimede » livree : les scenes s1, s2
 * et s3 portaient le MEME profil de becher et la MEME sphere, aux memes
 * coordonnees. Trois plans interchangeables sur trois idees differentes, et pas
 * un mot pour le signaler.
 *
 * On ne corrige pas la geometrie a la place du modele -- inventer une forme
 * qu'il n'a pas decrite serait exactement le defaut qu'on a mis huit couches a
 * eliminer. On DIT, et la correction remonte jusqu'a l'etudiant.
 */
function signalerRepetitions(
  scenes: Record<string, unknown>[], corrections: string[],
): void {
  const vues = new Map<string, string>();
  for (const s of scenes) {
    const cle = empreinte(s);
    if (!cle) continue;
    const premiere = vues.get(cle);
    if (premiere) {
      corr(corrections,
        `${s.id}: image identique a ${premiere} (memes gestes, memes coordonnees)`);
    } else {
      vues.set(cle, String(s.id));
    }
  }
}
