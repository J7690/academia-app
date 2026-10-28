// Tests du format capsule v2 (décors) — 28/10/2026.
// deno test supabase/functions/whiteboard-generate-storyboard/validate_capsule_v2_test.ts
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateCapsule } from "./validate_capsule.ts";

const ecrire = { verbe: "ecrire", role: "sujet", parametres: { texte: "ADN", taille: 1 } };
const scene = (extra: Record<string, unknown>) => ({
  id: "s1", intention: "objet", sujet: "le cœur", narration: "Le cœur pompe le sang.", duree_s: 10,
  gestes: [ecrire], ...extra,
});
const valider = (...scenes: Record<string, unknown>[]) => {
  const r = validateCapsule({ titre: "t", scenes });
  assert(r.valid, r.error);
  return { scenes: r.capsule!.scenes as Record<string, unknown>[], corr: r.corrections };
};

Deno.test("sans décor, une capsule v1 reste v1 : décor gestes, rien d'autre", () => {
  const { scenes, corr } = valider(scene({}));
  assertEquals(scenes[0].decor, "gestes");
  assertEquals(scenes[0].foyer, undefined);
  assertEquals(scenes[0].flux, undefined);
  assertEquals(corr, []);
});

Deno.test("décor corps : foyer, flux et plan gardés", () => {
  const { scenes, corr } = valider(scene({ decor: "corps", foyer: "tete", flux: true, plan: "approche" }));
  assertEquals([scenes[0].decor, scenes[0].foyer, scenes[0].flux, scenes[0].plan], ["corps", "tete", true, "approche"]);
  assertEquals(corr, []);
});

Deno.test("décor inconnu : ramené à gestes, et c'est dit", () => {
  const { scenes, corr } = valider(scene({ decor: "foret" }));
  assertEquals(scenes[0].decor, "gestes");
  assert(corr.some((c) => c.includes("decor « foret » inconnu")));
});

Deno.test("corps sans foyer : thorax, sans bruit ; foyer inconnu : thorax, et c'est dit", () => {
  assertEquals(valider(scene({ decor: "corps" })).scenes[0].foyer, "thorax");
  const { scenes, corr } = valider(scene({ decor: "corps", foyer: "aura" }));
  assertEquals(scenes[0].foyer, "thorax");
  assert(corr.some((c) => c.includes("foyer « aura » ramene a thorax")));
});

Deno.test("un ORGANE donné comme foyer est rangé dans sa zone (mesuré : foie, poumon)", () => {
  assertEquals(valider(scene({ decor: "corps", foyer: "foie" })).scenes[0].foyer, "ventre");
  assertEquals(valider(scene({ decor: "corps", foyer: "Poumon" })).scenes[0].foyer, "thorax");
  assertEquals(valider(scene({ decor: "corps", foyer: "pied" })).scenes[0].foyer, "jambes");
});

Deno.test("décor corps : l'organe convoqué est retiré (le foyer le montre), le mot reste", () => {
  const cerveau = { verbe: "convoquer", role: "sujet", parametres: { terme: "cerveau" } };
  const { scenes, corr } = valider(scene({ decor: "corps", foyer: "tete", gestes: [cerveau, ecrire] }));
  assertEquals((scenes[0].gestes as Record<string, unknown>[]).map((g) => g.verbe), ["ecrire"]);
  assert(corr.some((c) => c.includes("retire(s) du decor corps")));
  // Seul l'organe était là : le pod reçoit son repli.
  const r = valider(scene({ decor: "corps", gestes: [cerveau] }));
  assert((r.scenes[0].gestes as Record<string, unknown>[]).every((g) => g.pour === "pod"));
});

Deno.test("hors du corps, seul le foyer « sujet » passe : l'énergie a besoin d'un référent", () => {
  assertEquals(valider(scene({ foyer: "sujet" })).scenes[0].foyer, "sujet");
  const r1 = valider(scene({ foyer: "thorax" }));
  assertEquals(r1.scenes[0].foyer, undefined);
  assert(r1.corr.some((c) => c.includes("ignore hors du decor corps")));
  const r2 = valider(scene({ decor: "gouttes", foyer: "sujet" }));
  assertEquals(r2.scenes[0].foyer, undefined);
  assert(r2.corr.some((c) => c.includes("ignore en decor gouttes")));
});

Deno.test("un plan qui n'appartient pas au décor est ignoré", () => {
  const { scenes, corr } = valider(scene({ decor: "gouttes", plan: "approche" }));
  assertEquals(scenes[0].plan, undefined);
  assert(corr.some((c) => c.includes("plan « approche » inconnu")));
});

Deno.test("décor sans geste : le pod reçoit un repli marqué, sans correction bruyante", () => {
  const { scenes, corr } = valider(scene({ decor: "corps", gestes: [] }), { ...scene({ decor: "gouttes", gestes: [] }), id: "s2" });
  const g1 = scenes[0].gestes as Record<string, unknown>[];
  const g2 = scenes[1].gestes as Record<string, unknown>[];
  assert(g1.length > 0 && g1.every((g) => g.pour === "pod"));
  assert(g2.length > 0 && g2.every((g) => g.pour === "pod"));
  assertEquals((g1[0].parametres as Record<string, unknown>).terme, "corps humain");
  assertEquals(corr, []);
});

Deno.test("décor gestes sans geste : repli texte, comme avant", () => {
  const { scenes, corr } = valider(scene({ gestes: [] }));
  assertEquals((scenes[0].gestes as Record<string, unknown>[])[0].verbe, "ecrire");
  assert(corr.some((c) => c.includes("repli sur le texte")));
});

Deno.test("deux scènes corps : même foyer et même plan = même image, NOMMÉE ; foyer différent = rien", () => {
  const a = { ...scene({ decor: "corps", foyer: "tete", gestes: [] }), id: "s1" };
  const b = { ...scene({ decor: "corps", foyer: "tete", gestes: [] }), id: "s2" };
  const c = { ...scene({ decor: "corps", foyer: "ventre", gestes: [] }), id: "s3" };
  assert(valider(a, b).corr.some((x) => x.includes("s2: image identique a s1")));
  assertEquals(valider(a, c).corr, []);
});

Deno.test("le flux accepte « true » en texte, et rien d'autre", () => {
  assertEquals(valider(scene({ decor: "corps", flux: "true" })).scenes[0].flux, true);
  assertEquals(valider(scene({ decor: "corps", flux: "oui" })).scenes[0].flux, undefined);
});
