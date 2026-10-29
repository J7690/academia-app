// Tests de la chimie calculée (lot B2) — 29/10/2026.
// deno test supabase/functions/whiteboard-generate-storyboard/chimie_test.ts
import { assert, assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { equilibrer, lireEquation, lireEspece, lireSdf } from "./chimie.ts";

const coefs = (eq: string) => {
  const { reactifs, produits } = lireEquation(eq);
  return equilibrer(reactifs, produits);
};

Deno.test("les réactions des cours, équilibrées exactement", () => {
  const cas: [string, number[]][] = [
    ["H2 + O2 -> H2O", [2, 1, 2]],                                   // l'eau
    ["CH4 + O2 -> CO2 + H2O", [1, 2, 1, 2]],                         // combustion du méthane
    ["CO2 + H2O -> C6H12O6 + O2", [6, 6, 1, 6]],                     // photosynthèse
    ["C6H12O6 + O2 -> CO2 + H2O", [1, 6, 6, 6]],                     // respiration
    ["Fe + O2 -> Fe2O3", [4, 3, 2]],                                 // rouille
    ["Ca(OH)2 + HCl -> CaCl2 + H2O", [1, 2, 1, 2]],                  // parenthèses
    ["KMnO4 + HCl -> KCl + MnCl2 + Cl2 + H2O", [2, 16, 2, 2, 5, 8]], // le classique difficile
    ["N2 + H2 <=> NH3", [1, 3, 2]],                                  // Haber, réversible
  ];
  for (const [eq, attendu] of cas) assertEquals(coefs(eq), { coefficients: attendu }, eq);
});

Deno.test("les coefficients écrits par le modèle sont ignorés, même faux", () => {
  assertEquals(coefs("3 H2 + 5 O2 -> 7 H2O"), { coefficients: [2, 1, 2] });
});

Deno.test("les écritures courantes : indices, exposants, états, flèches", () => {
  assertEquals(coefs("2H₂ + O₂ → 2H₂O"), { coefficients: [2, 1, 2] });
  assertEquals(coefs("H2(g) + O2(g) = H2O(l)"), { coefficients: [2, 1, 2] });
  assertEquals(lireEspece("SO₄²⁻"), { formule: "SO4^2-", atomes: { S: 1, O: 4 }, charge: -2, etat: undefined });
  assertEquals(lireEspece("H2O(l)").etat, "l");
});

Deno.test("les ions : la charge se conserve aussi", () => {
  assertEquals(coefs("Cu + Ag^+ -> Cu^2+ + Ag"), { coefficients: [1, 2, 1, 2] });
  assertEquals(coefs("Fe^3+ + OH^- -> Fe(OH)3"), { coefficients: [1, 3, 1] });
});

Deno.test("ce qui ne s'équilibre pas est écarté, avec sa raison", () => {
  assert("erreur" in coefs("H2 -> O2"));
  const ambigu = coefs("H2 + O2 -> H2O + H2O2");
  assert("erreur" in ambigu && ambigu.erreur.includes("plusieurs"));
  assertThrows(() => lireEquation("H2 + O2"));
  assertThrows(() => lireEspece("Xy2"));
  assertThrows(() => lireEspece("Ca(OH2"));
});

Deno.test("SDF V2000 : atomes centrés, liaisons, plafond", () => {
  const sdf = [
    "eau", "  essai", "",
    "  3  2  0     0  0  0  0  0  0999 V2000",
    "    0.0000    0.0000    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0",
    "    0.9600    0.0000    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0",
    "   -0.2400    0.9300    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0",
    "  1  2  1  0  0  0  0",
    "  1  3  1  0  0  0  0",
    "M  END",
  ].join("\n");
  const g = lireSdf(sdf, "essai");
  assertEquals(g.atomes.map((a) => a[0]), ["O", "H", "H"]);
  assertEquals(g.liaisons, [[0, 1, 1], [0, 2, 1]]);
  const cx = g.atomes.reduce((s, a) => s + a[1], 0);
  assert(Math.abs(cx) < 0.02, "centré");
});
