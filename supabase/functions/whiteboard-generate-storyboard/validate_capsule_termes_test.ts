// Les termes de `convoquer` : une seule liste, trois copies — 29/10/2026.
// deno test --allow-read supabase/functions/whiteboard-generate-storyboard/validate_capsule_termes_test.ts
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { TERMES_OBJETS, validateCapsule } from "./validate_capsule.ts";
import { getCapsulePrompt } from "./prompt_capsule.ts";

const ici = new URL(".", import.meta.url);

Deno.test("la validation connaît exactement les termes de l'index", () => {
  const index = JSON.parse(Deno.readTextFileSync(
    new URL("../../../academia_bobodo_backend/studio_visuel/contours/index_objets.json", ici)));
  assertEquals([...TERMES_OBJETS].sort(), Object.keys(index.termes).sort());
});

Deno.test("l'invite annonce exactement ces termes", () => {
  const invite = getCapsulePrompt();
  const bloc = invite.split("Tout autre mot ne trouvera rien :")[1].split("CHOISIS LE PLUS PROCHE")[0];
  const annonces = bloc.split(",").map((t) => t.trim()).filter(Boolean);
  assertEquals(annonces.sort(), [...TERMES_OBJETS].sort());
});

const convoquer = (terme: string) => {
  const r = validateCapsule({ titre: "t", scenes: [{
    id: "s1", intention: "objet", sujet: "le feu", narration: "Le bois brûle.", duree_s: 10,
    gestes: [{ verbe: "convoquer", role: "sujet", parametres: { terme } }],
  }] });
  assert(r.valid, r.error);
  const g = (r.capsule!.scenes as Record<string, unknown>[])[0].gestes as Record<string, unknown>[];
  return { terme: (g[0].parametres as Record<string, unknown>).terme, corr: r.corrections };
};

Deno.test("« bois » (capsule du 29/10) : gardé, mais nommé", () => {
  const { terme, corr } = convoquer("bois");
  assertEquals(terme, "bois");
  assert(corr.some((c) => c.includes("« bois » hors bibliotheque")));
});

Deno.test("les écritures courantes sont ramenées à celle de l'index, sans correction", () => {
  for (const [brut, attendu] of [["Le Cœur", "coeur"], ["rivière", "riviere"], ["l'atome", "atome"], ["Corps  humain", "corps humain"]]) {
    const { terme, corr } = convoquer(brut);
    assertEquals(terme, attendu);
    assertEquals(corr, []);
  }
});
