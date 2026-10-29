// ========================================
// COPIE PAR COURRIEL DES ALERTES ADMINISTRATEUR (29/10/2026)
// ========================================
// Pourquoi : du 10/09 au 29/10, le compte administrateur n'avait plus aucun
// téléphone relié (repris par un compte étudiant sur le même appareil). Les
// alertes support, comptes, candidatures partaient dans le vide, sans que
// personne ne le voie. Le courriel ne dépend d'aucune application ouverte ni
// connectée : c'est le filet de secours.
//
// Inerte tant que RESEND_API_KEY et RESEND_FROM_EMAIL ne sont pas posés.
// Destinataires : app.alertes_courriel_destinataires (actif = true).
// Journal et anti-doublon : app.alertes_courriel_envois (clé = event_id).

export type AlerteCourriel = {
  eventId: string;
  userId: string;
  domain: string;
  titre: string;
  corps: string;
  creeLe: string;
  // Nombre de téléphones (hors navigateur) qui ont reçu le push.
  telephones: number;
};

// `admin_audience` est une statistique de visites toutes les quelques minutes :
// ce n'est pas un usager qui appelle, et elle noierait les vraies alertes.
const DOMAINES_SANS_COURRIEL = new Set(["admin_audience"]);

const URL_CONSOLE = "https://app.academiea.com";

export function alerteMeriteCourriel(domain: string | null | undefined): boolean {
  return !!domain && domain.startsWith("admin_") && !DOMAINES_SANS_COURRIEL.has(domain);
}

