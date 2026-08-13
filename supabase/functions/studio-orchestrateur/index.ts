import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * Orchestrateur du Studio visuel — la file cree la machine, plus l'humain.
 *
 * Appele toutes les trois minutes par pg_cron. Une seule decision : faut-il
 * louer une machine maintenant ?
 *
 * AUTANT DE MACHINES QUE DE TRAVAIL — depuis le 07/08/2026.
 *
 * La regle « jamais deux machines » datait du prototype. Mesure qui l'a fait
 * tomber : une capsule 3D demande 75 a 82 minutes sur un seul A40, et le
 * deuxieme etudiant attendait la fin du premier. Deux cours = plus de deux
 * heures. On compare donc le travail en attente aux machines actives, et on
 * cree la difference, en une seule fois.
 *
 * CE QUI BORNE, MAINTENANT :
 *
 *   1. Le travail reel. Jamais plus de machines qu'il n'y a de travaux en
 *      attente. Une machine sans file est une machine qui facture pour rien.
 *   2. Le veilleur. Toute machine oisive dix minutes est eteinte.
 *   3. Une borne absolue (MACHINES_MAX), qui n'existe que pour qu'une boucle
 *      folle ne puisse pas creer des machines a l'infini.
 *
 * On interroge RunPod lui-meme, pas seulement notre table : une machine creee
 * hors de ce circuit travaille -- et facture -- tout autant.
 *
 * L'orchestrateur ne fait PAS l'installation. Un pod neuf ne contient ni
 * Blender ni nos scripts, et cette Edge Function ne peut pas s'y connecter en
 * SSH. C'est LWS qui amorce, parce qu'il detient la cle -- voir
 * `studio_amorceur.py`. Chaque moitie garde son secret : la cle RunPod ici, la
 * cle SSH la-bas.
 */

const RUNPOD_GRAPHQL = "https://api.runpod.io/graphql";

// PLAFONDS LEVES LE 07/08/2026, sur decision de Jocelyn.
//
// Les valeurs precedentes -- 5 $/jour et 0,50 $/h -- dataient du prototype et
// bornaient la production a UNE machine, donc a un seul etudiant servi a la
// fois. Mesure du 07/08 : une capsule 3D demande 75 a 82 minutes sur un seul
// A40, et le second etudiant attendait son tour. Intenable.
//
// Le garde-fou n'a pas disparu, il a change de nature : ce n'est plus un
// plafond de depense mais le TRAVAIL REEL qui borne le nombre de machines --
// on n'en cree jamais plus qu'il n'y a de travaux en attente, et le veilleur
// eteint toute machine oisive au bout de dix minutes.
const PLAFOND_JOUR_USD = Number(Deno.env.get("STUDIO_PLAFOND_JOUR") ?? "60");
const PLAFOND_HORAIRE_USD = Number(Deno.env.get("STUDIO_PLAFOND_HEURE") ?? "6");
// Borne de securite absolue : elle n'existe que pour qu'une boucle folle ne
// puisse pas creer des machines a l'infini. Elle n'est jamais atteinte en
// usage normal, puisque le nombre de machines suit le nombre de travaux.
const MACHINES_MAX = Number(Deno.env.get("STUDIO_MACHINES_MAX") ?? "12");
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

