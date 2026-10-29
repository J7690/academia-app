// Tests de la chaîne en couches, sans réseau (appel injecté) — 29/10/2026.
// deno test --allow-read --allow-env supabase/functions/whiteboard-generate-storyboard/chaine_capsule_test.ts
// (--allow-env : llm.ts lit ses variables au chargement ; aucun appel réseau n'est fait.)
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { type Appeler, CONSIGNE_ILLUSTRATEUR, CONSIGNE_SCENARISTE, defautsParScene, genererCapsuleEnCouches } from "./chaine_capsule.ts";
import { getCapsulePrompt, INTRO_CAPSULE, SECTION_DECOR, SECTION_EXEMPLES, SECTION_GESTES, SECTION_LIMITES, SECTION_QUALITE, SECTION_RENDU } from "./prompt_capsule.ts";

const reponse = (content: unknown, model = "essai/modele") => ({ content: JSON.stringify(content), model, ms: 5, jetonsEntree: 10, jetonsSortie: 20, coutUsd: 0.001, essais: [] });

const PLAN = {
  titre: "Le feu",
  scenes: [
    { id: "s1", decor: "gestes", intention: "processus", sujet: "le triangle du feu", narration: "Le feu a besoin de bois, d'oxygène et de chaleur.", duree_s: 12, a_montrer: ["flamme", "arbre"] },
    { id: "s2", decor: "gestes", intention: "processus", sujet: "la combustion", narration: "Le méthane brûle dans l'oxygène.", duree_s: 12, a_montrer: ["réaction CH4 + O2 -> CO2 + H2O"] },
  ],
};

Deno.test("l'invite découpée en sections se recolle à l'identique", () => {
  assertEquals(getCapsulePrompt(), INTRO_CAPSULE + SECTION_DECOR + SECTION_GESTES + SECTION_LIMITES + SECTION_RENDU + SECTION_EXEMPLES + SECTION_QUALITE);
  // 17 632 OCTETS en UTF-8 (wc -c), mesurés avant la découpe, le 29/10.
  assertEquals(new TextEncoder().encode(getCapsulePrompt()).length, 17632);
});

Deno.test("chaque métier reçoit SA consigne, pas celle des autres", () => {
  assert(!CONSIGNE_SCENARISTE.includes("tu DÉCRIS la scène, en coordonnées"), "le scénariste ne fait pas de coordonnées");
  assert(CONSIGNE_SCENARISTE.includes("a_montrer") && CONSIGNE_SCENARISTE.includes("volcan"));
  assert(!CONSIGNE_SCENARISTE.includes("segments: [[[x,y,z]"), "pas la géométrie chez le scénariste");
  assert(CONSIGNE_ILLUSTRATEUR.includes("reaction") && CONSIGNE_ILLUSTRATEUR.includes("silhouetter"));
  assert(!CONSIGNE_ILLUSTRATEUR.includes("0. LE DÉCOR"), "pas le choix du décor chez l'illustrateur");
});

Deno.test("la chaîne : scénariste, illustrateurs en parallèle, capsule valide", async () => {
  const vus: string[] = [];
  const appeler: Appeler = async (role, msgs) => {
    vus.push(role);
    if (role === "scenariste") return reponse(PLAN, "anthropic/claude-sonnet-5.5");
    const id = JSON.parse(msgs[1].content).scene.id;
    return reponse({ gestes: id === "s1"
      ? [{ verbe: "flamme", role: "sujet", parametres: { taille: 1.5 } }, { verbe: "convoquer", parametres: { terme: "arbre", position: [-2, 0, 0] } }]
      : [{ verbe: "reaction", role: "sujet", parametres: { equation: "CH4 + O2 -> CO2 + H2O" } }, { verbe: "flamme", parametres: {} }] }, "google/gemini-3.8-flash");
  };
  const { vc, etapes, reprises } = await genererCapsuleEnCouches("le feu", appeler);
  assert(vc.valid, vc.error);
  assertEquals(vus.sort(), ["illustrateur", "illustrateur", "scenariste"]);
  assertEquals(reprises, []);
  assertEquals(etapes.map((e) => e.couche).sort(), ["illustrateur", "illustrateur", "scenariste"]);
  const s2 = (vc.capsule!.scenes as Record<string, unknown>[])[1];
  const coefs = ((s2.gestes as Record<string, unknown>[])[0].parametres as Record<string, unknown>).especes as Record<string, unknown>[];
  assertEquals(coefs.map((e) => e.coef), [1, 2, 1, 2]);
});

Deno.test("le contrôleur reprend la scène en défaut, une fois, avec ses défauts", async () => {
  let demandeReprise: Record<string, unknown> | null = null;
  const appeler: Appeler = async (role, msgs) => {
    if (role === "scenariste") return reponse(PLAN);
    const d = JSON.parse(msgs[1].content);
    if (d.scene.id === "s1" && !d.defauts_a_corriger) {
      return reponse({ gestes: [{ verbe: "convoquer", role: "sujet", parametres: { terme: "bois" } }] }); // hors bibliothèque, un seul geste
    }
    if (d.defauts_a_corriger) demandeReprise = d;
    return reponse({ gestes: [{ verbe: "flamme", role: "sujet", parametres: {} }, { verbe: "convoquer", parametres: { terme: "arbre" } }] });
  };
  const { vc, reprises } = await genererCapsuleEnCouches("le feu", appeler);
  assert(vc.valid);
  assertEquals(reprises, ["s1"]);
  assert(demandeReprise !== null);
  const defauts = (demandeReprise as unknown as { defauts_a_corriger: string[] }).defauts_a_corriger;
  assert(defauts.some((d) => d.includes("bois")) && defauts.some((d) => d.includes("seulement 1 geste")));
  const s1 = (vc.capsule!.scenes as Record<string, unknown>[])[0];
  assertEquals((s1.gestes as Record<string, unknown>[]).map((g) => g.verbe), ["flamme", "convoquer"]);
});

Deno.test("un illustrateur en panne ne perd pas le cours : la scène écrit son sujet", async () => {
  const appeler: Appeler = async (role, msgs) => {
    if (role === "scenariste") return reponse(PLAN);
    if (JSON.parse(msgs[1].content).scene.id === "s2") throw new Error("tous les modeles ont echoue");
    return reponse({ gestes: [{ verbe: "flamme", role: "sujet", parametres: {} }, { verbe: "ecrire", parametres: { texte: "feu" } }] });
  };
  const { vc, etapes } = await genererCapsuleEnCouches("le feu", appeler);
  assert(vc.valid);
  const s2 = (vc.capsule!.scenes as Record<string, unknown>[])[1];
  assertEquals((s2.gestes as Record<string, unknown>[])[0].verbe, "ecrire");
  assert(etapes.some((e) => e.couche === "illustrateur" && e.essais[0]?.includes("echoue")));
});

Deno.test("defautsParScene lit les corrections et compte les gestes", () => {
  const capsule = { scenes: [{ id: "s1", decor: "gestes", gestes: [{ verbe: "flamme" }] }, { id: "s2", decor: "corps", gestes: [] }] };
  const d = defautsParScene(capsule, ["s1.g0: objet « bois » hors bibliotheque (69 termes), il ne s'affichera pas", "duree totale 130s ecretee a 120s"]);
  assertEquals([...d.keys()], ["s1"]);
  assertEquals(d.get("s1")!.length, 2);
});
