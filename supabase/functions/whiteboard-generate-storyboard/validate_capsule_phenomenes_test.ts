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

Deno.test("molécule : les écritures courantes sont ramenées, l'inconnue est écartée et dite", () => {
  const { gestes, corr } = avec(
    { verbe: "molecule", parametres: { formule: "H₂O" } },
    { verbe: "molecule", parametres: { formule: "co2" } },
    { verbe: "molecule", parametres: { formule: "C6H12O6" } },
  );
  assertEquals(gestes.map((g) => P(g).formule), ["H2O", "CO2"]);
  assert(corr.some((c) => c.includes("C6H12O6") && c.includes("ecartee")));
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
