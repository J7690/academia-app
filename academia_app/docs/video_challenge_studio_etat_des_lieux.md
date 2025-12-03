# État des lieux du Video Challenge Studio (TikTok Academia)

## 1. Contexte

Ce document décrit l’état actuel de l’implémentation du "Video Challenge Studio" dans Academia (mini-studio de type TikTok pour les vidéos de challenge), en le comparant au cahier des charges initial dit "TikTok Academia Studio".

Objectifs initiaux (résumé) :
- Permettre aux étudiants de filmer / uploader, éditer et publier des vidéos de challenge sans quitter l’app.
- Proposer une expérience fun mais académique (overlays pédagogiques, équations, AR, IA, etc.).
- Se rapprocher d’un mini-studio vidéo à la TikTok : capture → édition → publication.

Ce document sert de référence technique pour la suite du développement.

---

## 2. Architecture actuelle

### 2.1 Côté app (Flutter / `academia_app`)

Principaux composants liés au Video Challenge Studio :

- **Providers**
  - `StudentChallengesProvider` (`lib/providers/student_challenges_provider.dart`)
    - Gestion des challenges, participations et vidéos côté étudiant.
    - RPC Supabase : listings de challenges, vidéos, participations, leaderboard, stats.
    - API vidéo : like/unlike, favorite/unfavorite, commentaires, signalements, ajout de vidéo, mises à jour des overlays, jobs de rendu audio/vidéo.
  - `AdminChallengesProvider` (`lib/providers/admin_challenges_provider.dart`)
    - Outils admin : gestion des challenges, participations, vidéos, assets vidéo/audio, signalements, modération.

- **Écrans étudiants (features)**
  - `StudentChallengesTab`
    - Onglet principal "Challenges" + sous-onglet "Vidéos de challenges" (flux type TikTok).
    - Accès à l’écran de détail de challenge et bouton pour créer une vidéo de challenge.
  - `StudentChallengeDetailScreen`
    - Détail d’un challenge (titre, description, type, difficulté, points).
    - Affichage de l’avancement étudiant, des vidéos de sa participation, du leaderboard.
    - Accès au `StudentChallengeVideoEditorScreen` pour créer/ajouter une vidéo de challenge.
  - `StudentChallengeVideoEditorScreen`
    - Cœur du "Video Challenge Studio" côté app.
    - Fonctions : sélection/capture vidéo, upload, prévisualisation, personnalisation académique (texte, équations, sous-titres, stickers, AR), outils IA, timeline multi-clips, studio audio, soumission.
  - `ChallengeCameraCaptureScreen`
    - Écran générique d’enregistrement vidéo (max 60s) via `camera`.
  - `StudentChallengeVideoArScreen` / `StudentChallengeVideoArCombinedScreen`
    - Studio AR 3D pour placer des objets AR (via `ar_flutter_plugin`), et écran combinant vidéo + AR en live.

- **Services Studio**
  - `StudioAiService` (`lib/services/studio_ai_service.dart`)
    - Envoie des requêtes authentifiées (JWT utilisateur) aux endpoints backend :
      - `/studio/ai/transcribe` : transcription IA.
      - `/studio/ai/analyze` : analyse pédagogique.
      - `/studio/ai/proofread` : relecture/correction de texte.
  - `StudioAudioService` (`lib/services/studio_audio_service.dart`)
    - Appelle `/studio/audio/render` pour mixer la vidéo avec des pistes audio Studio.

- **Modèle d’overlays vidéo**
  - `ChallengeVideoOverlays` (`lib/features/student/student_challenge_video_overlays.dart`)
    - Représente les couches académiques appliquées à une vidéo de challenge :
      - `backgroundTheme`, `filter`.
      - `texts`, `equations`, `subtitles`, `stickers`, `arObjects`.
    - Sérialisation JSON alignée avec le backend.

### 2.2 Côté backend (`academia_bobodo_backend/main.py`)

- **Services externes**
  - `call_studio_asr(video_url, language)`
    - Appelle `STUDIO_ASR_URL` (service d’ASR) pour obtenir des segments `{text, start_ms, end_ms}`.
  - `call_studio_audio_mix(video_url, tracks, normalize)`
    - Appelle `STUDIO_AUDIO_MIX_URL` (service de mixage audio) pour produire une nouvelle vidéo mixée.

- **Endpoints Studio**
  - `POST /studio/audio/render`
    - Authentification JWT user.
    - Récupère la vidéo de challenge pour une participation.
    - Envoie la vidéo et les pistes audio au service audio Studio.
    - Gère le job dans `app.challenge_video_render_jobs`.
    - Crée une nouvelle vidéo de challenge mixée via RPC `app_student_add_challenge_video`.
  - `POST /studio/ai/transcribe`
    - Transcrit la vidéo de challenge via `call_studio_asr`.
    - Met à jour `overlays.subtitles` via RPC `app_student_update_challenge_video_overlays`.
  - `POST /studio/ai/analyze`
    - Utilise les sous-titres + métadonnées du challenge pour générer :
      - résumé pédagogique,
      - plan de cours,
      - questions type quiz.
  - `POST /studio/ai/proofread`
    - Corrige un texte court (overlay, description) via un modèle IA.

