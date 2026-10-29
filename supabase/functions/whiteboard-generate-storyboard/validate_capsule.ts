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

import { equilibrer, lireEquation, lireEspece } from "./chimie.ts";

export const INTENTIONS = [
  "objet", "processus", "comparaison", "structure", "echelle", "flux",
] as const;

export const VERBES = [
  // `convoquer` fait venir un objet REEL du sujet depuis l'index verifie du
  // Studio, au lieu de le dessiner. Ajoute le 05/09/2026 apres la capsule
  // « le volcan » : la narration disait « chambre magmatique » puis « cone
  // volcanique », et les trois scenes montraient la meme lentille aplatie.
  // Les six autres verbes fabriquent depuis des coordonnees — aucun modele ne
  // dessine un volcan point par point, alors il rend une forme neutre.
  "convoquer",
  "silhouetter", "revolutionner", "extruder", "sculpter", "napper", "ecrire",
  // PHENOMENES ET ACCESSOIRES (28/10/2026). Le cours « le feu » (travail
  // 818a6e6e) ne montrait ni flamme, ni air, ni combustible : aucun verbe ne
  // savait faire BOUGER quelque chose. Ceux-ci sont des equations du lecteur
  // (lecteur.js, PHENOMENES et ACCESSOIRES) — aucun fichier, aucune licence.
  "flamme", "ecoulement", "pluie", "souffle", "foudre",
  "fleche", "etiquette", "molecule",
  // CHIMIE CALCULÉE (lot B2, 29/10/2026) : l'IA écrit la réaction, chimie.ts en
  // calcule les coefficients. Voir docs/STUDIO_3D_VOCABULAIRE_UNIVERSEL_2026-10-29.md.
  "reaction",
] as const;

// VALEUR COUPLEE avec MOLECULES de lecteur.js et la liste de prompt_capsule.ts :
// une formule absente ici serait ecartee, absente du lecteur elle ne s'afficherait pas.
export const MOLECULES = ["H2", "O2", "N2", "CO", "CO2", "H2O", "CH4", "NH3", "NaCl"] as const;
const COULEURS_SOUFFLE = ["bleu", "blanc", "rouge"] as const;

// LES 69 TERMES DE `convoquer` (29/10/2026). VALEUR COUPLEE avec
// contours/index_objets.json et la liste ecrite dans prompt_capsule.ts :
// validate_capsule_termes_test.ts compare les trois. Avant elle, une capsule
// « le feu » demandant « bois » passait avec ZERO correction, et l'objet
// manquait a l'image sans que personne ne l'ait dit.
export const TERMES_OBJETS = [
  "adn", "aimant", "arbre", "atome", "bacterie", "balance", "barrage", "cellule",
  "cerveau", "charrue", "chateau", "circuit", "coeur", "corps humain", "crane",
  "cristal", "dent", "engrenage", "eolienne", "estomac", "feuille", "fleur",
  "foie", "fruit", "germination", "globe", "goutte", "graine", "insecte",
  "livre", "maison", "microscope", "molecule", "montagne", "muscle", "neurone",
  "nuage", "oeil", "oiseau", "os", "outil", "panneau solaire", "parchemin",
  "peau", "pendule", "piece", "pile", "planete", "plante", "poisson", "pont",
  "poumon", "prisme", "puits", "pyramide", "racine", "rein", "ressort",
  "riviere", "roche", "sang", "squelette", "statue", "temple", "thermometre",
  "tracteur", "vase", "virus", "volcan",
] as const;

