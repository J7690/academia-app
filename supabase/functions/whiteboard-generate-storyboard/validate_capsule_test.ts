// Tests de la validation d'une capsule DECRITE.
//
// L'ancienne version de ces tests verifiait qu'« un archetype inconnu est
// remplace, pas rejete ». C'etait le defaut lui-meme, tenu pour une qualite :
// toute forme inconnue devenait `reseau`, y compris une forme parfaitement
// adaptee au sujet. Les tests ci-dessous verifient l'inverse -- qu'un geste
// qu'on ne sait pas faire est ECARTE ET NOMME, jamais silencieusement remplace.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { validateCapsule } from "./validate_capsule.ts";

const scene = (gestes: unknown[], extra: Record<string, unknown> = {}) => ({
  titre: "essai",
  scenes: [{
    id: "s1", intention: "objet", sujet: "un poumon",
    narration: "La voix dit quelque chose.", duree_s: 12, gestes, ...extra,
  }],
});

Deno.test("une composition correcte passe sans correction", () => {
  const r = validateCapsule(scene([{
    verbe: "silhouetter", role: "sujet",
    parametres: {
      segments: [[[0, 0, 0], [0, 0, 1], [0, 0, 2]]],
      rayons: [0.3, 0.25, 0.2], lisser: 1, nom: "tige",
    },
  }]));
  assert(r.valid);
  assertEquals(r.corrections.length, 0);
  const s = (r.capsule!.scenes as any[])[0];
  assertEquals(s.gestes.length, 1);
  assertEquals(s.gestes[0].verbe, "silhouetter");
});

Deno.test("un verbe inconnu est ECARTE et NOMME, jamais remplace", () => {
  const r = validateCapsule(scene([
    { verbe: "invoquer", parametres: {} },
    { verbe: "sculpter", role: "sujet", parametres: { base: "ovoide" } },
  ]));
  assert(r.valid);
  const s = (r.capsule!.scenes as any[])[0];
  // Le geste inconnu a disparu, l'autre survit. AUCUN remplacement.
  assertEquals(s.gestes.length, 1);
  assertEquals(s.gestes[0].verbe, "sculpter");
  assert(r.corrections.some((c) => c.includes("verbe inconnu")));
  assert(!r.corrections.some((c) => c.includes("remplace_par")));
});

Deno.test("les six verbes sont acceptes", () => {
  const r = validateCapsule(scene([
    { verbe: "silhouetter", parametres: { segments: [[[0, 0, 0], [0, 0, 1]]] } },
    { verbe: "revolutionner", parametres: { profil: [[0.1, 0], [1, 1], [0.2, 2]] } },
    { verbe: "extruder", parametres: { contour: [[0, 0], [1, 0], [1, 1]] } },
    { verbe: "sculpter", parametres: { base: "galet" } },
    { verbe: "napper", parametres: { cote: 100, pas: 30 } },
    { verbe: "ecrire", parametres: { texte: "photosynthese" } },
  ]));
  assert(r.valid);
  assertEquals((r.capsule!.scenes as any[])[0].gestes.length, 6);
});

Deno.test("un squelette vide est ecarte, pas devine", () => {
  const r = validateCapsule(scene([
    { verbe: "silhouetter", parametres: { segments: [] } },
  ]));
  assert(r.valid);   // la scene survit par le repli en texte
  const s = (r.capsule!.scenes as any[])[0];
  assertEquals(s.gestes[0].verbe, "ecrire");
  assert(r.corrections.some((c) => c.includes("sans squelette")));
  assert(r.corrections.some((c) => c.includes("repli sur le texte")));
});

Deno.test("les coordonnees hors bornes sont ramenees, pas rejetees", () => {
  const r = validateCapsule(scene([{
    verbe: "sculpter",
    parametres: { base: "ovoide", echelle: 900, position: [9999, 0, -9999] },
  }]));
  assert(r.valid);
  const p = (r.capsule!.scenes as any[])[0].gestes[0].parametres;
  assertEquals(p.echelle, 8.0);
  assert(Math.abs(p.position[0]) <= 48);
});