- **Intégration Supabase**
  - RPC nombreuses pour la gestion des challenges / participations / vidéos / stats.
  - Tables utilisées pour le Studio :
    - `app.challenge_video_assets` (pistes audio Studio).
    - `app.challenge_video_render_jobs` (jobs de rendu audio/vidéo).

---

## 3. Fonctionnalités implémentées vs cahier des charges "TikTok Academia Studio"

Cette section compare l’existant au cahier des charges initial.

### 3.1 Capture & upload vidéo

- **Implémenté**
  - Capture vidéo via `ChallengeCameraCaptureScreen` (plugin `camera`), avec durée max, switch caméra.
  - Upload vidéo vers Supabase Storage dans le bucket `challenge-media`.
  - Gestion de la prévisualisation via `VideoPlayerController.networkUrl`.

- **Non implémenté**
  - Effets/filtres appliqués **en direct** pendant la capture (beautify, filtre live, background replace live).

### 3.2 Overlays académiques (texte, équations, sous-titres, stickers, AR)

- **Texte sur vidéo**
  - Implémentation actuelle :
    - Un texte principal saisi via `_overlayTextController`.
    - Stockage dans `overlays.texts` avec position fixe (x, y) et alignement centre.
  - Manques par rapport au cahier des charges :
    - Pas de multi-calques texte.
    - Pas de gestion de police, taille, couleur, animations, ni in/out temporels par texte.

- **Équations**
  - Implémentation actuelle :
    - Champ `_equationController` pour une équation (LaTeX ou texte).
    - Stockée dans `overlays.equations` avec position simple.
  - Manques :
    - Pas de flux IA "parler → LaTeX".
    - Pas d’éditeur avancé (handwriting → LaTeX, etc.).

- **Sous-titres (STT)**
  - Implémentation actuelle :
    - `StudioAiService.transcribe` → `/studio/ai/transcribe` → mise à jour de `overlays.subtitles` côté backend.
    - Éditeur détaillé de sous-titres dans `_openSubtitlesEditor()` :
      - segments (texte, start_ms, end_ms), ajout/suppression/modification.
  - Manques :
    - Pas de transcription **live** pendant l’enregistrement, tout est post-processing.

- **Stickers**
  - Implémentation actuelle :
    - Choix d’un sticker simple (`none`, `star`, `heart`, `idea`), stocké dans `overlays.stickers`.
  - Manques :
    - Pas de bibliothèque avancée de stickers académiques ; pas d’animations.

- **AR 3D**
  - Implémentation actuelle :
    - `StudentChallengeVideoArScreen` pour placer des objets AR (exemple Duck GLB) sur des plans.
    - Objets sérialisés dans `overlays.ar_objects`.
    - `StudentChallengeVideoArCombinedScreen` pour afficher vidéo + AR en live dans un même écran.
  - Manques :
    - Pas de modèles académiques dédiés (molécules 3D, circuits, etc.) fournis dans le code.
    - Pas de pipeline de "rendu vidéo final" intégrant AR + vidéo de façon combinée.

### 3.3 Filtres vidéo & thèmes

- Implémentation actuelle :
  - Choix d’un `backgroundTheme` (ex. `universite-vert`, `tableau-noir`).
  - Choix d’un `filter` (`none`, `warm`, `cool`, `bw`).
  - Ces valeurs sont stockées dans `overlays.background.theme` et `overlays.filter`.

- Manques :
  - Pas de moteur de filtres GPU visible dans le code (pas d’utilisation de `flutter_gpu_video_filters` ou shaders personnalisés).
  - Pas de rendu vidéo serveur utilisant explicitement `filter`/`backgroundTheme`.

### 3.4 Timeline multi-clips

- Implémentation actuelle (côté app) :
  - Récupération de `clips` supplémentaires via `listMyChallengeVideos`.
  - UI pour :
    - Réordonner les clips (`_clipOrder`).
    - Définir des points d’entrée/sortie en ms (`_clipEdits`).
  - Sérialisation dans `overlays.layers.clips`.

- Manques :
  - Côté backend, aucun service de rendu vidéo multi-clips n’utilisant `layers.clips` n’est visible.
  - Il s’agit pour l’instant d’un **modèle logique** et d’une UI de configuration, sans pipeline de montage vidéo final.

### 3.5 Studio audio (mix multi-pistes)

