# Brief Devin — Déploiement & tests Smart Whiteboard V1

**But** : déployer et valider les corrections V1 du Smart Whiteboard (onglet
Challenge de l'app `academia`). Le code est **déjà écrit et committé dans le
repo** — ta mission est de **déployer, compiler, tester et rapporter**. Ne
réécris pas la logique ; si un test échoue, corrige au minimum et documente.

---

## 0. Contexte technique

Pipeline : app Flutter → Edge Function Supabase (génère un storyboard JSON) →
job de rendu (table `whiteboard_renders`) → worker Python sur VPS Kamatera
(génère des PNG, assemble un MP4 via FFmpeg, upload dans le bucket Supabase
`whiteboard-renders`) → l'app lit l'URL et joue le MP4.

**Bug corrigé** : le worker encodait le MP4 en `H.264 baseline @ level 3.1`
mais à une résolution 1080×1920 illégale pour ce niveau → le décodeur Android
échouait (`MediaCodecVideoRenderer error`). Corrigé en encodant à 720×1280
(légal pour le niveau). Le renderer PNG a aussi été fiabilisé (polices,
retour à la ligne, formules) et 4 bugs Flutter corrigés.

---

## 1. Fichiers déjà modifiés (ne pas réécrire, juste déployer/compiler)

Worker (Python — source canonique) :
- `academia_bobodo_backend/whiteboard_ffmpeg_assembler.py` — encodage 720×1280 légal, tunable via constantes `TARGET_W/TARGET_H/H264_PROFILE/H264_LEVEL`.
- `academia_bobodo_backend/whiteboard_png_renderer.py` — polices DejaVu, word-wrap, formules matplotlib (repli texte si absent).
- Miroir identique dans `.windsurf/kamatera_snapshot/` (représente l'état VPS).

Flutter :
- `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart` — `loadProjects` gère `{success, projects}`.
- `academia_app/lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_input_screen.dart` — transmet `mode` + `content` (modes B/C/D) via `InputMode.apiValue`.
- `academia_app/lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_preview_screen.dart` — bouton « Publier dans le Challenge » → `VideoPublishScreen`.
- `academia_app/lib/main.dart` — la route `/smart-whiteboard-preview` passe désormais les `arguments`.

---

## 2. TÂCHE A — Déployer le worker sur Kamatera

**VPS** : hôte `185.167.97.144`, user `root`. Les identifiants SSH sont dans
`.windsurf/deploy_whiteboard_worker_systemd.py` (paramiko, en clair). Réutilise
ce même mécanisme/identifiants. Chemin worker : `/opt/whiteboard-worker/`.

Étapes :

1. **Sauvegarde** l'état actuel du VPS avant écrasement :
   ```bash
   ssh root@185.167.97.144 "mkdir -p /opt/whiteboard-worker/_backup_$(date +%F) && cp /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py /opt/whiteboard-worker/whiteboard_png_renderer.py /opt/whiteboard-worker/_backup_$(date +%F)/"
   ```
2. **Copie** les deux fichiers corrigés :
   ```bash
   scp academia_bobodo_backend/whiteboard_ffmpeg_assembler.py root@185.167.97.144:/opt/whiteboard-worker/
   scp academia_bobodo_backend/whiteboard_png_renderer.py     root@185.167.97.144:/opt/whiteboard-worker/
   ```
3. **Dépendances** (matplotlib active le rendu des formules ; non bloquant si échec — repli texte automatique) :
   ```bash
   ssh root@185.167.97.144 "pip3 install matplotlib && fc-list | grep -i dejavu"
   ```
   Si aucune police DejaVu n'est listée : `apt-get install -y fonts-dejavu-core`.
4. **Redémarre** et vérifie le service :
   ```bash
   ssh root@185.167.97.144 "systemctl restart whiteboard-worker && systemctl is-active whiteboard-worker && journalctl -u whiteboard-worker -n 30 --no-pager"
   ```

Critère de succès : service `active (running)`, pas d'exception au démarrage.

---

## 3. TÂCHE B — Compiler l'app Flutter

1. Localise le projet Flutter buildable (celui qui contient `pubspec.yaml` —
   normalement `academia_app/`). Depuis ce dossier :
   ```bash
   flutter pub get
   flutter analyze
   ```
2. `flutter analyze` doit passer **sans nouvelle erreur** sur les 4 fichiers
   modifiés (section 1). Corrige toute erreur de compilation introduite
   (imports, types) au minimum nécessaire.
3. Build de vérification :
   ```bash
   flutter build apk --debug
   ```

Critère de succès : `flutter analyze` sans erreur bloquante et build APK OK.

---

## 4. TÂCHE C — Test de rendu bout-en-bout (sans téléphone)

Objectif : prouver que le worker produit maintenant un MP4 **décodable**.

1. Génère un job de rendu de test via les scripts existants du repo
   (dossier `.windsurf/`, ex. `create_whiteboard_test_job.py` ou
   `test_whiteboard_generation.py`). Utilise un storyboard réaliste (titre,
   paragraphe long, une formule, une correction) pour tester le word-wrap et
   les formules. Attends que le worker passe le job à `done` et récupère
   l'`video_url`.
2. Télécharge le MP4 produit et **vérifie le format** :
   ```bash
   ffprobe -v error -select_streams v:0 \
     -show_entries stream=codec_name,profile,level,width,height \
     -of default=noprint_wrappers=1 out.mp4
   ```
   Attendu : `codec_name=h264`, `width=720`, `height=1280`, `level=31`
   (profil « Constrained Baseline » ou « Baseline »).
3. **Test de décodage** (échoue si le flux est corrompu / illégal) :
   ```bash
   ffmpeg -v error -i out.mp4 -f null - && echo "DECODE OK"
   ```
4. Vérifie visuellement une frame (texte non tronqué, formule lisible) :
   ```bash
   ffmpeg -y -i out.mp4 -vf "select=eq(n\,15)" -vframes 1 frame.png
   ```

Critères de succès : ffprobe conforme (720×1280, level 31), `DECODE OK`, et la
frame montre du texte qui tient dans l'écran + une formule rendue.

> Note importante : les vidéos **déjà rendues avant le déploiement restent
> illisibles**. Seuls les rendus lancés APRÈS le déploiement du worker sont
> corrigés. Toujours tester avec un **nouveau** job.

---

## 5. TÂCHE D — Test app réel (si un appareil/émulateur Android est dispo)

1. Installe l'APK debug, connecte-toi comme étudiant.
2. Onglet Challenge → créer une vidéo → Smart Whiteboard.
3. Vérifie chaque correctif :
   - **Modes B/C/D** : choisir « Texte complet », coller un texte, générer → le storyboard doit refléter le texte fourni (pas un contenu générique).
   - **Prévisualisation** : la vidéo se **lit** sans « Erreur lecteur vidéo ».
   - **Publier dans le Challenge** : le bouton ouvre l'écran de publication et poste la vidéo dans le feed.
   - **Liste des projets** : s'affiche sans crash.

---

## 6. Rapport attendu

Fournis un compte-rendu avec :
- Statut de chaque tâche (A/B/C/D) : succès / échec + logs pertinents.
- Sortie `ffprobe` et résultat du test de décodage.
- La frame `frame.png` extraite.
- Toute correction que tu as dû apporter (fichier + diff).
- Blocages éventuels (dépendance manquante, accès VPS, etc.).

---

## 7. Garde-fous

- Ne modifie pas les identifiants/secrets ni le fichier `.env` du VPS.
- Ne touche pas aux tables/RPC Supabase ni à l'Edge Function (hors périmètre V1).
- Si tu changes les constantes d'encodage, garde une résolution **légale** pour
  le niveau H.264 choisi (720×1280 pour level 3.1 ; pour 1080×1920 il faut
  `H264_LEVEL="4.1"` et profil `high`/`main`).
- En cas d'échec du déploiement worker, restaure depuis `_backup_<date>/`.
