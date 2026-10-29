// L'ambiance de la capsule : une liste, trois copies — 29/10/2026.
// deno test --allow-read --allow-env supabase/functions/whiteboard-generate-storyboard/validate_capsule_ambiance_test.ts
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { AMBIANCES, validateCapsule } from "./validate_capsule.ts";
import { CONSIGNE_SCENARISTE } from "./chaine_capsule.ts";

const ici = new URL(".", import.meta.url);

const capsule = (ambiance?: unknown) => validateCapsule({ titre: "t", ...(ambiance === undefined ? {} : { ambiance }), scenes: [{
  id: "s1", intention: "objet", sujet: "le feu", narration: "Le bois brûle.", duree_s: 10,
  gestes: [{ verbe: "ecrire", role: "sujet", parametres: { texte: "feu" } }],
}] });

Deno.test("chaque ambiance proposée est dessinée par le lecteur", () => {
  const lecteur = Deno.readTextFileSync(new URL("../../../academia_bobodo_backend/studio_visuel/lecteur/lecteur.js", ici));
  const bloc = lecteur.split("export const AMBIANCES = {")[1].split("};")[0];
  const dessinees = [...bloc.matchAll(/^\s*([a-z]+):/gm)].map((m) => m[1]);
  for (const a of AMBIANCES) assert(dessinees.includes(a), `« ${a} » absente de lecteur.js`);
});

Deno.test("l'invite du scénariste présente exactement ces ambiances", () => {
  const bloc = CONSIGNE_SCENARISTE.split("L'AMBIANCE DE LA CAPSULE")[1].split("Choisis d'après")[0];
  const annoncees = [...bloc.matchAll(/^\s{3}([a-z]+)\s{2,}/gm)].map((m) => m[1]);
  assertEquals(annoncees.sort(), [...AMBIANCES].sort());
});

Deno.test("absente : nuit, sans correction", () => {
  const r = capsule();
  assert(r.valid);
  assertEquals(r.capsule!.ambiance, "nuit");
  assertEquals(r.corrections, []);
});

Deno.test("connue, même avec accent et majuscule : gardée", () => {
  assertEquals(capsule("Forêt").capsule!.ambiance, "foret");
  assertEquals(capsule("savane").capsule!.ambiance, "savane");
});

Deno.test("inconnue ou pas encore prête (papier) : nuit, et c'est dit", () => {
  for (const a of ["jungle", "papier"]) {
    const r = capsule(a);
    assertEquals(r.capsule!.ambiance, "nuit");
    assert(r.corrections.some((c) => c.includes("ambiance")), r.corrections.join(" | "));
  }
});
