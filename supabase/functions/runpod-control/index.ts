import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * runpod-control — le plan de controle des machines. Idempotent.
 *
 * POURQUOI CETTE FONCTION EXISTE.
 * L'orchestrateur savait CREER une machine, le veilleur savait en TUER une, et
 * personne ne savait ni en demarrer une arretee, ni lire son etat reel. Le
 * cycle de vie n'existait donc pas : une machine vivait jusqu'a son plafond de
 * 240 minutes. Quatre l'ont fait, de 1,35 a 1,77 $ chacune, sans rien rendre.
 *
 * TROIS VERITES, TROIS AUTORITES — ne jamais les confondre :
 *
 *   le travail demande   ->  app.studio_jobs                  (la file)
 *   l'etat SOUHAITE      ->  app.gpu_pods.desired_state       (Supabase)
 *   l'etat REEL          ->  l'API RunPod                     (observed_state)
 *
 * La machine ne decide plus de sa propre vie. C'est ce qui manquait a
 * `agent_pod.sh`, qui deduisait « occupe » d'une ecriture disque ou d'une
 * session SSH ouverte -- et empechait ainsi toute extinction.
 *
 * DEUX PROTECTIONS CONTRE LES COURSES.
 *
 *   1. `control_generation`. Sequence dangereuse : le controleur constate la
 *      file vide, une tache arrive, et l'ordre d'arret part quand meme. On
 *      relit donc la generation JUSTE AVANT d'appeler RunPod ; si elle a bouge,
 *      l'ordre est caduc et on ne fait rien.
 *   2. La readiness. « RUNNING » chez RunPod ne veut pas dire « sait rendre » :
 *      un pod peut demarrer avec ZERO GPU (documente par RunPod), ou avec
 *      Chromium retombe en silence sur SwiftShader. Une machine n'est
 *      disponible qu'apres avoir rendu une image de test non vide.
 *
 * ZERO GPU : ON REMPLACE, ON NE TERMINE PAS D'ABORD.
 * Un pod arrete reste lie a sa machine d'origine et peut redemarrer sans carte
 * si elle a ete reallouee. Dans ce cas on CREE un remplacant, et on ne termine
 * l'ancien qu'apres -- son volume porte peut-etre des images pas encore
 * deposees.
 *
 * Corps attendu : { "action": "etat" | "demarrer" | "arreter" | "creer" | "terminer",
 *                   "pod_id"?: string, "gpu"?: string, "generation"?: number }
 */

const RUNPOD_REST = "https://rest.runpod.io/v1";
const RUNPOD_GRAPHQL = "https://api.runpod.io/graphql";

const GPU_DEFAUT = Deno.env.get("STUDIO_GPU") ?? "NVIDIA GeForce RTX 4090";
// L'IMAGE AUTONOME, publiee le 12/08/2026. Ce n'est pas un secret : c'est un nom
// de depot, et le mettre en defaut evite de dependre d'une variable que personne
// n'aura posee le jour ou l'on redeploie.
//
// Elle contient Blender 4.5.12, Node 20, Chromium, ffmpeg, la couche EGL et le
// moteur. Elle existe parce que RunPod EFFACE le disque du conteneur a chaque
// arret : avec l'ancienne image, un pod redemarre revenait nu, et l'arret
// automatique serait devenu une panne au lieu d'une economie.
const IMAGE = Deno.env.get("STUDIO_IMAGE") ?? "academia0/academia-studio:1.1.1";
// La version que la sonde du conteneur doit annoncer. Un pod qui rendrait avec
// une autre version se declare NON PRET : mieux vaut une machine refusee qu'une
// capsule rendue par un moteur qu'on croyait remplace.
const VERSION_ATTENDUE = Deno.env.get("STUDIO_VERSION_MOTEUR") ?? "1.1.1";
const MACHINES_MAX = Number(Deno.env.get("STUDIO_MACHINES_MAX") ?? "12");
const PLAFOND_HORAIRE_USD = Number(Deno.env.get("STUDIO_PLAFOND_HEURE") ?? "6");

type Reponse = { ok: boolean; detail: string; corps: unknown };

