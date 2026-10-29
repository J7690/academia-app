// Tests des phénomènes et accessoires (phase B) — 28/10/2026.
// deno test supabase/functions/whiteboard-generate-storyboard/validate_capsule_phenomenes_test.ts
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateCapsule } from "./validate_capsule.ts";

const avec = (...gestes: Record<string, unknown>[]) => {
  const r = validateCapsule({ titre: "le feu", scenes: [{
    id: "s1", intention: "processus", sujet: "la combustion", duree_s: 10,
    narration: "Le feu a besoin d'un combustible, d'oxygène et de chaleur.", gestes,
  }] });
  assert(r.valid, r.error);
  const s = (r.capsule!.scenes as Record<string, unknown>[])[0];
  return { gestes: s.gestes as Record<string, unknown>[], corr: r.corrections };
};
const P = (g: Record<string, unknown>) => g.parametres as Record<string, unknown>;

Deno.test("le cours sur le feu passe tel quel : flamme, souffle d'oxygène, molécule, étiquette", () => {
  const { gestes, corr } = avec(
    { verbe: "flamme", role: "sujet", parametres: { taille: 1.6, position: [0, 0, 0] } },
    { verbe: "souffle", parametres: { de: [3, 0, 1], vers: [0, 0, 0.5], couleur: "bleu", texte: "oxygène" } },
    { verbe: "molecule", parametres: { formule: "O2", position: [2, 0, 1.5] } },
    { verbe: "etiquette", parametres: { cible: [0, 0, 0.3], texte: "chaleur", cote: "gauche" } },
  );
  assertEquals(gestes.map((g) => g.verbe), ["flamme", "souffle", "molecule", "etiquette"]);
  assertEquals(corr, []);
});

Deno.test("molécule : les écritures courantes sont ramenées, l'illisible est écartée et dite", () => {
  // Depuis le lot B2 (29/10), toute formule LISIBLE passe : sa géométrie vient de PubChem.
  const { gestes, corr } = avec(
    { verbe: "molecule", parametres: { formule: "H₂O" } },
    { verbe: "molecule", parametres: { formule: "co2" } },
    { verbe: "molecule", parametres: { formule: "C6H12O6", nom: "glucose" } },
    { verbe: "molecule", parametres: { formule: "Xy2" } },
  );
  assertEquals(gestes.map((g) => P(g).formule), ["H2O", "CO2", "C6H12O6"]);
  assertEquals(P(gestes[2]).nom, "glucose");
  assert(corr.some((c) => c.includes("Xy2") && c.includes("ecartee")));
});

Deno.test("réaction : les coefficients sont calculés, les faux du modèle ignorés", () => {
  const { gestes, corr } = avec(
    { verbe: "reaction", role: "sujet", parametres: { equation: "3 H2 + O2 -> 5 H2O" } },
  );
  const e = P(gestes[0]).especes as Record<string, unknown>[];
  assertEquals(e.map((x) => [x.formule, x.cote, x.coef]), [["H2", "reactif", 2], ["O2", "reactif", 1], ["H2O", "produit", 2]]);
  assertEquals(corr, []);
});

Deno.test("réaction impossible ou ambiguë : écartée, jamais affichée fausse", () => {
  const { gestes, corr } = avec(
    { verbe: "reaction", parametres: { equation: "H2 -> O2" } },
    { verbe: "reaction", parametres: { equation: "H2 + O2 -> H2O + H2O2" } },
    { verbe: "flamme", parametres: {} },
  );
  assertEquals(gestes.map((g) => g.verbe), ["flamme"]);
  assertEquals(corr.filter((c) => c.includes("reaction")).length, 2);
});

Deno.test("réaction : les noms des espèces sont gardés, rangés par formule", () => {
  const { gestes } = avec(
    { verbe: "reaction", parametres: { equation: "CO₂ + H₂O → C₆H₁₂O₆ + O₂", noms: { "C₆H₁₂O₆": "glucose" } } },
  );
  assertEquals(P(gestes[0]).noms, { C6H12O6: "glucose" });
  assertEquals((P(gestes[0]).especes as Record<string, unknown>[]).map((x) => x.coef), [6, 6, 1, 6]);
});

Deno.test("souffle, foudre et flèche sans extrémités : écartés, pas inventés", () => {
  const { gestes, corr } = avec(
    { verbe: "souffle", parametres: { de: [0, 0, 0] } },
    { verbe: "foudre", parametres: {} },
    { verbe: "fleche", parametres: { de: [-1, 0, 0], vers: [1, 0, 0], texte: "évaporation" } },
  );
  assertEquals(gestes.map((g) => g.verbe), ["fleche"]);
  assertEquals(P(gestes[0]).texte, "évaporation");
  assertEquals(corr.length, 2);
});

Deno.test("écoulement sans chemin : un lit droit plutôt qu'aucune eau, et c'est dit", () => {
  const { gestes, corr } = avec({ verbe: "ecoulement", role: "sujet", parametres: {} });
  assertEquals((P(gestes[0]).chemin as unknown[]).length, 3);
  assert(corr.some((c) => c.includes("lit droit")));
});

Deno.test("bornes : une flamme géante et une pluie folle sont ramenées", () => {
  const { gestes } = avec(
    { verbe: "flamme", parametres: { taille: 99 } },
    { verbe: "pluie", parametres: { intensite: 50, zone: [-40, 3] } },
    { verbe: "souffle", parametres: { de: [0, 0, 0], vers: [1, 0, 0], couleur: "violet" } },
  );
  assertEquals(P(gestes[0]).taille, 6);
  assertEquals(P(gestes[1]).intensite, 2);
  assertEquals(P(gestes[1]).zone, [12, 3]);
  assertEquals(P(gestes[2]).couleur, "bleu");
});
