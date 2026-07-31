import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * Orchestrateur du Studio visuel — la file cree la machine, plus l'humain.
 *
 * Appele toutes les trois minutes par pg_cron. Une seule decision : faut-il
 * louer une machine maintenant ?
 *
 * TROIS REFUS, ET CHACUN A COUTE QUELQUE CHOSE POUR ETRE COMPRIS.
 *
 *   1. Jamais deux machines. Le cahier des charges impose une seule tache GPU
 *      pendant le prototype, et deux pods oublies coutent deux fois. On
 *      interroge RunPod lui-meme, pas seulement notre table : une machine
 *      creee hors de ce circuit doit aussi compter.
 *   2. Jamais sans travail en attente. Une machine sans file est une machine
 *      qui facture pour rien.
 *   3. Jamais au-dela du plafond quotidien. C'est le garde-fou qui manque
 *      partout ailleurs : sans lui, une boucle de jobs en echec relancerait
 *      indefiniment des machines.
 *
 * L'orchestrateur ne fait PAS l'installation. Un pod neuf ne contient ni
 * Blender ni nos scripts, et cette Edge Function ne peut pas s'y connecter en
 * SSH. C'est LWS qui amorce, parce qu'il detient la cle -- voir
 * `studio_amorceur.py`. Chaque moitie garde son secret : la cle RunPod ici, la
 * cle SSH la-bas.
 */

const RUNPOD_GRAPHQL = "https://api.runpod.io/graphql";

// Plafond quotidien. A 0,44 $/h, cela borne la depense automatique a environ
// onze heures de machine par jour -- largement au-dessus d'un usage editorial
// normal, et tres en-dessous d'un emballement.
const PLAFOND_JOUR_USD = 5.0;
const PLAFOND_HORAIRE_USD = 0.50;
const GPU = "NVIDIA A40";
const IMAGE = "runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404";

async function appelRunpod(cle: string, query: string) {
  try {
    const r = await fetch(`${RUNPOD_GRAPHQL}?api_key=${encodeURIComponent(cle)}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ query }),
    });
    const texte = await r.text();
    let corps: any = null;
    try { corps = JSON.parse(texte); } catch { /* non JSON */ }
    return {
      ok: r.ok && !(corps?.errors?.length),
      detail: corps?.errors?.[0]?.message ?? texte.slice(0, 300),
      corps,
    };
  } catch (e) {
    return { ok: false, detail: `reseau: ${e}`, corps: null };
  }
}

Deno.serve(async () => {
  const cleRunpod = Deno.env.get("RUNPOD_API_KEY");
  const urlSupabase = Deno.env.get("SUPABASE_URL");
  const cleService = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!cleRunpod || !urlSupabase || !cleService) {
    return new Response(JSON.stringify({ success: false, error: "configuration_incomplete" }),
      { status: 500, headers: { "content-type": "application/json" } });
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

  const etat = await rpc("studio_etat_file");
  if (!etat) {
    return new Response(JSON.stringify({ success: false, error: "etat_illisible" }),
      { status: 500, headers: { "content-type": "application/json" } });
  }

  // ── Refus 2 : rien a faire ────────────────────────────────────────────
  if (Number(etat.en_attente ?? 0) === 0) {
    return new Response(JSON.stringify({ success: true, action: "rien", ...etat }),
      { headers: { "content-type": "application/json" } });
  }

  // ── Refus 1 : une machine tourne deja ─────────────────────────────────
  // On demande a RunPod plutot que de croire notre table : une machine creee
  // hors de ce circuit facture tout autant.
  const liste = await appelRunpod(cleRunpod, `query { myself { pods { id desiredStatus } } }`);
  if (liste.ok) {
    const actifs = (liste.corps?.data?.myself?.pods ?? [])
      .filter((p: any) => String(p?.desiredStatus ?? "").toUpperCase() === "RUNNING");
    if (actifs.length > 0) {
      return new Response(JSON.stringify({
        success: true, action: "machine_deja_active",
        pods: actifs.map((p: any) => p.id), ...etat,
      }), { headers: { "content-type": "application/json" } });
    }
  }

  // ── Refus 3 : plafond quotidien ───────────────────────────────────────
  if (Number(etat.depense_24h ?? 0) >= PLAFOND_JOUR_USD) {
    return new Response(JSON.stringify({
      success: false, action: "plafond_quotidien_atteint",
      plafond: PLAFOND_JOUR_USD, ...etat,
    }), { status: 429, headers: { "content-type": "application/json" } });
  }

  // ── Creation ──────────────────────────────────────────────────────────
  const clePublique = Deno.env.get("STUDIO_CLE_PUBLIQUE") ?? "";
  if (!/^ssh-(ed25519|rsa) [A-Za-z0-9+/=]+( \S+)?$/.test(clePublique.trim())) {
    // Sans cle publique, l'image ne demarre pas sshd : la machine facturerait
    // sans etre joignable, donc sans jamais pouvoir etre amorcee.
    return new Response(JSON.stringify({
      success: false, error: "STUDIO_CLE_PUBLIQUE absente ou invalide",
    }), { status: 500, headers: { "content-type": "application/json" } });
  }

  const creation = await appelRunpod(cleRunpod, `mutation {
    podFindAndDeployOnDemand(input: {
      cloudType: SECURE, gpuCount: 1,
      volumeInGb: 20, containerDiskInGb: 30,
      gpuTypeId: "${GPU}",
      name: "academia-studio-auto",
      imageName: "${IMAGE}",
      ports: "22/tcp",
      volumeMountPath: "/workspace",
      env: [{key: "PUBLIC_KEY", value: "${clePublique.trim().replace(/"/g, "")}"}]
    }) { id name costPerHr }
  }`);

  const pod = creation.corps?.data?.podFindAndDeployOnDemand;
  if (!creation.ok || !pod?.id) {
    return new Response(JSON.stringify({
      success: false, action: "creation_echouee", detail: creation.detail, ...etat,
    }), { status: 502, headers: { "content-type": "application/json" } });
  }

  const cout = typeof pod.costPerHr === "number" ? pod.costPerHr : 0.44;

  // Le tarif reel n'est connu qu'apres coup : le catalogue annonce le prix le
  // plus bas, la machine attribuee peut couter davantage. On defait plutot que
  // de laisser tourner au mauvais tarif.
  if (cout > PLAFOND_HORAIRE_USD) {
    await appelRunpod(cleRunpod, `mutation { podTerminate(input: {podId: "${pod.id}"}) }`);
    return new Response(JSON.stringify({
      success: false, action: "tarif_trop_eleve_annule",
      cout, plafond: PLAFOND_HORAIRE_USD,
    }), { status: 412, headers: { "content-type": "application/json" } });
  }

  // Inscription immediate : la machine naît sous la surveillance du veilleur.
  await rpc("gpu_pod_inscrire_decouvert", {
    p_pod_id: String(pod.id), p_label: pod.name ?? "academia-studio-auto",
    p_gpu: GPU, p_cout: cout,
  });

  return new Response(JSON.stringify({
    success: true, action: "machine_creee",
    pod_id: pod.id, cout_heure: cout, ...etat,
  }), { headers: { "content-type": "application/json" } });
});
