// La chimie de la capsule — CALCULÉE, jamais dessinée par le modèle (29/10/2026).
//
// POURQUOI. Après l'essai « l'eau » sur le TECNO, Jocelyn : « je ne vois pas les
// équations chimiques qui s'écrivent, qui s'équilibrent ». La recherche externe
// (docs/STUDIO_3D_VOCABULAIRE_UNIVERSEL_2026-10-29.md, §3) tranche la manière :
// les modèles se trompent sur la chimie qu'ils écrivent ou dessinent (atomes mal
// reliés, substances mal étiquetées), au point que des chimistes demandent d'en
// interdire l'usage. Le modèle CHOISIT donc la réaction ; ce module en calcule les
// coefficients, exactement, et va chercher la vraie géométrie des molécules.
//
// L'ÉQUILIBRAGE : le noyau de la matrice « éléments × espèces ». En fractions
// exactes (BigInt) : la décomposition LU en flottants échoue sur ces matrices
// presque toujours déficientes en rang (méthode du noyau, cf. Nayuki, et le
// paquet Haskell `chemical-equation`). Une réaction n'est retenue que si son noyau
// est de dimension 1 — un seul équilibre possible — et tous ses coefficients du
// même signe. Sinon elle est écartée, et c'est dit : une équation fausse à l'écran
// enseigne une erreur.

const SYMBOLES = new Set((
  "H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn " +
  "Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce " +
  "Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn " +
  "Fr Ra Ac Th Pa U Np Pu"
).split(" "));

const INDICES: Record<string, string> = { "₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9" };
const EXPOSANTS: Record<string, string> = { "⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9", "⁺": "+", "⁻": "-" };

export type Espece = {
  formule: string;               // écriture ASCII sans coefficient ni état : « Ca(OH)2 », « SO4^2- »
  atomes: Record<string, number>;
  charge: number;
  etat?: string;                 // « aq », « s », « l », « g »
};

/** « H₂O », « Ca(OH)2 », « SO4^2- », « Fe^3+ », « H2O(l) » -> une espèce, ou une erreur dite. */
export function lireEspece(brut: string): Espece {
  let s = brut.trim()
    .replace(/[₀-₉]/g, (c) => INDICES[c])
    // ¹ ² ³ ne sont PAS dans la plage ⁰-⁹ d'Unicode : la classe les nomme un à un.
    .replace(/[⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻]+/g, (m) => "^" + [...m].map((c) => EXPOSANTS[c]).join(""))
    .replace(/\s+/g, "");
  let etat: string | undefined;
  const e = s.match(/\((aq|s|l|g)\)$/i);
  if (e) { etat = e[1].toLowerCase(); s = s.slice(0, -e[0].length); }
  // La charge : « ^2- », « ^+ », « ^3+ » (aussi « ^-2 »).
  let charge = 0;
  const c = s.match(/\^(\d*)([+-])$|\^([+-])(\d*)$/);
  if (c) {
    const n = Number(c[1] || c[4] || 1), signe = (c[2] || c[3]) === "-" ? -1 : 1;
    charge = signe * n; s = s.slice(0, -c[0].length);
  }
  if (!s) throw new Error(`espèce vide « ${brut} »`);
  const atomes: Record<string, number> = {};
  let i = 0;
  const groupe = (): Record<string, number> => {
    const g: Record<string, number> = {};
    while (i < s.length && s[i] !== ")" && s[i] !== "]") {
      let part: Record<string, number>;
      if (s[i] === "(" || s[i] === "[") {
        i++; part = groupe();
        if (s[i] !== ")" && s[i] !== "]") throw new Error(`parenthèse non fermée dans « ${brut} »`);
        i++;
      } else {
        const m = s.slice(i).match(/^[A-Z][a-z]?/);
        if (!m || !SYMBOLES.has(m[0])) throw new Error(`élément inconnu dans « ${brut} » à « ${s.slice(i, i + 3)} »`);
        i += m[0].length; part = { [m[0]]: 1 };
      }
      const n = s.slice(i).match(/^\d+/);
      const k = n ? Number(n[0]) : 1; if (n) i += n[0].length;
      for (const [el, q] of Object.entries(part)) g[el] = (g[el] || 0) + q * k;
    }
    return g;
  };
  Object.assign(atomes, groupe());
  if (i !== s.length) throw new Error(`caractère inattendu dans « ${brut} »`);
  return { formule: s + (charge ? `^${Math.abs(charge) > 1 ? Math.abs(charge) : ""}${charge > 0 ? "+" : "-"}` : ""), atomes, charge, etat };
}