async function rest(cle: string, chemin: string, methode = "GET"): Promise<Reponse> {
  try {
    const r = await fetch(`${RUNPOD_REST}${chemin}`, {
      method: methode,
      headers: { authorization: `Bearer ${cle}`, "content-type": "application/json" },
    });
    const texte = await r.text();
    let corps: unknown = null;
    try { corps = JSON.parse(texte); } catch { /* non JSON */ }
    return { ok: r.ok, detail: r.ok ? "" : `${r.status} ${texte.slice(0, 200)}`, corps };
  } catch (e) {
    return { ok: false, detail: `reseau: ${e}`, corps: null };
  }
}

// La creation reste en GraphQL : `podFindAndDeployOnDemand` cherche une machine
// libre chez tous les fournisseurs, ce que l'API REST ne fait pas.
async function graphql(cle: string, requete: string): Promise<Reponse> {
  try {
    const r = await fetch(`${RUNPOD_GRAPHQL}?api_key=${encodeURIComponent(cle)}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ query: requete }),
    });
    const texte = await r.text();
    let corps: any = null;
    try { corps = JSON.parse(texte); } catch { /* non JSON */ }
    return {
      ok: r.ok && !(corps?.errors?.length),
      detail: corps?.errors?.[0]?.message ?? (r.ok ? "" : texte.slice(0, 200)),
      corps,
    };
  } catch (e) {
    return { ok: false, detail: `reseau: ${e}`, corps: null };
  }
}

/** Combien de cartes ce pod a-t-il REELLEMENT ? Zero est un cas nominal. */
function nombreGpu(pod: any): number {
  return Number(pod?.gpuCount ?? pod?.machine?.gpuCount ?? (pod?.gpus?.length ?? 0)) || 0;
}

Deno.serve(async (req: Request) => {
  const cleRunpod = Deno.env.get("RUNPOD_API_KEY");
  const urlSupabase = Deno.env.get("SUPABASE_URL");
  const cleService = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!cleRunpod || !urlSupabase || !cleService) {
    return json({ success: false, error: "configuration_incomplete" }, 500);
  }

  let corps: any = {};
  try { corps = await req.json(); } catch { /* corps vide */ }
  const action = String(corps?.action ?? "etat");
  const podId = typeof corps?.pod_id === "string" ? corps.pod_id.trim() : "";
  const gpu = typeof corps?.gpu === "string" && corps.gpu.trim() ? corps.gpu.trim() : GPU_DEFAUT;

  // Le podId part dans une URL et dans du GraphQL : on refuse tout ce qui n'est
  // pas un identifiant, plutot que d'echapper approximativement.
  if (podId && !/^[A-Za-z0-9_-]{1,64}$/.test(podId)) {
    return json({ success: false, error: "pod_id_invalide" }, 400);
  }

  const rpc = async (nom: string, arg: unknown = {}) => {
    const r = await fetch(`${urlSupabase}/rest/v1/rpc/${nom}`, {
      method: "POST",
      headers: {
        apikey: cleService, Authorization: `Bearer ${cleService}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(arg),
    });
    return r.ok ? await r.json() : null;
  };

  const lire = async (chemin: string) => {
    const r = await fetch(`${urlSupabase}/rest/v1/${chemin}`, {
      headers: {
        apikey: cleService, Authorization: `Bearer ${cleService}`,
        "Accept-Profile": "app",
      },
    });
    return r.ok ? await r.json() : null;
  };

  // ── etat ───────────────────────────────────────────────────────────────
  if (action === "etat") {
    if (!podId) return json({ success: false, error: "pod_id_requis" }, 400);
    const r = await rest(cleRunpod, `/pods/${podId}`);
    const pod: any = r.corps ?? {};
    const observed = String(pod?.desiredStatus ?? pod?.status ?? "INCONNU").toUpperCase();
    if (r.ok) {
      await rpc("gpu_pod_observer", {
        p_pod_id: podId, p_observed: observed, p_gpu_count: nombreGpu(pod),
      });
    }
    return json({
      success: r.ok, action, pod_id: podId,
      observed_state: observed, gpu_count: nombreGpu(pod), detail: r.detail,
    }, r.ok ? 200 : 502);
  }

  // ── demarrer ───────────────────────────────────────────────────────────
  // Idempotent : si le pod tourne deja, on ne fait rien et on le dit.
  if (action === "demarrer") {
    if (!podId) return json({ success: false, error: "pod_id_requis" }, 400);

    const avant = await rest(cleRunpod, `/pods/${podId}`);
    const etatAvant = String((avant.corps as any)?.desiredStatus ?? "").toUpperCase();
    if (etatAvant === "RUNNING") {
      return json({ success: true, action, pod_id: podId, note: "deja_en_marche" });
    }

    const r = await rest(cleRunpod, `/pods/${podId}/start`, "POST");
    if (!r.ok) {
      return json({ success: false, action, pod_id: podId, detail: r.detail }, 502);
    }

    // LA VERIFICATION QUI COMPTE. Un pod peut demarrer AVEC ZERO CARTE si la
    // machine d'origine a ete reallouee. Sans ce controle, l'etudiant
    // attendrait devant une machine « demarree » incapable de rendre.
    const apres = await rest(cleRunpod, `/pods/${podId}`);
    const cartes = nombreGpu(apres.corps);
    if (cartes < 1) {
      await rpc("gpu_pod_observer", {
        p_pod_id: podId, p_observed: "ZERO_GPU", p_gpu_count: 0,
      });
      // On ne termine PAS l'ancien ici : son volume porte peut-etre des images
      // pas encore deposees. Le remplacement d'abord, la terminaison ensuite,
      // et seulement une fois les donnees en securite.
      return json({
        success: false, action, pod_id: podId, gpu_count: 0,
        error: "zero_gpu", suite: "creer_un_remplacant",
      }, 409);
    }

    await rpc("gpu_pod_observer", {
      p_pod_id: podId, p_observed: "RUNNING", p_gpu_count: cartes,
    });
    return json({ success: true, action, pod_id: podId, gpu_count: cartes });
  }

  // ── arreter ────────────────────────────────────────────────────────────
  if (action === "arreter") {
    if (!podId) return json({ success: false, error: "pod_id_requis" }, 400);

    // 1. Y a-t-il encore du travail ? La file est l'autorite, pas la machine.
    const sollicitee = await rpc("studio_machine_sollicitee");
    if (sollicitee === true) {
      return json({ success: true, action, pod_id: podId, note: "travail_en_cours_arret_annule" });
    }

    // 2. LA GENERATION. On relit JUSTE AVANT d'appeler RunPod. Si elle a bouge
    //    depuis que l'ordre a ete emis, une tache est arrivee entre-temps :
    //    l'ordre est caduc.
    const lignes = await lire(`gpu_pods?select=control_generation,desired_state,stop_after&pod_id=eq.${podId}`);
    const ligne = Array.isArray(lignes) ? lignes[0] : null;
    if (!ligne) return json({ success: false, error: "pod_inconnu_en_base" }, 404);

    const attendue = corps?.generation;
    if (typeof attendue === "number" && Number(ligne.control_generation) !== attendue) {
      return json({
        success: true, action, pod_id: podId, note: "ordre_perime",
        generation_attendue: attendue, generation_actuelle: ligne.control_generation,
      });
    }

    // 3. La grace evenementielle : une seule temporisation, posee a la fin de
    //    la derniere tache. Ce n'est pas un cycle.
    if (ligne.stop_after && new Date(ligne.stop_after) > new Date()) {
      return json({
        success: true, action, pod_id: podId, note: "grace_en_cours",
        stop_after: ligne.stop_after,
      });
    }

    const r = await rest(cleRunpod, `/pods/${podId}/stop`, "POST");
    if (r.ok) {
      await rpc("gpu_pod_observer", { p_pod_id: podId, p_observed: "STOPPED", p_gpu_count: 0 });
    }
    return json({ success: r.ok, action, pod_id: podId, detail: r.detail }, r.ok ? 200 : 502);
  }

  // ── creer ──────────────────────────────────────────────────────────────
  if (action === "creer") {
    const etat = await rpc("studio_etat_file");
    const actifs = await lire("gpu_pods?select=pod_id&status=neq.terminated");
    const nActifs = Array.isArray(actifs) ? actifs.length : 0;
    if (nActifs >= MACHINES_MAX) {
      return json({ success: false, action, error: "plafond_machines", actives: nActifs }, 429);
    }

    const lignesCle = (Deno.env.get("STUDIO_CLE_PUBLIQUE") ?? "")
      .split("\n").map((l) => l.trim()).filter(Boolean)
      .filter((l) => /^ssh-(ed25519|rsa) [A-Za-z0-9+/=]+( \S+)?$/.test(l));
    if (lignesCle.length === 0) {
      return json({ success: false, error: "STUDIO_CLE_PUBLIQUE absente ou invalide" }, 500);
    }
    const clePublique = lignesCle.join("\\n").replace(/"/g, "");

    // LE JETON EST TIRE ICI, AVANT LA CREATION — et c'est tout le point.
    //
    // `gpu_pods.jeton` a pour defaut `gen_random_uuid()` : il naissait donc dans
    // la base, et l'amorceur devait ensuite se connecter en SSH au pod pour le
    // lui ecrire. C'etait sa raison d'etre. Notre image n'ouvre pas sshd : le
    // jeton doit partir avec le conteneur, ou la machine ne pourra jamais se
    // faire reconnaitre.
    //
    // POD_ID n'est PAS injecte : RunPod ne l'attribue qu'apres la creation.
    // `entree.sh` lit `RUNPOD_POD_ID`, que RunPod pose lui-meme.
    const jeton = crypto.randomUUID();
    const cleAnon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    // L'IMAGE SE LIT EN BASE, pas dans ce fichier. Changer de version ne doit
    // pas demander de redeployer une Edge Function : entre le 12/08 midi et le
    // 12/08 soir, l'image est passee de 1.0.0 a 1.1.1, soit trois deploiements
    // pour deux chaines de caracteres. `app.studio_config` porte le reglage ;
    // les constantes ci-dessus ne servent plus que de repli.
    const imagePod = (await rpc("studio_reglage",
      { p_cle: "image_pod", p_defaut: IMAGE })) ?? IMAGE;
    const versionAttendue = (await rpc("studio_reglage",
      { p_cle: "version_moteur", p_defaut: VERSION_ATTENDUE })) ?? VERSION_ATTENDUE;

    // L'ENVIRONNEMENT AUSSI SE LIT EN BASE, ET POUR LA MEME RAISON QUE L'IMAGE.
    //
    // Mesure du 12/08 20h32 : le rendu est mort sur
    //     [Errno 2] No such file or directory: '/workspace/blender/blender'
    // Ces deux chemins dataient de l'installation A CHAUD, quand `/workspace`
    // etait le seul dossier survivant a un arret. L'image met Blender dans
    // `/opt/blender/` et le moteur dans `/opt/moteur/`.
    //
    // `executer_capsule.py` lit DEJA les deux depuis l'environnement. Corriger
    // le defaut ne demande donc ni image reconstruite ni poste de developpeur
    // allume : deux variables suffisent, et elles se reglent en base.
    //
    // C'est la regle generale qu'on veut ici : une machine qu'on ne peut
    // reparer qu'en reconstruisant son image est une machine dont la reparation
    // depend d'un poste local. Tout ce qui peut se regler doit se regler depuis
    // Supabase, sans quoi la chaine n'est pas autonome.
    const baseEnv: Record<string, string> = {
      PUBLIC_KEY: String(clePublique),
      POD_JETON: jeton,
      SUPABASE_URL: String(urlSupabase),
      SUPABASE_ANON_KEY: String(cleAnon),
      VERSION_MOTEUR_ATTENDUE: String(versionAttendue),
      BLENDER: "/opt/blender/blender",
      GENERATEUR: "/opt/moteur/generateur_scenes.py",
    };

    // `env_pod` : un objet JSON en base, fusionne PAR-DESSUS les valeurs
    // ci-dessus. Il permet de depanner ou de rerouter une machine sans
    // redeployer. Illisible ou absent, on garde les defauts -- et on le DIT,
    // parce qu'un reglage silencieusement ignore est pire que pas de reglage.
    let envNote = "defauts";
    const envBrut = await rpc("studio_reglage", { p_cle: "env_pod", p_defaut: "" });
    if (envBrut && String(envBrut).trim()) {
      try {
        const sup = JSON.parse(String(envBrut));
        if (sup && typeof sup === "object" && !Array.isArray(sup)) {
          for (const [k, v] of Object.entries(sup)) baseEnv[k] = String(v);
          envNote = `env_pod applique (${Object.keys(sup).join(",")})`;
        } else {
          envNote = "env_pod ignore : ce n'est pas un objet JSON";
        }
      } catch (_e) {
        envNote = "env_pod ignore : JSON illisible";
      }
    }

    const env = Object.entries(baseEnv)
      .map(([k, v]) => `{key: "${k}", value: "${v.replace(/"/g, "")}"}`)
      .join(", ");

    const creation = await graphql(cleRunpod, `mutation {
      podFindAndDeployOnDemand(input: {
        cloudType: SECURE, gpuCount: 1,
        volumeInGb: 40, containerDiskInGb: 30,
        gpuTypeId: "${gpu}",
        name: "academia-studio",
        imageName: "${imagePod}",
        ports: "22/tcp",
        volumeMountPath: "/workspace",
        env: [${env}]
      }) { id name costPerHr }
    }`);

    const pod = (creation.corps as any)?.data?.podFindAndDeployOnDemand;
    if (!creation.ok || !pod?.id) {
      return json({ success: false, action, error: "aucune_machine_obtenue", detail: creation.detail, ...etat }, 502);
    }
    const cout = typeof pod.costPerHr === "number" ? pod.costPerHr : 0.74;
    if (cout > PLAFOND_HORAIRE_USD) {
      await graphql(cleRunpod, `mutation { podTerminate(input: {podId: "${pod.id}"}) }`);
      return json({ success: false, action, error: "tarif_trop_eleve", cout }, 402);
    }
    // On enregistre AVEC le jeton tire plus haut : sans lui, la machine
    // possede un secret que la base ignore, et aucun de ses rapports ne serait
    // accepte. `gpu_pod_inscrire_decouvert` ne sait pas le faire -- il laisse
    // la base en generer un autre.
    const inscription = await rpc("gpu_pod_enregistrer", {
      p_pod_id: String(pod.id), p_jeton: jeton,
      p_label: pod.name ?? "academia-studio",
      p_gpu: gpu, p_cout: cout, p_image: imagePod,
    });
    if (!inscription?.success) {
      // La machine existe et facture, mais nous ne saurions pas la reconnaitre.
      // On la detruit plutot que de la laisser tourner en orpheline.
      await graphql(cleRunpod, `mutation { podTerminate(input: {podId: "${pod.id}"}) }`);
      return json({
        success: false, action, error: "enregistrement_impossible",
        detail: JSON.stringify(inscription), pod_detruit: pod.id,
      }, 500);
    }
    return json({
      success: true, action, pod_id: pod.id, gpu, cout_heure: cout, image: imagePod,
      // `env` est rendu pour qu'un reglage ignore se VOIE. Un `env_pod` mal
      // ecrit qui ne dirait rien ferait croire a un depannage applique.
      env: envNote,
    });
  }

  // ── terminer ───────────────────────────────────────────────────────────
  // Detruit la machine ET son volume. A n'appeler qu'une fois les donnees
  // deposees dans Storage : c'est irreversible.
  if (action === "terminer") {
    if (!podId) return json({ success: false, error: "pod_id_requis" }, 400);
    const sollicitee = await rpc("studio_machine_sollicitee");
    if (sollicitee === true && corps?.forcer !== true) {
      return json({ success: false, action, error: "travail_en_cours" }, 409);
    }
    const r = await graphql(cleRunpod, `mutation { podTerminate(input: {podId: "${podId}"}) }`);
    if (r.ok) {
      await rpc("gpu_pod_marquer_eteint", {
        p_pod_id: podId, p_raison: "runpod-control terminate", p_reussi: true,
      });
    }
    return json({ success: r.ok, action, pod_id: podId, detail: r.detail }, r.ok ? 200 : 502);
  }

  return json({ success: false, error: "action_inconnue", action }, 400);
});

function json(corps: unknown, status = 200): Response {
  return new Response(JSON.stringify(corps), {
    status, headers: { "content-type": "application/json" },
  });
}
