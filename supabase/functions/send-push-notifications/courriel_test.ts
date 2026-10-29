import { assert, assertEquals, assertFalse } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { alerteMeriteCourriel, type AlerteCourriel, composerCourriel } from "./courriel.ts";

const alerte = (p: Partial<AlerteCourriel> = {}): AlerteCourriel => ({
  eventId: "e1",
  userId: "u1",
  domain: "admin_support",
  titre: "🚨 Nouveau message support",
  corps: "Awa : je n'arrive pas à payer",
  creeLe: "2026-10-29T18:05:00Z",
  telephones: 1,
  ...p,
});

Deno.test("seules les alertes administrateur partent par courriel, pas les statistiques de visite", () => {
  assert(alerteMeriteCourriel("admin_support"));
  assert(alerteMeriteCourriel("admin_accounts"));
  assert(alerteMeriteCourriel("admin_bobodo"));
  assertFalse(alerteMeriteCourriel("admin_audience"));
  assertFalse(alerteMeriteCourriel("student_payments"));
  assertFalse(alerteMeriteCourriel(null));
});

Deno.test("une alerte : son titre fait le sujet", () => {
  const { sujet } = composerCourriel([alerte()]);
  assertEquals(sujet, "Academia — 🚨 Nouveau message support");
});

Deno.test("une rafale : un seul courriel qui les compte", () => {
  const { sujet, html } = composerCourriel([alerte(), alerte({ eventId: "e2", titre: "Nouveau compte" })]);
  assertEquals(sujet, "Academia — 2 alertes administrateur");
  assert(html.includes("Nouveau compte"));
});

Deno.test("le texte d'un étudiant ne peut pas injecter de HTML", () => {
  const { html } = composerCourriel([alerte({ corps: '<a href="x">clic</a>' })]);
  assertFalse(html.includes('<a href="x">'));
  assert(html.includes("&lt;a href=&quot;x&quot;&gt;"));
});

Deno.test("sans téléphone relié, le courriel le dit ; avec, il se tait", () => {
  assert(composerCourriel([alerte({ telephones: 0 })]).html.includes("Aucun téléphone"));
  assertFalse(composerCourriel([alerte({ telephones: 2 })]).html.includes("Aucun téléphone"));
});

Deno.test("l'heure est celle de Ouagadougou", () => {
  const { html } = composerCourriel([alerte()]);
  assert(html.includes("18:05"), html);
});
