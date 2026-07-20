# Brief Devin — Déploiement worker Whiteboard v9 (correctif lecture + durées)

## Contexte (1 phrase)
Le worker de rendu Smart Whiteboard produit des vidéos qui (a) ne se lisent pas sur
Android (`MediaCodecVideoRenderer error`) et (b) ignorent les durées de scène. Le code
source est corrigé ; il faut le déployer sur le VPS Kamatera et vérifier.

## Fichiers corrigés (déjà dans le dépôt, à déployer TELS QUELS)
- `academia_bobodo_backend/whiteboard_ffmpeg_assembler.py`  (v9 : profil `main`/level `4.0`, encodage segment-par-segment à durée exacte)
- `academia_bobodo_backend/whiteboard_render_worker.py`     (respecte `duration_ms` de chaque scène + durée totale réelle)

> ⚠️ **Déployer les DEUX fichiers ensemble.** La signature de `assemble_pngs_to_mp4()`
> a changé (nouveau paramètre optionnel `durations`). Déployer un seul des deux fichiers
> re-crée l'erreur historique `assemble_pngs_to_mp4() takes 2 positional arguments but 3 were given`.

## Cible
VPS **Kamatera** (le worker whiteboard tourne comme service dans `/opt`, en boucle de
polling sur la RPC `whiteboard_fetch_queued_jobs`). Identifiants SSH root : fournis
séparément par le propriétaire (ne pas les committer). Server ID Kamatera de référence :
`f6d2656b-0f80-4df1-ac62-53b26d6d921b`.

## Tâche A — Localiser précisément le worker sur le VPS
```bash
ssh root@<IP_DU_VPS>
# Trouver le répertoire réel du worker whiteboard et le service systemd
find / -name "whiteboard_render_worker.py" 2>/dev/null
systemctl list-units --type=service | grep -iE "whiteboard|worker"
```
Noter : le dossier du worker (ex. `/opt/whiteboard-worker/`) et le nom exact du service.

## Tâche B — Sauvegarde + déploiement des 2 fichiers
Depuis une copie à jour du dépôt (git pull d'abord si le VPS est un checkout git) :
```bash
WORKER_DIR=/opt/whiteboard-worker      # <-- remplacer par le chemin trouvé en Tâche A
cp $WORKER_DIR/whiteboard_ffmpeg_assembler.py $WORKER_DIR/whiteboard_ffmpeg_assembler.py.bak
cp $WORKER_DIR/whiteboard_render_worker.py     $WORKER_DIR/whiteboard_render_worker.py.bak

# Copier les 2 fichiers corrigés depuis le dépôt (scp depuis la machine de déploiement) :
scp academia_bobodo_backend/whiteboard_ffmpeg_assembler.py root@<IP>:$WORKER_DIR/
scp academia_bobodo_backend/whiteboard_render_worker.py     root@<IP>:$WORKER_DIR/
```
Si le worker est un checkout git sur le VPS : `cd $WORKER_DIR && git pull` (après merge de la branche).

## Tâche C — Dépendances + redémarrage
```bash
pip3 install matplotlib          # requis uniquement pour le rendu des formules (sinon repli texte)
python3 -c "import ast; ast.parse(open('$WORKER_DIR/whiteboard_ffmpeg_assembler.py').read()); print('syntax OK')"
systemctl restart <nom_du_service_whiteboard>
systemctl status  <nom_du_service_whiteboard> --no-pager | head -20
journalctl -u <nom_du_service_whiteboard> --no-pager -n 30
```

## Tâche D — TEST DÉCISIF : relancer un rendu NEUF, puis vérifier
> Les vidéos déjà rendues restent illisibles. Il FAUT un rendu généré APRÈS le
> redéploiement, sinon on conclut à tort que le correctif ne marche pas.

1. Depuis l'app (ou en réenfilant un job), générer une nouvelle vidéo whiteboard
   à partir d'un storyboard multi-scènes aux durées variées.
2. Récupérer l'URL du MP4 (table `app.whiteboard_renders.video_url`) et le télécharger.
3. Vérifier le flux :
```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=profile,level,width,height,pix_fmt,avg_frame_rate \
  -of default=noprint_wrappers=1 nouvelle_video.mp4
# ATTENDU : profile=Main, level=40, 720x1280, pix_fmt=yuv420p, 30 fps

ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 nouvelle_video.mp4
# ATTENDU : ≈ somme des duration_ms des scènes du storyboard (ex. 65s), PAS n_scenes×5s

ffmpeg -v error -i nouvelle_video.mp4 -f null -   # doit finir sans erreur (décodage OK)
```
4. Ouvrir la vidéo dans l'app sur un téléphone d'entrée de gamge : elle doit se lire.

## Critères d'acceptation
- [ ] `ffprobe` montre `Main / level 40 / 720x1280 / yuv420p`.
- [ ] Durée du MP4 = somme des durées de scène du storyboard (± 1 frame), pas un multiple de 5 s.
- [ ] `ffmpeg -f null -` décode sans erreur.
- [ ] Lecture OK dans l'app (plus de `MediaCodecVideoRenderer error`).
- [ ] Les deux fichiers `.bak` sont conservés pour rollback.

## Garde-fous (ne PAS faire)
- Ne pas déployer un seul des deux fichiers.
- Ne pas committer les identifiants SSH / clés Supabase.
- Ne pas remonter en 1080p sans re-tester : si besoin HD plus tard, mettre
  `TARGET_W/H = 1080/1920`, `H264_PROFILE = "high"`, `H264_LEVEL = "4.1"` dans l'assembleur,
  puis re-vérifier la lecture sur appareil d'entrée de gamme.
- Ne pas toucher aux RPC Supabase `whiteboard_*` ni au bucket `whiteboard-renders`.

## Rollback
`cp *.bak` sur les originaux + `systemctl restart <service>`.