- Implémentation actuelle :
  - Table Supabase `app.challenge_video_assets` pour les pistes audio Studio.
  - `_loadAudioAssetsIfNeeded()` pour charger ces pistes côté app.
  - UI Timeline audio :
    - Sélection de pistes.
    - In/out via `RangeSlider`.
    - Volume par piste.
  - Appel à `StudioAudioService.render` → `/studio/audio/render`.
  - Backend :
    - Utilise `call_studio_audio_mix`.
    - Crée un job de rendu et une **nouvelle vidéo mixée** rattachée à la participation.

- Manques :
  - Pas de ducking automatique explicite dans l’API actuelle.
  - Pas d’effets vocaux (reverb, pitch, etc.) exposés côté app ou backend.

### 3.6 IA pédagogiques (analyse, correction)

- Implémentation actuelle :
  - Analyse pédagogique : `/studio/ai/analyze` produit un texte structuré (résumé, plan, quiz) à partir des sous-titres + métadonnées du challenge.
  - Relecture texte : `/studio/ai/proofread` corrige le texte d’overlay (orthographe, grammaire, ton académique simple).

- Manques par rapport au cahier détaillé :
  - Outils de résolution d’exercices en surcouche, génération de graphiques, reconnaissance manuscrite, etc. ne sont pas présents dans ce code.

### 3.7 Édition photo

- Non trouvée dans cette base : aucun écran ni service dédié à un mode éditeur de photo avec recadrage, filtres, annotations académiques, cleanup IA.

---

## 4. Flux utilisateur actuel (résumé)

1. **Découverte & participation aux challenges**
   - `StudentChallengesTab` liste les challenges, permet de rejoindre un challenge.

2. **Accès à la création vidéo**
   - Depuis le détail de challenge (`StudentChallengeDetailScreen`) ou depuis le flux vidéo (TikTok-like), l’étudiant ouvre `StudentChallengeVideoEditorScreen`.

3. **Capture / upload vidéo**
   - Capture via `ChallengeCameraCaptureScreen` (ou) sélection de fichier via `FilePicker`.
   - Upload vers Supabase via `StudentChallengesProvider.uploadChallengeVideo`.

4. **Personnalisation académique**
   - Choix du thème de fond, filtre simple.
   - Texte de titre / explication.
   - Équation (LaTeX/texte).
   - Sous-titres : saisie manuelle ou génération IA + édition fine.
   - Stickers simples.
   - AR 3D via `StudentChallengeVideoArScreen` (objets sérialisés dans `ar_objects`).

5. **Studio audio & multi-clips**
   - Sélection de pistes audio Studio, création d’une nouvelle vidéo mixée.
   - Gestion de clips supplémentaires, timeline multi-clips (ordre + in/out) au niveau des overlays.

6. **Soumission**
   - Mise à jour des overlays via RPC.
   - Soumission du challenge avec `submissionText` et `submissionUrl`.

---

## 5. Gaps principaux vs cahier des charges complet

Voici les manques majeurs par rapport au cahier des charges "TikTok Academia Studio" :

1. **Éditeur vidéo riche**
   - Pas de moteur d’édition complet : vitesse, transitions, effets glitch/zoom, texte animé multi-calques.
   - Pas de rendu vidéo multi-clips côté backend.

2. **Effets live en capture**
   - Capture vidéo brute uniquement, sans filtres live, beautify ni remplacement de fond en direct.

3. **Filtres vidéo avancés**
   - Filtres et thèmes existent au niveau des métadonnées, mais pas de pipeline GPU / rendu vidéo associé dans ce code.

4. **Édition photo**
   - Aucun module dédié dans cette base pour l’édition d’images fixes.

5. **Outils IA académiques avancés**
   - Manquent : reconnaissance manuscrite, génération de schémas/graphes, résolution d’exercices filmés, etc.

6. **Pipeline générique de projet d’édition**
   - Pas de notion de "projet" d’édition vidéo générique avec sauvegarde de drafts, export paramétrable, gestion de sessions d’édition avancées.

---

## 6. Pistes de développement (haut niveau)

1. **Renforcer l’éditeur vidéo côté app**
   - Introduire un vrai timeline editor (multi-pistes vidéo/texte/stickers) avec un moteur d’édition local (FFmpeg ou plugin spécialisé).
   - Donner des paramètres d’animation, style et timing par calque d’overlay.

2. **Exploiter `layers.clips` côté backend**
   - Créer un service de rendu vidéo multi-clips qui consomme `overlays.layers.clips` pour produire un fichier final monté.

3. **Compléter les filtres vidéo**
   - Ajouter un pipeline de filtres GPU (Flutter shaders ou plugin dédié).
   - Documenter le mapping entre `overlays.filter` / `background.theme` et les effets visuels appliqués.

4. **Captation enrichie & AR**
   - Étendre la capture avec filtres live simples et/ou backgrounds floutés.
   - Intégrer un flux de rendu "vidéo + AR" final si besoin.

5. **Étendre les outils IA académiques**
   - Ajouter progressivement : éditeur LaTeX IA, graphes automatiques, outils par matière.

Ce document pourra être mis à jour au fur et à mesure des évolutions du Studio.