Deno.test("un rayon negatif de revolution est ramene a zero", () => {
  const r = validateCapsule(scene([{
    verbe: "revolutionner", parametres: { profil: [[-5, 0], [1, 1], [0.3, 2]] },
  }]));
  assert(r.valid);
  const p = (r.capsule!.scenes as any[])[0].gestes[0].parametres;
  assertEquals(p.profil[0][0], 0);
});

// Le filtre reconstruit `parametres` a neuf, cle par cle. Toute cle qu'il
// oublie disparait SANS un mot dans `corrections` -- et `position` avait ete
// oubliee pour ce verbe-la seulement. Le profil etant [rayon, hauteur], rien
// d'autre ne permet un decalage LATERAL : deux recipients d'une scene
// `comparaison` naissaient superposes a l'origine, et on ne voyait qu'une
// masse. Audit croise des quatre couches, 12/08.
Deno.test("revolutionner conserve sa position : deux formes cote a cote", () => {
  const r = validateCapsule(scene([
    { verbe: "revolutionner", parametres: { profil: [[1, 0], [1, 2]], position: [-2.5, 0, 0] } },
    { verbe: "revolutionner", parametres: { profil: [[1, 0], [1, 2]], position: [2.5, 0, 0] } },
  ]));
  assert(r.valid);
  const g = (r.capsule!.scenes as any[])[0].gestes;
  assertEquals(g[0].parametres.position, [-2.5, 0, 0]);
  assertEquals(g[1].parametres.position, [2.5, 0, 0]);
  assert(g[0].parametres.position[0] !== g[1].parametres.position[0],
    "les deux formes doivent pouvoir etre distinctes en x");
});

Deno.test("revolutionner sans position reste centre, sans correction bruyante", () => {
  const r = validateCapsule(scene([
    { verbe: "revolutionner", parametres: { profil: [[1, 0], [1, 2]] } },
  ]));
  assert(r.valid);
  assertEquals(r.corrections.length, 0);
  assertEquals((r.capsule!.scenes as any[])[0].gestes[0].parametres.position, [0, 0, 0]);
});

Deno.test("une intention inconnue est ramenee a objet, et c'est dit", () => {
  const r = validateCapsule(scene(
    [{ verbe: "sculpter", parametres: {} }], { intention: "cosmique" }));
  assert(r.valid);
  assertEquals((r.capsule!.scenes as any[])[0].intention, "objet");
  assert(r.corrections.some((c) => c.includes("intention")));
});

Deno.test("aucune scene : refus explicite, pour que le credit soit rembourse", () => {
  const r = validateCapsule({ titre: "x", scenes: [] });
  assertEquals(r.valid, false);
  assertEquals(r.error, "aucune scene");
});

Deno.test("capsule entierement muette : refus", () => {
  const r = validateCapsule({
    titre: "x",
    scenes: [{ id: "s1", intention: "objet", narration: "", gestes: [
      { verbe: "sculpter", parametres: {} }] }],
  });
  assertEquals(r.valid, false);
  assert(String(r.error).includes("muette"));
});

Deno.test("duree totale ecretee sans perdre de scene", () => {
  const scenes = Array.from({ length: 6 }, (_, i) => ({
    id: `s${i}`, intention: "objet", narration: "voix", duree_s: 25,
    gestes: [{ verbe: "sculpter", parametres: {} }],
  }));
  const r = validateCapsule({ titre: "x", scenes });
  assert(r.valid);
  const t = (r.capsule!.scenes as any[]).reduce((a, s) => a + s.duree_s, 0);
  assertEquals((r.capsule!.scenes as any[]).length, 6);
  assert(t <= 120, `total ${t}`);
  assert(r.corrections.some((c) => c.includes("ecretee")));
});

Deno.test("plus de six scenes : troncature", () => {
  const scenes = Array.from({ length: 9 }, (_, i) => ({
    id: `s${i}`, intention: "objet", narration: "voix", duree_s: 10,
    gestes: [{ verbe: "sculpter", parametres: {} }],
  }));
  const r = validateCapsule({ titre: "x", scenes });
  assert(r.valid);
  assertEquals((r.capsule!.scenes as any[]).length, 6);
});
