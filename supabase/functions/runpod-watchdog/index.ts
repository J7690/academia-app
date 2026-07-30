import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * Veilleur des machines GPU louees.
 *
 * Appele toutes les deux minutes par pg_cron. Trois temps :
 *   1. DECOUVERTE   : il demande sa liste de pods a RunPod. Un pod cree a la
 *                     main dans la console est donc protege des la minute
 *                     suivante, sans que personne ait rien a declarer.
 *   2. RECONCILIATION : ce que nous croyons actif mais que RunPod ne liste plus
 *                     est marque eteint -- notre table cesse de mentir.
 *   3. EXTINCTION   : les pods qui facturent sans produire sont coupes.
 *
 * DEUX MODES, et la distinction est importante. Un pod de prototypage n'a pas
 * d'agent : on installe ComfyUI et Blender a la main, en SSH, pendant des
 * heures. Un veilleur qui tue apres dix minutes de silence detruirait ce
 * travail. Les pods decouverts sont donc en mode `manuel` -- seule la duree
 * maximale s'applique. Un pod bascule en `auto`, regles serrees, des que son
 * agent envoie un premier battement de coeur : il a prouve qu'il existe.
 *
 * Il vit chez Supabase et non sur LWS pour une raison simple : si le VPS tombe,
 * le pod GPU continuerait de facturer. Supabase survit aux deux. Consequence
 * heureuse, la cle RunPod n'existe qu'a un seul endroit et ne touche aucune
 * machine que nous administrons.
 */

const RUNPOD_GRAPHQL = "https://api.runpod.io/graphql";

type Resultat = { ok: boolean; detail: string; corps: any };

async function appelRunpod(cle: string, query: string): Promise<Resultat> {
  try {
    const r = await fetch(`${RUNPOD_GRAPHQL}?api_key=${encodeURIComponent(cle)}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ query }),
    });
    const texte = await r.text();
    let corps: any = null;
    try { corps = JSON.parse(texte); } catch { /* reponse non JSON */ }
    const enErreur = !r.ok || (corps?.errors?.length ?? 0) > 0;
    return {
      ok: !enErreur,
      detail: corps?.errors?.[0]?.message ?? texte.slice(0, 300),
      corps,
    };
  } catch (e) {
    return { ok: false, detail: `reseau: ${e}`, corps: null };
  }
}

/**
 * On n'interroge que des champs dont la syntaxe est confirmee. Un champ
 * inconnu ferait echouer TOUTE la requete GraphQL -- et desactiverait la
 * decouverte en silence, ce qui est exactement la panne qu'on ne verrait pas.
 */
async function listerPods(cle: string) {
  const r = await appelRunpod(cle, `query { myself { pods { id name desiredStatus costPerHr } } }`);
  if (!r.ok) return { ok: false, pods: [] as any[], detail: r.detail };
  const pods = r.corps?.data?.myself?.pods;
  if (!Array.isArray(pods)) return { ok: false, pods: [] as any[], detail: "liste_illisible" };
  return { ok: true, pods, detail: "" };
}

/**
 * `podTerminate` d'abord : c'est le seul qui ramene la facture a zero.
 * `podStop` en repli : il conserve le disque, donc continue de couter un peu,
 * mais libere le GPU qui est de loin le poste le plus cher.
 */
async function eteindre(cle: string, podId: string) {
  const t = await appelRunpod(cle, `mutation { podTerminate(input: {podId: "${podId}"}) }`);
  if (t.ok) return { ok: true, methode: "terminate", note: "" };

  const s = await appelRunpod(cle, `mutation { podStop(input: {podId: "${podId}"}) { id desiredStatus } }`);
  if (s.ok) return { ok: true, methode: "stop", note: `terminate refuse: ${t.detail}` };

  return { ok: false, methode: "aucune", note: `${t.detail} || ${s.detail}` };
}

Deno.serve(async () => {
  const cleRunpod = Deno.env.get("RUNPOD_API_KEY");
  const urlSupabase = Deno.env.get("SUPABASE_URL");
  const cleService = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!cleRunpod || !urlSupabase || !cleService) {
    return new Response(
      JSON.stringify({ success: false, error: "configuration_incomplete" }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }

  const rpc = async (nom: string, corps: unknown = {}) => {
    const r = await fetch(`${urlSupabase}/rest/v1/rpc/${nom}`, {
      method: "POST",
      headers: {
        apikey: cleService,
        Authorization: `Bearer ${cleService}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(corps),
    });
    return r.ok ? await r.json() : null;
  };

  const rapport: Record<string, unknown> = {};

  // ── 1. Decouverte ────────────────────────────────────────────────────────
  const liste = await listerPods(cleRunpod);
  rapport.liste_runpod = liste.ok ? liste.pods.length : `echec: ${liste.detail}`;

  if (liste.ok) {
    const actifs = liste.pods.filter((p: any) =>
      String(p?.desiredStatus ?? "").toUpperCase() === "RUNNING"
    );

    for (const p of actifs) {
      await rpc("gpu_pod_inscrire_decouvert", {
        p_pod_id: String(p.id ?? ""),
        p_label: p.name ?? null,
        p_gpu: null,
        p_cout: typeof p.costPerHr === "number" ? p.costPerHr : null,
      });
    }
    rapport.actifs_chez_runpod = actifs.length;

    // ── 2. Reconciliation ──────────────────────────────────────────────────
    // Uniquement si la liste a bien ete obtenue : sinon une panne reseau
    // ferait croire que toutes les machines ont disparu.
    rapport.reconciliation = await rpc("gpu_pods_reconcilier", {
      p_presents: actifs.map((p: any) => String(p.id ?? "")),
    });
  }

  // ── 3. Extinction ────────────────────────────────────────────────────────
  const cibles = await rpc("gpu_pods_a_eteindre");
  if (!Array.isArray(cibles)) {
    return new Response(
      JSON.stringify({ success: false, error: "lecture_impossible", rapport }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }

  const journal: unknown[] = [];

  for (const cible of cibles) {
    const podId = String(cible.pod_id ?? "");
    // Le podId part dans une chaine GraphQL : on refuse tout ce qui n'est pas
    // un identifiant, plutot que d'echapper approximativement.
    if (!/^[A-Za-z0-9_-]{1,64}$/.test(podId)) {
      journal.push({ pod_id: podId, ok: false, note: "identifiant_invalide" });
      continue;
    }

    const issue = await eteindre(cleRunpod, podId);

    // Marque meme en cas d'echec : le statut `orphan` fait remonter les pods
    // que nous n'avons PAS reussi a eteindre, ceux qui coutent vraiment.
    await rpc("gpu_pod_marquer_eteint", {
      p_pod_id: podId,
      p_raison: `${cible.raison} (${issue.methode})${issue.note ? " — " + issue.note : ""}`,
      p_reussi: issue.ok,
    });

    journal.push({
      pod_id: podId,
      raison: cible.raison,
      age_minutes: cible.age_minutes,
      ok: issue.ok,
      methode: issue.methode,
      note: issue.note,
    });
  }

  rapport.eteints = journal;
  return new Response(
    JSON.stringify({ success: true, ...rapport }),
    { headers: { "content-type": "application/json" } },
  );
});