/** « Le Cœur », « rivière », « l'atome » -> l'écriture de l'index. */
function termeCanonique(brut: string): string {
  return brut.toLowerCase().replace(/œ/g, "oe").normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/^(le|la|les|un|une|des)\s+|^l['’]\s*/, "").replace(/\s+/g, " ").trim();
}

const BASES = ["ovoide", "sphere", "galet", "goutte", "lentille"] as const;

// LES AMBIANCES (29/10/2026). VALEUR COUPLÉE avec AMBIANCES de lecteur.js, qui
// les dessine : couleur de toute la capsule et lointain (savane, lisière, ciel).
// `papier` existe dans le lecteur mais n'est pas proposé : son rendu n'est pas
// prêt (halo inversé en taches, planche docs/captures_ambiances_2026-10-29/).
export const AMBIANCES = ["nuit", "savane", "foret", "cosmos", "ardoise"] as const;

// ── Décors (capsule v2, 28/10/2026) ─────────────────────────────────────
// Le lecteur sur l'appareil (studio_visuel/lecteur/) sait jouer deux décors
// tout faits : un CORPS allongé avec un foyer, et des GOUTTES sur une grille.
// L'IA choisit ; on nettoie, on ne rejette pas.
//
// COMPATIBILITÉ AVEC LE POD. La chaîne GPU actuelle ignore `decor` et ne
// dessine que des gestes. Une scène « corps » ou « gouttes » sans geste y
// serait VIDE — donc on lui ajoute des gestes de repli marqués `pour: "pod"`,
// que le lecteur, lui, ignore. Les deux chaînes restent servies par la même capsule.
export const DECORS = ["gestes", "corps", "gouttes"] as const;
export const ZONES = ["tete", "thorax", "ventre", "bassin", "jambes", "bras"] as const;
const ORGANES: Record<string, string> = {
  cerveau: "tete", crane: "tete", oeil: "tete", yeux: "tete", oreille: "tete", bouche: "tete", dent: "tete", nez: "tete",
  coeur: "thorax", poumon: "thorax", poumons: "thorax", poitrine: "thorax", peau: "thorax", sang: "thorax",
  estomac: "ventre", foie: "ventre", intestin: "ventre", intestins: "ventre", rein: "ventre", reins: "ventre", pancreas: "ventre",
  vessie: "bassin", uterus: "bassin", hanche: "bassin",
  jambe: "jambes", genou: "jambes", pied: "jambes", pieds: "jambes",
  main: "bras", mains: "bras", doigt: "bras", doigts: "bras", coude: "bras",
};
const PLANS: Record<string, readonly string[]> = {
  corps: ["approche", "profil", "reference"],
  gouttes: ["rase", "arc"],
};
const REPLI_POD: Record<string, Record<string, unknown>[]> = {
  corps: [
    { verbe: "convoquer", role: "sujet", pour: "pod",
      parametres: { terme: "corps humain", taille: 4, position: [0, 0, 0] } },
  ],
  gouttes: [
    { verbe: "napper", role: "structure", pour: "pod", parametres: { cote: 60, pas: 46, amplitude: 0.8 } },
    { verbe: "sculpter", role: "sujet", pour: "pod",
      parametres: { base: "goutte", echelle: 0.9, facettes: 2, position: [-2, 0, 0.6], deformation: 0, graine: 1 } },
    { verbe: "sculpter", role: "sujet", pour: "pod",
      parametres: { base: "goutte", echelle: 1.2, facettes: 2, position: [0, -1, 0.8], deformation: 0, graine: 2 } },
    { verbe: "sculpter", role: "sujet", pour: "pod",
      parametres: { base: "goutte", echelle: 0.8, facettes: 2, position: [2.2, 0, 0.5], deformation: 0, graine: 3 } },
  ],
};

/** Le décor d'une scène, nettoyé. Chaque écart est NOMMÉ dans `corr`. */
function validerDecor(s: Record<string, unknown>, id: string, corrections: string[]) {
  let decor = String(s.decor ?? "gestes").trim() || "gestes";
  if (!(DECORS as readonly string[]).includes(decor)) {
    corrections.push(`${id}: decor « ${decor} » inconnu, ramene a gestes`);
    decor = "gestes";
  }
  const brut = s.foyer == null ? "" : String(s.foyer).trim();
  let foyer: string | null = null;
  if (decor === "corps") {
    // Le modèle nomme parfois l'ORGANE au lieu de la zone (mesuré le 28/10 :
    // « foie », « poumon », « peau ») : on le range dans sa zone plutôt qu'au thorax.
    const zone = (ZONES as readonly string[]).includes(brut) ? brut : ORGANES[brut.toLowerCase()];
    foyer = zone ?? "thorax";
    if (brut && foyer !== brut) corrections.push(`${id}: foyer « ${brut} » ramene a ${foyer}`);
  } else if (decor === "gestes") {
    // L'énergie a besoin d'un référent : seul « sujet » est admis hors du corps.
    if (brut === "sujet") foyer = "sujet";
    else if (brut) corrections.push(`${id}: foyer « ${brut} » ignore hors du decor corps`);
  } else if (brut) {
    corrections.push(`${id}: foyer ignore en decor gouttes`);
  }
  const flux = s.flux === true || s.flux === "true";
  let plan = String(s.plan ?? "").trim();
  if (plan && !(PLANS[decor] ?? []).includes(plan)) {
    corrections.push(`${id}: plan « ${plan} » inconnu pour le decor ${decor}, ignore`);
    plan = "";
  }
  return { decor, foyer, flux, plan };
}

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

  if (verbe === "convoquer") {
    // Un seul parametre compte : le TERME. C'est un nom d'objet en francais
    // (« volcan », « cerveau », « graine »), que le moteur cherche dans son
    // index. On nettoie sans juger : le moteur sait deja repondre « aucun
    // objet connu » et retomber sur une forme geometrique, ce qui vaut mieux
    // qu'un refus ici — rejeter ferait perdre a l'etudiant ses credits ET sa
    // video.
    const terme = String(pIn.terme ?? pIn.nom ?? "").trim().slice(0, 60);
    if (!terme) {
      corr.push(`${id}.g${rang}: convoquer sans terme, geste ecarte`);
      return null;
    }
    // Ecriture ramenee a celle de l'index ; un terme absent est GARDE (le
    // moteur retombe sur une forme, le lecteur montre le reste de la scene)
    // mais NOMME : l'objet ne viendra pas.
    const canon = termeCanonique(terme);
    if ((TERMES_OBJETS as readonly string[]).includes(canon)) {
      p.terme = canon;
    } else {
      p.terme = terme;
      corr.push(`${id}.g${rang}: objet « ${terme} » hors bibliotheque (69 termes), il ne s'affichera pas`);
    }
    const taille = Number(pIn.taille);
    p.taille = Number.isFinite(taille) && taille > 0.2 && taille < 12
      ? taille : 2.0;
    const pos = point3(pIn.position);
    if (pos) p.position = pos;
    return { verbe, role, parametres: p };
  }

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

  } else if (verbe === "flamme") {
    p.taille = borner(nombre(pIn.taille, 1.2), 0.3, 6);
    p.position = point3(pIn.position) ?? [0, 0, 0];

  } else if (verbe === "ecoulement") {
    const chemin: [number, number, number][] = [];
    for (const pt of (Array.isArray(pIn.chemin) ? pIn.chemin : [])) {
      const q = point3(pt);
      if (q && chemin.length < 12) chemin.push(q);
    }
    if (chemin.length < 2) {
      // Pas de lit trace : un cours d'eau droit, plutot qu'aucune eau.
      corr.push(`${id}.g${rang}: ecoulement sans chemin, lit droit par defaut`);
      chemin.splice(0, chemin.length, [-3, 0, 0], [0, 0.5, 0], [3, 0, 0]);
    }
    p.chemin = chemin;
    p.largeur = borner(nombre(pIn.largeur, 0.7), 0.1, 3);
    p.cailloux = pIn.cailloux !== false;

  } else if (verbe === "pluie") {
    const z = point2(pIn.zone);
    p.zone = z ? [borner(Math.abs(z[0]), 1, 12), borner(Math.abs(z[1]), 1, 12)] : [6, 4];
    p.hauteur = borner(nombre(pIn.hauteur, 4), 1, 10);
    p.intensite = borner(nombre(pIn.intensite, 1), 0.2, 2);
    p.position = point3(pIn.position) ?? [0, 0, 0];

  } else if (verbe === "souffle" || verbe === "foudre" || verbe === "fleche") {
    // Trois verbes tendus d'un point a un autre.
    const de = point3(pIn.de), vers = point3(pIn.vers);
    if (!de || !vers) {
      corr.push(`${id}.g${rang}: ${verbe} sans « de » et « vers », ecarte`);
      return null;
    }
    p.de = de; p.vers = vers;
    if (verbe === "souffle") {
      const c = String(pIn.couleur ?? "bleu");
      p.couleur = (COULEURS_SOUFFLE as readonly string[]).includes(c) ? c : "bleu";
    }
    const texte = String(pIn.texte ?? "").trim();
    if (texte && verbe !== "foudre") p.texte = texte.slice(0, 30);

  } else if (verbe === "etiquette") {
    const texte = String(pIn.texte ?? "").trim();
    if (!texte) {
      corr.push(`${id}.g${rang}: etiquette sans texte, ecartee`);
      return null;
    }
    p.texte = texte.slice(0, 30);
    p.cible = point3(pIn.cible) ?? [0, 0, 0];
    p.cote = pIn.cote === "gauche" ? "gauche" : "droite";

  } else if (verbe === "molecule") {
    // « O₂ », « o2 », « H2 O » : on ramene a l'ecriture du lecteur. Hors des neuf
    // qu'il dessine de memoire, toute formule LISIBLE est admise (lot B2) : sa vraie
    // geometrie vient de PubChem apres la validation (chimie.ts, resoudreChimie).
    const brute = String(pIn.formule ?? "").replace(/[₀-₉]/g, (c) => String(c.charCodeAt(0) - 8320)).replace(/\s/g, "");
    const nom = String(pIn.nom ?? "").trim().slice(0, 40);
    let formule: string | undefined = MOLECULES.find((m) => m.toLowerCase() === brute.toLowerCase());
    if (!formule && brute) {
      try { formule = lireEspece(brute).formule; } catch { formule = undefined; }
    }
    if (!formule && !nom) {
      corr.push(`${id}.g${rang}: molecule « ${brute || "absente"} » illisible, ecartee`);
      return null;
    }
    if (formule) p.formule = formule;
    if (nom) p.nom = nom;
    p.taille = borner(nombre(pIn.taille, 1.4), 0.3, 6);
    p.position = point3(pIn.position) ?? [0, 0, 0];

  } else if (verbe === "reaction") {
    // ON N'AFFICHE JAMAIS UNE EQUATION FAUSSE. Les coefficients du modele sont
    // ignores ; s'il n'existe pas d'equilibre unique, la reaction est ecartee.
    const texte = String(pIn.equation ?? "").trim().slice(0, 160);
    try {
      const { reactifs, produits, reversible } = lireEquation(texte);
      const r = equilibrer(reactifs, produits);
      if ("erreur" in r) {
        corr.push(`${id}.g${rang}: reaction « ${texte} » ecartee : ${r.erreur}`);
        return null;
      }
      p.especes = [...reactifs.map((e) => ({ ...e, cote: "reactif" })), ...produits.map((e) => ({ ...e, cote: "produit" }))]
        .map((e, i) => {
          const o: Record<string, unknown> = { formule: e.formule, atomes: e.atomes, charge: e.charge, cote: e.cote, coef: r.coefficients[i] };
          if (e.etat) o.etat = e.etat;
          return o;
        });
      p.reversible = reversible;
    } catch (e) {
      corr.push(`${id}.g${rang}: reaction « ${texte || "absente"} » illisible (${(e as Error).message}), ecartee`);
      return null;
    }
    // Les noms (en anglais) que le modele donne aux especes : pour aller chercher
    // la bonne molecule, pas un isomere de meme formule.
    if (pIn.noms && typeof pIn.noms === "object") {
      const noms: Record<string, string> = {};
      for (const [f, n] of Object.entries(pIn.noms as Record<string, unknown>).slice(0, 6)) {
        try { noms[lireEspece(f).formule] = String(n).trim().slice(0, 40); } catch { /* formule illisible : ignoree */ }
      }
      if (Object.keys(noms).length) p.noms = noms;
    }
    p.taille = borner(nombre(pIn.taille, 1.0), 0.5, 2.5);
    p.position = point3(pIn.position) ?? [0, 0, 1.6];
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
    const { decor, foyer, flux, plan } = validerDecor(s, id, corrections);
    if (decor === "corps") {
      // Un organe convoqué en décor corps se poserait PAR-DESSUS le corps : le
      // foyer le montre déjà. Mesuré le 28/10 : 21 scènes sur 35 le faisaient.
      const avant = gestes.length;
      for (let k = gestes.length - 1; k >= 0; k--) if (gestes[k].verbe === "convoquer") gestes.splice(k, 1);
      if (gestes.length < avant) corrections.push(`${id}: ${avant - gestes.length} objet(s) convoque(s) retire(s) du decor corps, le foyer le montre`);
    }

    if (!gestes.length && decor !== "gestes") {
      // Le décor montre déjà le sujet sur l'appareil ; le pod, lui, a besoin
      // de gestes. Repli marqué, ignoré par le lecteur — pas une correction.
      if (!sujet && !narration) {
        corr(corrections, `${id}: scene vide, ecartee`);
        continue;
      }
      gestes.push(...REPLI_POD[decor].map((g) => structuredClone(g)));
    } else if (!gestes.length) {
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

    const scene: Record<string, unknown> = {
      id, intention, sujet, narration, gestes,
      duree_s: borner(nombre(s.duree_s, 12), MIN_DUREE, MAX_DUREE),
      decor,
    };
    if (foyer) scene.foyer = foyer;
    if (flux) scene.flux = true;
    if (plan) scene.plan = plan;
    scenes.push(scene);
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
      ambiance: ambianceDe(src.ambiance, corrections),
      format: { largeur: 1080, hauteur: 1920, fps: 25 },
      scenes,
      corrections,
    },
    corrections,
  };
}

/** L'ambiance de la capsule : absente -> `nuit` en silence (le rendu d'origine) ;
 *  inconnue -> `nuit`, et c'est dit. */
function ambianceDe(brut: unknown, corrections: string[]): string {
  const a = String(brut ?? "").trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
  if (!a) return "nuit";
  if ((AMBIANCES as readonly string[]).includes(a)) return a;
  corrections.push(`ambiance « ${String(brut).slice(0, 30)} » inconnue, ramenee a nuit`);
  return "nuit";
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
  // Les gestes de repli du pod ne font pas l'image sur l'appareil : on les ôte,
  // et c'est le décor (avec son foyer et son cadrage) qui la fait.
  const gestes = ((scene.gestes as Record<string, unknown>[]) ?? []).filter((g) => g.pour !== "pod");
  const decor = scene.decor && scene.decor !== "gestes"
    ? `${scene.decor}:${scene.foyer ?? ""}:${scene.plan || scene.intention}|` : "";
  return decor + gestes.map((g) => {
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
