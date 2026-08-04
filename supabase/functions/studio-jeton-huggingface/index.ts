import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * Remet le jeton HuggingFace a une machine qui prouve son identite.
 *
 * POURQUOI CETTE FONCTION EXISTE. Les secrets Supabase ne sont lisibles que par
 * les Edge Functions -- c'est la propriete qui fait leur valeur. Mais le pod a
 * BESOIN de ce jeton : c'est lui qui telecharge les modeles, et certains
 * depots exigent une authentification.
 *
 * Trois solutions etaient possibles, deux mauvaises :
 *   - recopier le jeton sur LWS : deux endroits a tenir a jour, deux endroits
 *     a compromettre ;
 *   - donner la cle de service au pod : elle ouvre TOUTE la base, sur une
 *     machine louee dont nous ne controlons pas l'hote ;
 *   - celle-ci : le pod s'authentifie avec SON jeton, celui qu'il possede
 *     deja, et ne recoit que ce dont il a besoin.
 *
 * Supabase reste la source unique. Le jeton ne transite jamais par LWS.
 *
 * CE QU'UN JETON DE POD VOLE PERMETTRAIT. De recuperer le jeton HuggingFace de
 * cette machine. C'est pourquoi ce jeton doit etre de portee LECTURE SEULE :
 * le pire devient alors « telecharger des modeles publics », ce qui n'est pas
 * un incident. Un jeton en ecriture permettrait de publier sous l'identite du
 * compte -- a ne jamais deposer ici.
 */

Deno.serve(async (req: Request) => {
  const urlSupabase = Deno.env.get("SUPABASE_URL");
  const cleService = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const jetonHF = Deno.env.get("Token_huggingface") ?? Deno.env.get("TOKEN_HUGGINGFACE") ?? "";

  if (!urlSupabase || !cleService) {
    return new Response(JSON.stringify({ success: false, error: "configuration_incomplete" }),
      { status: 500, headers: { "content-type": "application/json" } });
  }

  let corps: any = {};
  try { corps = await req.json(); } catch { /* corps vide */ }
  const podId = String(corps.pod_id ?? "").trim();
  const jetonPod = String(corps.jeton ?? "").trim();

  if (!podId || !jetonPod) {
    return new Response(JSON.stringify({ success: false, error: "identification_manquante" }),
      { status: 400, headers: { "content-type": "application/json" } });
  }

  // On reutilise le battement de coeur pour verifier l'identite : il valide
  // deja le couple pod_id / jeton et refuse une machine inconnue ou eteinte.
  // Une seule regle d'authentification, un seul endroit ou la corriger.
  const verif = await fetch(`${urlSupabase}/rest/v1/rpc/gpu_pod_heartbeat`, {
    method: "POST",
    headers: {
      apikey: cleService,
      Authorization: `Bearer ${cleService}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      p_pod_id: podId, p_jeton: jetonPod,
      p_busy: true, p_activite: "installation",
    }),
  });

  const resultat = verif.ok ? await verif.json() : null;
  if (!resultat?.success) {
    return new Response(JSON.stringify({ success: false, error: "pod_non_autorise" }),
      { status: 403, headers: { "content-type": "application/json" } });
  }

  if (!jetonHF) {
    // Degradation gracieuse : sans jeton, les depots ouverts restent
    // accessibles. On le dit clairement plutot que de renvoyer une chaine vide
    // qui ressemblerait a un succes.
    return new Response(JSON.stringify({
      success: true, jeton: "", note: "aucun_jeton_configure_depots_ouverts_seulement",
    }), { headers: { "content-type": "application/json" } });
  }

  return new Response(JSON.stringify({ success: true, jeton: jetonHF }),
    { headers: { "content-type": "application/json" } });
});