const FLECHES = /\s*(?:<=>|<->|⇌|⟶|→|->|=>|=)\s*/;

/** « 2 H2 + O2 -> 2 H2O » -> réactifs et produits. Les coefficients écrits par le
 *  modèle sont IGNORÉS : c'est le calcul qui les fixe. */
export function lireEquation(brut: string): { reactifs: Espece[]; produits: Espece[]; reversible: boolean } {
  const texte = String(brut || "").trim();
  const cotes = texte.split(FLECHES);
  if (cotes.length !== 2) throw new Error("l'équation doit avoir une flèche et une seule");
  const reversible = /<=>|<->|⇌/.test(texte);
  // Le « + » sépare les espèces quand il est entouré d'espaces ; collé, c'est une charge.
  const especes = (cote: string) => cote.split(/\s+\+\s+/).map((x) => x.trim()).filter(Boolean)
    .map((x) => lireEspece(x.replace(/^\d+\s*(?=[A-Z(\[])/, "")));
  const reactifs = especes(cotes[0]), produits = especes(cotes[1]);
  if (!reactifs.length || !produits.length) throw new Error("un côté de l'équation est vide");
  if (reactifs.length + produits.length > 6) throw new Error("plus de six espèces : trop pour l'écran");
  return { reactifs, produits, reversible };
}

// ── Fractions exactes ────────────────────────────────────────────────────────
type Q = [bigint, bigint];
const pgcd = (a: bigint, b: bigint): bigint => { a = a < 0n ? -a : a; b = b < 0n ? -b : b; while (b) [a, b] = [b, a % b]; return a; };
const q = (n: bigint, d = 1n): Q => { if (d < 0n) { n = -n; d = -d; } const g = pgcd(n, d) || 1n; return [n / g, d / g]; };
const sous = (a: Q, b: Q): Q => q(a[0] * b[1] - b[0] * a[1], a[1] * b[1]);
const mul = (a: Q, b: Q): Q => q(a[0] * b[0], a[1] * b[1]);
const div = (a: Q, b: Q): Q => q(a[0] * b[1], a[1] * b[0]);

/** Les coefficients entiers les plus petits, ou la raison de l'échec. */
export function equilibrer(reactifs: Espece[], produits: Espece[]): { coefficients: number[] } | { erreur: string } {
  const especes = [...reactifs, ...produits], n = especes.length;
  const elements = [...new Set(especes.flatMap((e) => Object.keys(e.atomes)))];
  // Une ligne par élément, plus la charge si une espèce en porte.
  const lignes: Q[][] = elements.map((el) => especes.map((e, j) => q(BigInt((e.atomes[el] || 0) * (j < reactifs.length ? 1 : -1)))));
  if (especes.some((e) => e.charge)) lignes.push(especes.map((e, j) => q(BigInt(e.charge * (j < reactifs.length ? 1 : -1)))));
  for (const el of elements) {
    const g = reactifs.some((e) => e.atomes[el]), d = produits.some((e) => e.atomes[el]);
    if (g !== d) return { erreur: `l'élément ${el} n'apparaît que d'un côté` };
  }
  // Gauss-Jordan exact.
  const M = lignes.map((l) => [...l]);
  const pivots: number[] = [];
  let r = 0;
  for (let c = 0; c < n && r < M.length; c++) {
    const p = M.findIndex((l, i) => i >= r && l[c][0] !== 0n);
    if (p < 0) continue;
    [M[r], M[p]] = [M[p], M[r]];
    const piv = M[r][c];
    M[r] = M[r].map((x) => div(x, piv));
    for (let i = 0; i < M.length; i++) if (i !== r && M[i][c][0] !== 0n) {
      const f = M[i][c];
      M[i] = M[i].map((x, k) => sous(x, mul(f, M[r][k])));
    }
    pivots.push(c); r++;
  }
  const libres = [...Array(n).keys()].filter((c) => !pivots.includes(c));
  if (libres.length === 0) return { erreur: "aucun équilibre possible" };
  if (libres.length > 1) return { erreur: "plusieurs équilibres possibles : la réaction est ambiguë" };
  const f = libres[0];
  const x: Q[] = Array(n).fill(q(0n));
  x[f] = q(1n);
  pivots.forEach((c, i) => { x[c] = q(-M[i][f][0], M[i][f][1]); });
  // Entiers : multiplier par le PPCM des dénominateurs, puis diviser par le PGCD.
  let ppcm = 1n;
  for (const [, d] of x) ppcm = ppcm / pgcd(ppcm, d) * d;
  let entiers = x.map(([a, d]) => a * (ppcm / d));
  if (entiers.every((e) => e <= 0n)) entiers = entiers.map((e) => -e);
  if (entiers.some((e) => e <= 0n)) return { erreur: "aucun équilibre à coefficients positifs" };
  const g = entiers.reduce((a, b) => pgcd(a, b));
  const fin = entiers.map((e) => Number(e / g));
  if (fin.some((e) => e > 99)) return { erreur: "coefficients trop grands pour l'écran" };
  return { coefficients: fin };
}

// ── La vraie géométrie des molécules : PubChem ───────────────────────────────
// Données du gouvernement américain (NLM), domaine public, citation demandée :
// l'attribution « PubChem (NLM), CID … » s'affiche dans la vidéo. Mesuré le
// 29/10 : glucose en 3D en 1,1 s, 4 Ko, sans clé.

export type Geometrie = { atomes: [string, number, number, number][]; liaisons: [number, number, number][]; source: string };

const PUBCHEM = "https://pubchem.ncbi.nlm.nih.gov/rest/pug";
const MAX_ATOMES = 60;
const cache = new Map<string, Geometrie | null>();

/** Une molécule V2000 -> atomes centrés et liaisons. */
export function lireSdf(sdf: string, source: string): Geometrie {
  const l = sdf.split(/\r?\n/);
  const na = Number(l[3].slice(0, 3)), nl = Number(l[3].slice(3, 6));
  if (!na || na > MAX_ATOMES) throw new Error(`${na} atomes : hors des bornes`);
  const atomes: [string, number, number, number][] = [];
  for (let i = 0; i < na; i++) {
    const t = l[4 + i];
    atomes.push([t.slice(31, 34).trim(), Number(t.slice(0, 10)), Number(t.slice(10, 20)), Number(t.slice(20, 30))]);
  }
  const c = [1, 2, 3].map((k) => atomes.reduce((s, a) => s + (a[k] as number), 0) / na);
  const arrondi = (x: number) => Math.round(x * 100) / 100;
  const centres = atomes.map(([e, x, y, z]) => [e, arrondi(x - c[0]), arrondi(y - c[1]), arrondi(z - c[2])] as [string, number, number, number]);
  const liaisons: [number, number, number][] = [];
  for (let i = 0; i < nl; i++) {
    const t = l[4 + na + i];
    liaisons.push([Number(t.slice(0, 3)) - 1, Number(t.slice(3, 6)) - 1, Math.min(3, Number(t.slice(6, 9)) || 1)]);
  }
  return { atomes: centres, liaisons, source };
}

/** La composition d'une géométrie, pour la comparer à la formule demandée. */
function composition(g: Geometrie): Record<string, number> {
  const o: Record<string, number> = {};
  for (const [e] of g.atomes) o[e] = (o[e] || 0) + 1;
  return o;
}
const memeComposition = (a: Record<string, number>, b: Record<string, number>) =>
  Object.keys({ ...a, ...b }).every((k) => (a[k] || 0) === (b[k] || 0));

async function lire(url: string, delaiMs: number): Promise<string | null> {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), delaiMs);
  try {
    const r = await fetch(url, { signal: ctrl.signal });
    return r.ok ? await r.text() : null;
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
}

/** La géométrie 3D d'une molécule, par son nom ou sa formule. Nulle si PubChem ne
 *  la connaît pas, ne répond pas à temps, ou rend une autre composition que celle
 *  demandée : on n'affiche jamais une molécule qui n'est pas la bonne. */
export async function geometriePubChem(requete: string, attendu: Record<string, number> | null, delaiMs = 4000): Promise<Geometrie | null> {
  const cle = requete.toLowerCase() + "|" + JSON.stringify(attendu);
  if (cache.has(cle)) return cache.get(cle)!;
  const cids = await lire(`${PUBCHEM}/compound/name/${encodeURIComponent(requete)}/cids/TXT`, delaiMs);
  const cid = cids?.split(/\s+/).find((x) => /^\d+$/.test(x));
  let g: Geometrie | null = null;
  if (cid) {
    const sdf = await lire(`${PUBCHEM}/compound/cid/${cid}/SDF?record_type=3d`, delaiMs);
    try { g = sdf ? lireSdf(sdf, `PubChem (NLM), CID ${cid}`) : null; } catch { g = null; }
    if (g && attendu && !memeComposition(composition(g), attendu)) g = null;
  }
  cache.set(cle, g);
  return g;
}

// Les molécules que le lecteur dessine déjà de mémoire : inutile d'aller les chercher.
const CONNUES = new Set(["H2", "O2", "N2", "CO", "CO2", "H2O", "CH4", "NH3", "NaCl"]);

// UNE FORMULE N'EST PAS UNE MOLÉCULE dès qu'il y a deux carbones. Mesuré le 29/10 :
// « C6H12O6 » cherché par sa formule rend le CID 102288, un autre isomère — même
// composition, pas le glucose (CID 5793). Les molécules des programmes ont donc
// leur nom ici (en anglais : c'est la langue de PubChem — « caféine » n'y est pas).
const NOMS_SCOLAIRES: Record<string, string> = {
  C6H12O6: "glucose", C12H22O11: "sucrose", C2H6O: "ethanol", C2H5OH: "ethanol",
  CH3OH: "methanol", CH4O: "methanol", C2H4O2: "acetic acid", CH3COOH: "acetic acid",
  C3H8: "propane", C4H10: "butane", C2H6: "ethane", C2H4: "ethylene", C2H2: "acetylene",
  C8H18: "octane", C6H6: "benzene", C3H8O3: "glycerol", C8H10N4O2: "caffeine",
  C9H8O4: "aspirin", C6H8O7: "citric acid", CH4N2O: "urea", C3H6O: "acetone",
};

/** Ce qu'on demande à PubChem pour une formule, ou null si elle est ambiguë. */
function requetePour(formule: string, nom?: string): string | null {
  if (nom) return nom;
  if (NOMS_SCOLAIRES[formule]) return NOMS_SCOLAIRES[formule];
  const carbones = lireEspece(formule).atomes.C || 0;
  return carbones >= 2 ? null : formule;
}

/** Après la validation : la géométrie réelle des molécules et des espèces des
 *  réactions que le lecteur ne connaît pas. Tout en parallèle, plafonné ; un échec
 *  est NOMMÉ dans les corrections, et le lecteur écrit alors la formule. */
export async function resoudreChimie(capsule: Record<string, unknown>, corrections: string[], delaiMs = 4000): Promise<void> {
  const travaux: Promise<void>[] = [];
  for (const s of (capsule.scenes as Record<string, unknown>[]) ?? []) {
    for (const g of (s.gestes as Record<string, unknown>[]) ?? []) {
      const p = g.parametres as Record<string, unknown>;
      if (g.verbe === "molecule" && !p.geometrie && !CONNUES.has(String(p.formule || ""))) {
        const attendu = p.formule ? lireEspece(String(p.formule)).atomes : null;
        const req = p.formule ? requetePour(String(p.formule), p.nom as string | undefined) : String(p.nom || "");
        if (!req) {
          corrections.push(`${s.id}: molécule « ${p.formule} » sans nom, plusieurs isomères possibles : formule écrite`);
          continue;
        }
        travaux.push(geometriePubChem(req, attendu, delaiMs).then((geo) => {
          if (geo) p.geometrie = geo;
          else corrections.push(`${s.id}: molécule « ${req} » sans forme 3D sur PubChem, formule écrite à la place`);
        }));
      }
      if (g.verbe === "reaction") {
        const noms = (p.noms ?? {}) as Record<string, string>;
        for (const e of (p.especes as Record<string, unknown>[]) ?? []) {
          const f = String(e.formule);
          if (CONNUES.has(f) || e.charge || e.geometrie) continue;
          const req = requetePour(f, noms[f]);
          // Sans géométrie, le lecteur écrit l'espèce : la réaction reste juste.
          if (req) travaux.push(geometriePubChem(req, e.atomes as Record<string, number>, delaiMs).then((geo) => {
            if (geo) e.geometrie = geo;
          }));
        }
      }
    }
  }
  await Promise.all(travaux);
}
