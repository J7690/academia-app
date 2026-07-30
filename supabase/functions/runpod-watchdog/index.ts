import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * Veilleur des machines GPU louees.
 *
 * Appele toutes les deux minutes par pg_cron. Il eteint les pods qui facturent
 * sans produire, selon trois causes distinctes calculees en base :
 *   - `agent_muet`              : plus de battement de coeur, l'agent est mort
 *   - `inactif`                 : vivant mais sans travail depuis trop longtemps
 *   - `duree_maximale_depassee` : filet absolu, quoi qu'il arrive
 *
 * Il vit ici et non sur LWS pour une raison simple : si le VPS tombe, le pod
 * GPU continuerait de facturer. Supabase survit aux deux. Consequence
 * heureuse, la cle RunPod n'existe qu'a un seul endroit -- les secrets
 * Supabase -- et ne touche aucune machine que nous administrons.
 */

const RUNPOD_GRAPHQL = "https://api.runpod.io/graphql";

type Resultat = { ok: boolean; detail: string };

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
    };
  } catch (e) {
    return { ok: false, detail: `reseau: ${e}` };
  }
}

/**
 * On tente `podTerminate` d'abord : c'est le seul qui ramene la facture a zero.
 * `podStop` conserve le disque, donc continue de couter -- mais il libere le
 * GPU, qui est de loin le poste le plus cher. En repli, c'est bien mieux que
 * rien.
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

  const cibles = await rpc("gpu_pods_a_eteindre");
  if (!Array.isArray(cibles)) {
    return new Response(
      JSON.stringify({ success: false, error: "lecture_impossible" }),
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

  return new Response(
    JSON.stringify({ success: true, examines: cibles.length, journal }),
    { headers: { "content-type": "application/json" } },
  );
});