Deno.serve(async (req: Request) => {
  // Le corps permet de MESURER : choisir un autre GPU que le defaut, et forcer
  // une machine sans travail en file. Rien de tout cela n'est utilise par le
  // cron -- qui appelle avec un corps vide -- mais sans cette porte, comparer
  // A40 et RTX 4090 sur notre propre moteur serait impossible.
  let corpsEntrant: any = {};
  try { corpsEntrant = await req.json(); } catch { /* corps vide : cas nominal */ }
  const gpuDemande = typeof corpsEntrant?.gpu === "string" && corpsEntrant.gpu.trim()
    ? corpsEntrant.gpu.trim() : GPU;
  const forcer = corpsEntrant?.forcer === true;
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
  if (Number(etat.en_attente ?? 0) === 0 && !forcer) {
    return new Response(JSON.stringify({ success: true, action: "rien", ...etat }),
      { headers: { "content-type": "application/json" } });
  }

  // ── Combien de machines MANQUE-T-IL ? ─────────────────────────────────
  //
  // On ne refuse plus des qu'une machine tourne. On compare le travail en
  // attente aux machines disponibles, et on cree la difference : plusieurs
  // etudiants sont donc servis EN MEME TEMPS au lieu de faire la queue.
  //
  // Mesure du 07/08 qui a impose ce changement : une capsule 3D demande 75 a
  // 82 minutes sur un seul A40, et le deuxieme etudiant attendait la fin du
  // premier -- soit plus de deux heures pour deux cours.
  //
  // On interroge RunPod lui-meme plutot que notre table : une machine creee
  // hors de ce circuit travaille, et facture, tout autant.
  let actives = 0;
  const liste = await appelRunpod(cleRunpod, `query { myself { pods { id desiredStatus } } }`);
  if (!liste.ok) {
    // Liste illisible : on ne cree RIEN plutot que de risquer des doublons
    // qu'on ne verrait pas. Le passage suivant reessaiera.
    return new Response(JSON.stringify({
      success: false, action: "liste_runpod_illisible", detail: liste.detail, ...etat,
    }), { status: 503, headers: { "content-type": "application/json" } });
  }
  actives = (liste.corps?.data?.myself?.pods ?? [])
    .filter((p: any) => String(p?.desiredStatus ?? "").toUpperCase() === "RUNNING").length;

  const attente = forcer ? Math.max(1, Number(etat.en_attente ?? 0))
                         : Number(etat.en_attente ?? 0);
  const manquantes = Math.min(attente - actives, MACHINES_MAX - actives);
  if (manquantes <= 0) {
    return new Response(JSON.stringify({
      success: true, action: "machines_suffisantes",
      actives, en_attente: attente, ...etat,
    }), { headers: { "content-type": "application/json" } });
  }

  // ── Refus 3 : plafond quotidien ───────────────────────────────────────
  if (Number(etat.depense_24h ?? 0) >= PLAFOND_JOUR_USD) {
    return new Response(JSON.stringify({
      success: false, action: "plafond_quotidien_atteint",
      plafond: PLAFOND_JOUR_USD, ...etat,
    }), { status: 429, headers: { "content-type": "application/json" } });
  }

  // ── Creation ──────────────────────────────────────────────────────────
  // PLUSIEURS cles, une par ligne : celle de LWS pour amorcer la machine,
  // celle du poste de developpement pour pouvoir diagnostiquer. Une validation
  // mono-ligne aurait rejete l'ensemble, et un retour a la ligne brut casserait
  // la requete GraphQL -- d'ou l'echappement en `\n` litteral.
  const lignes = (Deno.env.get("STUDIO_CLE_PUBLIQUE") ?? "")
    .split("\n").map((l) => l.trim()).filter(Boolean);
  const valides = lignes.filter((l) => /^ssh-(ed25519|rsa) [A-Za-z0-9+/=]+( \S+)?$/.test(l));

  if (valides.length === 0) {
    // Sans cle publique, l'image ne demarre pas sshd : la machine facturerait
    // sans etre joignable, donc sans jamais pouvoir etre amorcee.
    return new Response(JSON.stringify({
      success: false, error: "STUDIO_CLE_PUBLIQUE absente ou invalide",
      lignes_lues: lignes.length,
    }), { status: 500, headers: { "content-type": "application/json" } });
  }
  const clePublique = valides.join("\\n").replace(/"/g, "");

  // ── Creation EN LOT ───────────────────────────────────────────────────
  // Autant de machines qu'il en manque, d'un seul passage. Les creer une par
  // une au rythme du cron aurait demande trois minutes PAR machine : servir
  // cinq etudiants aurait pris un quart d'heure rien qu'en allocation.
  const creees: unknown[] = [];
  const echecs: unknown[] = [];

  for (let i = 0; i < manquantes; i++) {
    const creation = await appelRunpod(cleRunpod, `mutation {
      podFindAndDeployOnDemand(input: {
        cloudType: SECURE, gpuCount: 1,
        volumeInGb: 20, containerDiskInGb: 30,
        gpuTypeId: "${gpuDemande}",
        name: "academia-studio-auto",
        imageName: "${IMAGE}",
        ports: "22/tcp",
        volumeMountPath: "/workspace",
        env: [{key: "PUBLIC_KEY", value: "${clePublique}"}]
      }) { id name costPerHr }
    }`);

    const pod = creation.corps?.data?.podFindAndDeployOnDemand;
    if (!creation.ok || !pod?.id) {
      // Plus de A40 disponible chez RunPod, par exemple. On garde celles
      // obtenues et on s'arrete la : le passage suivant reessaiera.
      echecs.push({ rang: i, detail: creation.detail });
      break;
    }

    const cout = typeof pod.costPerHr === "number" ? pod.costPerHr : 0.44;

    // Le tarif reel n'est connu qu'apres coup : le catalogue annonce le prix
    // le plus bas, la machine attribuee peut couter davantage.
    if (cout > PLAFOND_HORAIRE_USD) {
      await appelRunpod(cleRunpod, `mutation { podTerminate(input: {podId: "${pod.id}"}) }`);
      echecs.push({ rang: i, action: "tarif_trop_eleve_annule", cout });
      break;
    }

    // Inscription immediate : la machine nait sous la surveillance du veilleur.
    await rpc("gpu_pod_inscrire_decouvert", {
      p_pod_id: String(pod.id), p_label: pod.name ?? "academia-studio-auto",
      p_gpu: gpuDemande, p_cout: cout,
    });
    creees.push({ pod_id: pod.id, cout_heure: cout });
  }

  return new Response(JSON.stringify({
    success: creees.length > 0,
    action: creees.length > 0 ? "machines_creees" : "aucune_machine_obtenue",
    demandees: manquantes, obtenues: creees.length,
    machines: creees, echecs, actives_avant: actives, ...etat,
  }), {
    status: creees.length > 0 ? 200 : 502,
    headers: { "content-type": "application/json" },
  });
});
