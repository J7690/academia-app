import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * Creation et catalogue des machines GPU RunPod.
 *
 * Elle existe parce que la console RunPod n'est atteignable ni par moi ni
 * confortablement par l'utilisateur. Elle fait les reglages a sa place, en
 * lisant `RUNPOD_API_KEY` dans les secrets Supabase -- la cle ne transite donc
 * par aucune machine que nous administrons, et personne n'a besoin de la voir.
 *
 * Deux actions :
 *   `catalogue` : lit les GPU disponibles et leurs tarifs. NE DEPENSE RIEN.
 *                 C'est ce qui permet d'annoncer un prix exact avant d'engager
 *                 quoi que ce soit.
 *   `creer`     : loue la machine. DEPENSE. Exige un plafond horaire explicite,
 *                 et refuse si une machine tourne deja.
 *
 * Toute machine creee est inscrite dans `app.gpu_pods` dans la foulee : elle
 * naît sous la surveillance du veilleur, jamais avant.
 */

const RUNPOD_GRAPHQL = "https://api.runpod.io/graphql";

async function appelRunpod(cle: string, query: string) {
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
      detail: corps?.errors?.[0]?.message ?? texte.slice(0, 400),
      corps,
    };
  } catch (e) {
    return { ok: false, detail: `reseau: ${e}`, corps: null };
  }
}

