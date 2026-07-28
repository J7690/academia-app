# Instructions Windsurf — URGENT : un seul worker, un seul moteur

**Date** : 25 juillet 2026
**Serveurs concernés** : Kamatera (185.167.97.144) **et** LWS (`lws-nexiom`).
**Nature** : arrêter un service sur Kamatera, vérifier, puis nettoyer LWS.

## Le problème, prouvé

Un rendu créé aujourd'hui avec `engine: "remotion"` (vérifié en base) est sorti **au
format Vision** : cartes, étiquette « DÉFINITION », pagination « 2/8 », aucune écriture
manuscrite.

Or le worker à jour **ne dégrade jamais en silence** : si Remotion est demandé et
indisponible, il fait échouer le job avec un message explicite. Le job a réussi, en
Vision. **Un second worker, non à jour, a donc intercepté le job.** C'est celui de
Kamatera : il interroge toujours la même file Supabase, et les deux machines se
disputent les jobs au hasard.

Preuve complémentaire : `app.whiteboard_engine_health` porte encore `host: vps122603`
(Kamatera), preuve que cette machine publie toujours.

## RÈGLES ABSOLUES

1. Sur Kamatera, **n'arrête QUE le worker whiteboard**. Cette machine fait aussi tourner
   **LiveKit (appels en direct), Bobodo vocal, la compression vidéo** : n'y touche pas,
   ne redémarre pas la machine, ne touche pas à Docker globalement.
2. **Ne supprime rien sur LWS** avant l'étape 4 (Claude valide entre-temps).
3. **Ne touche pas à Supabase**, n'ajoute aucun secret.
4. À la moindre erreur ou doute → **STOP + rapport**.

---

## ÉTAPE 1 — Constater qui tourne, sur les DEUX machines (lecture seule)

```bash
echo "===== KAMATERA ====="
ssh root@185.167.97.144 "hostname
systemctl list-units --type=service --all 2>/dev/null | grep -iE 'whiteboard|render' || echo 'aucun service whiteboard systemd'
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null | grep -iE 'whiteboard|render' || echo 'aucun conteneur whiteboard'
ps aux | grep -iE 'whiteboard_render_worker' | grep -v grep || echo 'aucun process worker'"

echo "===== LWS ====="
ssh lws-nexiom "hostname
systemctl is-active whiteboard-worker
ps aux | grep -iE 'whiteboard_render_worker' | grep -v grep | head -3"
```

**Rapporte cette sortie AVANT de continuer.** Si aucun worker whiteboard n'apparaît sur
Kamatera, **arrête-toi** : l'explication est ailleurs, Claude doit revoir son analyse.

## ÉTAPE 2 — Arrêter le worker whiteboard sur Kamatera (et lui seul)

Adapte le nom exact du service ou du conteneur à ce que l'étape 1 a montré.

Si c'est un service systemd :
```bash
ssh root@185.167.97.144 "systemctl stop whiteboard-worker && systemctl disable whiteboard-worker && systemctl is-active whiteboard-worker; systemctl is-enabled whiteboard-worker"
```

Si c'est un conteneur Docker :
```bash
ssh root@185.167.97.144 "docker stop academia-whiteboard-worker && docker update --restart=no academia-whiteboard-worker && docker ps -a --format '{{.Names}}\t{{.Status}}' | grep whiteboard"
```

`disable` / `--restart=no` est **essentiel** : sans cela le worker repart au prochain
redémarrage de la machine et le problème réapparaîtrait plus tard, sans prévenir.

## ÉTAPE 3 — Vérifier qu'il ne reste QU'UN worker

```bash
ssh root@185.167.97.144 "ps aux | grep whiteboard_render_worker | grep -v grep || echo 'KAMATERA : plus aucun worker whiteboard'
echo '--- les autres services de Kamatera doivent rester intacts ---'
docker ps --format '{{.Names}}\t{{.Status}}' | head -10
systemctl is-active livekit-server 2>/dev/null || echo 'livekit: (verifier manuellement)'"
ssh lws-nexiom "systemctl is-active whiteboard-worker"
```

Attendu : plus aucun worker whiteboard sur Kamatera, **les autres services de Kamatera
toujours actifs**, et le worker LWS `active`.

**Puis arrête-toi et rapporte.** Claude lance un rendu de contrôle via Supabase pour
confirmer que LWS le traite bien en manuscrit. Ne fais pas l'étape 4 avant son feu vert.

---

## ÉTAPE 4 — (Après validation de Claude) Retirer le moteur Vision de LWS

Objectif : Remotion devient le seul moteur, plus aucune ambiguïté possible.

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
# 1. Sauvegarde horodatee, au cas ou
tar czf /root/vision_engine_backup_\$(date +%Y%m%d).tar.gz vision_engine
# 2. Neutraliser le moteur vision
sed -i 's/^RENDERER_ENGINE=.*/RENDERER_ENGINE=remotion/' .env
grep -oE '^[A-Z_]+=' .env
mv vision_engine /root/vision_engine_retire
systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

La sauvegarde et le `mv` (au lieu d'un `rm`) sont volontaires : si un problème
apparaissait, le moteur se remet en place en une commande.

---

## RAPPORT À RENDRE

1. **Étape 1 : la sortie complète des deux machines** (c'est le point décisif).
2. Étape 2 : le service/conteneur arrêté, et confirmation qu'il est aussi désactivé.
3. Étape 3 : confirmation qu'il ne reste qu'un worker, et que LiveKit / les autres
   conteneurs de Kamatera tournent toujours.
4. Statut final : « terminé sans erreur » ou « arrêté à l'étape X ».

Puis **arrête-toi**.