function echapper(texte: string): string {
  return texte
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function heureOuaga(iso: string): string {
  try {
    return new Date(iso).toLocaleString("fr-FR", {
      timeZone: "Africa/Ouagadougou",
      day: "2-digit",
      month: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

/** Un seul courriel par destinataire et par passage, quelle que soit la rafale. */
export function composerCourriel(alertes: AlerteCourriel[]): { sujet: string; html: string } {
  const sujet = alertes.length === 1
    ? `Academia — ${alertes[0].titre}`
    : `Academia — ${alertes.length} alertes administrateur`;

  const lignes = alertes.map((a) =>
    `<li style="margin:0 0 12px 0">` +
    `<strong>${echapper(a.titre)}</strong><br>` +
    `${echapper(a.corps)}<br>` +
    `<span style="color:#6b7280;font-size:12px">${echapper(heureOuaga(a.creeLe))}</span>` +
    `</li>`
  ).join("");

  // Le signal qui a manqué sept semaines : le dire dans le courriel même.
  const sansTelephone = alertes.some((a) => a.telephones === 0)
    ? `<p style="color:#E02018;font-weight:bold">Aucun téléphone ne reçoit vos alertes ` +
      `administrateur. Ouvrez l'application mobile et connectez-vous avec ce compte.</p>`
    : "";

  const html =
    `<div style="font-family:Arial,sans-serif;max-width:560px;color:#111827">` +
    `<h2 style="color:#388840;margin:0 0 16px 0">Alertes Academia</h2>` +
    `<ul style="padding-left:18px;margin:0 0 16px 0">${lignes}</ul>` +
    sansTelephone +
    `<p><a href="${URL_CONSOLE}" style="color:#388840">Ouvrir la console</a></p>` +
    `</div>`;

  return { sujet, html };
}

type Rest = {
  url: string;
  cle: string;
};

function entetes(rest: Rest, extra: Record<string, string> = {}) {
  return {
    apikey: rest.cle,
    Authorization: `Bearer ${rest.cle}`,
    "Content-Type": "application/json",
    "Accept-Profile": "app",
    "Content-Profile": "app",
    ...extra,
  };
}

async function noterStatut(rest: Rest, eventIds: string[], champs: Record<string, unknown>) {
  const res = await fetch(
    `${rest.url}/rest/v1/alertes_courriel_envois?event_id=in.(${eventIds.join(",")})`,
    { method: "PATCH", headers: entetes(rest, { Prefer: "return=minimal" }), body: JSON.stringify(champs) },
  );
  if (!res.ok) console.error("[COURRIEL] statut non noté", await res.text());
}

/**
 * Envoie la copie courriel. Ne lève jamais : un courriel raté ne doit pas
 * empêcher les push d'être marqués traités.
 */
export async function envoyerCopiesCourriel(alertes: AlerteCourriel[], rest: Rest): Promise<void> {
  if (!alertes.length) return;
  try {
    const cleResend = Deno.env.get("RESEND_API_KEY") ?? "";
    const expediteur = Deno.env.get("RESEND_FROM_EMAIL") ?? "";
    if (!cleResend || !expediteur) {
      console.warn(`[COURRIEL] ${alertes.length} alerte(s) admin sans copie : RESEND_API_KEY ou RESEND_FROM_EMAIL absent`);
      return;
    }

    const ids = [...new Set(alertes.map((a) => a.userId))];
    const resDest = await fetch(
      `${rest.url}/rest/v1/alertes_courriel_destinataires?actif=eq.true&user_id=in.(${ids.join(",")})&select=user_id,courriel`,
      { headers: entetes(rest) },
    );
    if (!resDest.ok) throw new Error(`destinataires: ${resDest.status} ${await resDest.text()}`);
    const courrielDe = new Map<string, string>(
      (await resDest.json()).map((d: { user_id: string; courriel: string }) => [d.user_id, d.courriel]),
    );

    const aReserver = alertes
      .filter((a) => courrielDe.has(a.userId))
      .map((a) => ({ event_id: a.eventId, user_id: a.userId, courriel: courrielDe.get(a.userId)! }));
    if (!aReserver.length) return;

    // Réservation : le cron et l'envoi immédiat peuvent lire le même événement
    // au même instant. ON CONFLICT DO NOTHING ne renvoie que les lignes
    // réellement insérées : seul le passage qui les a obtenues envoie.
    const resRes = await fetch(`${rest.url}/rest/v1/alertes_courriel_envois`, {
      method: "POST",
      headers: entetes(rest, { Prefer: "resolution=ignore-duplicates,return=representation" }),
      body: JSON.stringify(aReserver),
    });
    if (!resRes.ok) throw new Error(`reservation: ${resRes.status} ${await resRes.text()}`);
    const obtenus = new Set((await resRes.json()).map((r: { event_id: string }) => r.event_id));

    const parCourriel = new Map<string, AlerteCourriel[]>();
    for (const a of alertes) {
      if (!obtenus.has(a.eventId)) continue;
      const c = courrielDe.get(a.userId)!;
      parCourriel.set(c, [...(parCourriel.get(c) ?? []), a]);
    }

    for (const [courriel, lot] of parCourriel) {
      const eventIds = lot.map((a) => a.eventId);
      const { sujet, html } = composerCourriel(lot);
      try {
        const res = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: { Authorization: `Bearer ${cleResend}`, "Content-Type": "application/json" },
          body: JSON.stringify({ from: expediteur, to: [courriel], subject: sujet, html }),
        });
        const texte = await res.text();
        if (res.ok) {
          let resendId: string | null = null;
          try { resendId = JSON.parse(texte).id ?? null; } catch { /* corps inattendu */ }
          await noterStatut(rest, eventIds, { statut: "envoye", resend_id: resendId, envoye_at: new Date().toISOString() });
        } else {
          console.error("[COURRIEL] Resend a refusé", res.status, texte.slice(0, 300));
          await noterStatut(rest, eventIds, { statut: "echec", erreur: `${res.status} ${texte}`.slice(0, 500) });
        }
      } catch (e) {
        await noterStatut(rest, eventIds, { statut: "echec", erreur: String(e).slice(0, 500) });
      }
    }
  } catch (e) {
    console.error("[COURRIEL] copie non envoyée", e);
  }
}