Deno.serve(async (req: Request) => {
  const cleRunpod = Deno.env.get("RUNPOD_API_KEY");
  const urlSupabase = Deno.env.get("SUPABASE_URL");
  const cleService = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!cleRunpod || !urlSupabase || !cleService) {
    return new Response(JSON.stringify({ success: false, error: "configuration_incomplete" }),
      { status: 500, headers: { "content-type": "application/json" } });
  }

  let corpsRequete: any = {};
  try { corpsRequete = await req.json(); } catch { /* corps vide accepte */ }
  const action = String(corpsRequete.action ?? "catalogue");

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

  // ── Catalogue : information seule, aucune depense ────────────────────────
  if (action === "catalogue") {
    const filtre = String(corpsRequete.filtre ?? "").toLowerCase();
    const r = await appelRunpod(cleRunpod, `query {
      gpuTypes {
        id
        displayName
        memoryInGb
        secureCloud
        communityCloud
        lowestPrice(input: {gpuCount: 1}) {
          uninterruptablePrice
          minimumBidPrice
        }
      }
    }`);

    if (!r.ok) {
      return new Response(JSON.stringify({ success: false, etape: "catalogue", detail: r.detail }),
        { status: 502, headers: { "content-type": "application/json" } });
    }

    const tous = (r.corps?.data?.gpuTypes ?? []) as any[];
    const retenus = tous
      .filter((g) => !filtre || String(g.displayName ?? "").toLowerCase().includes(filtre))
      .filter((g) => g?.lowestPrice?.uninterruptablePrice != null)
      .map((g) => ({
        id: g.id,
        nom: g.displayName,
        vram_go: g.memoryInGb,
        prix_heure: g.lowestPrice?.uninterruptablePrice,
        prix_encheres: g.lowestPrice?.minimumBidPrice,
        secure: g.secureCloud,
        communaute: g.communityCloud,
      }))
      .sort((a, b) => (a.prix_heure ?? 999) - (b.prix_heure ?? 999));

    return new Response(JSON.stringify({ success: true, total: tous.length, gpus: retenus }),
      { headers: { "content-type": "application/json" } });
  }

  // ── Creation : cela DEPENSE ──────────────────────────────────────────────
  if (action === "creer") {
    const gpuTypeId = String(corpsRequete.gpu_type_id ?? "");
    const plafond = Number(corpsRequete.plafond_horaire ?? 0);
    const nom = String(corpsRequete.nom ?? "academia-studio");
    const image = String(corpsRequete.image ?? "runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404");
    const disqueConteneur = Number(corpsRequete.disque_conteneur_go ?? 40);
    const disqueVolume = Number(corpsRequete.disque_volume_go ?? 20);

    if (!gpuTypeId || plafond <= 0) {
      return new Response(JSON.stringify({ success: false, error: "gpu_type_id et plafond_horaire obligatoires" }),
        { status: 400, headers: { "content-type": "application/json" } });
    }

    // Refus si une machine tourne deja : le cahier des charges impose une
    // seule tache GPU simultanee durant le prototype, et deux pods oublies
    // coutent deux fois.
    const dejaActifs = await appelRunpod(cleRunpod, `query { myself { pods { id desiredStatus } } }`);
    if (dejaActifs.ok) {
      const actifs = (dejaActifs.corps?.data?.myself?.pods ?? [])
        .filter((p: any) => String(p?.desiredStatus ?? "").toUpperCase() === "RUNNING");
      if (actifs.length > 0) {
        return new Response(JSON.stringify({
          success: false,
          error: "machine_deja_active",
          pods: actifs.map((p: any) => p.id),
        }), { status: 409, headers: { "content-type": "application/json" } });
      }
    }

    // Verification du tarif AVANT de louer : on ne depasse jamais le plafond
    // annonce, meme si les prix ont bouge depuis le catalogue.
    const tarif = await appelRunpod(cleRunpod, `query {
      gpuTypes(input: {id: "${gpuTypeId.replace(/"/g, "")}"}) {
        id displayName lowestPrice(input: {gpuCount: 1}) { uninterruptablePrice }
      }
    }`);
    const prix = tarif.corps?.data?.gpuTypes?.[0]?.lowestPrice?.uninterruptablePrice;
    if (typeof prix !== "number") {
      return new Response(JSON.stringify({ success: false, error: "tarif_illisible", detail: tarif.detail }),
        { status: 502, headers: { "content-type": "application/json" } });
    }
    if (prix > plafond) {
      return new Response(JSON.stringify({
        success: false, error: "tarif_superieur_au_plafond",
        prix_constate: prix, plafond,
      }), { status: 412, headers: { "content-type": "application/json" } });
    }

    const creation = await appelRunpod(cleRunpod, `mutation {
      podFindAndDeployOnDemand(input: {
        cloudType: ALL,
        gpuCount: 1,
        volumeInGb: ${disqueVolume},
        containerDiskInGb: ${disqueConteneur},
        gpuTypeId: "${gpuTypeId.replace(/"/g, "")}",
        name: "${nom.replace(/[^A-Za-z0-9 _-]/g, "")}",
        imageName: "${image.replace(/"/g, "")}",
        ports: "22/tcp",
        volumeMountPath: "/workspace"
      }) { id name costPerHr machineId }
    }`);

    if (!creation.ok) {
      return new Response(JSON.stringify({ success: false, etape: "creation", detail: creation.detail }),
        { status: 502, headers: { "content-type": "application/json" } });
    }

    const pod = creation.corps?.data?.podFindAndDeployOnDemand;
    if (!pod?.id) {
      return new Response(JSON.stringify({ success: false, error: "aucun_pod_retourne", detail: creation.detail }),
        { status: 502, headers: { "content-type": "application/json" } });
    }

    // Inscription immediate : la machine naît sous surveillance.
    await rpc("gpu_pod_inscrire_decouvert", {
      p_pod_id: String(pod.id),
      p_label: pod.name ?? nom,
      p_gpu: gpuTypeId,
      p_cout: typeof pod.costPerHr === "number" ? pod.costPerHr : prix,
    });

    return new Response(JSON.stringify({
      success: true,
      pod_id: pod.id,
      nom: pod.name,
      cout_heure: pod.costPerHr ?? prix,
    }), { headers: { "content-type": "application/json" } });
  }

  return new Response(JSON.stringify({ success: false, error: "action_inconnue" }),
    { status: 400, headers: { "content-type": "application/json" } });
});
