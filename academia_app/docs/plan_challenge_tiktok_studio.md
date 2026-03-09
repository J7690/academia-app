# Plan d'implémentation — Challenge TikTok + Studio Scientifique

## Date : 20 février 2026
## Statut : Plan validé, prêt pour implémentation phase par phase

---

## 0. Vision

Transformer l'onglet Challenge en un **mini-TikTok éducatif** avec :
1. **Feed vertical infini** type TikTok (swipe up/down, autoplay, preload)
2. **Capture vidéo** avec effets live (filtres, timer, flash, switch caméra)
3. **Éditeur vidéo** type CapCut (trim, merge, vitesse, transitions)
4. **Studio scientifique** (innovation) : zones d'écriture sur vidéo pour équations, formules, cours, schémas
5. **Social complet** : likes, commentaires, partages, duos, remix, leaderboard
6. **Pipeline vidéo** : upload → transcoding → CDN → playback adaptatif

---

## 1. Analyse de l'architecture TikTok (référence)

### 1.1 Mécanismes clés TikTok à reproduire

| Mécanisme | TikTok | Notre implémentation |
|---|---|---|
| **Feed vertical** | PageView infini, preload N+1/N+2, autoplay au focus, pause au swipe | PageView.builder + VideoPlayerController pool (1 actif, 2 preloaded) |
| **Double-tap like** | Cœur animé au double-tap | GestureDetector + animation Lottie/Rive |
| **Commentaires** | Bottom sheet scrollable, temps réel | BottomSheet + Realtime Supabase |
| **Partage** | Share sheet natif + lien deep link | share_plus + deep links |
| **Duos/Remix** | Split-screen ou réponse vidéo | parent_participation_id + remix_type (déjà en DB) |
| **Son original** | Extraction audio, réutilisation | easy_video_editor.extractAudio() |
| **Discover/Search** | Hashtags, trending, recherche | app_student_list_challenges(search) déjà en place |
| **Upload pipeline** | Upload → Transcoding → Multi-résolution → CDN | Supabase Storage → Edge Function transcoding → video_assets → playback manifest |
| **Recommendation** | ML-based, engagement signals | Phase future — pour l'instant : chronologique + featured + engagement score |

### 1.2 Architecture TikTok simplifiée (adaptée à notre stack)

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Client)                         │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Feed     │  │ Capture  │  │ Editor   │  │ Studio        │  │
│  │ TikTok   │  │ Caméra   │  │ Vidéo    │  │ Scientifique  │  │
│  │ vertical │  │ + effets │  │ CapCut   │  │ (équations,   │  │
│  │          │  │          │  │          │  │  whiteboard)  │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────┬────────┘  │
│       │              │              │               │           │
│       └──────────────┴──────────────┴───────────────┘           │
│                              │                                  │
│                     Supabase Client SDK                         │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────┴──────────────────────────────────┐
│                    SUPABASE (Backend)                            │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Storage  │  │ RPCs     │  │ Realtime │  │ Edge          │  │
│  │ (vidéos) │  │ (38+)    │  │ (comments│  │ Functions     │  │
│  │          │  │          │  │  likes)  │  │ (transcoding) │  │
│  └──────────┘  └──────────┘  └──────────┘  └───────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Tables : challenges, participations, likes, comments,    │  │
│  │ favorites, reports, bans, video_overlays, video_assets,  │  │
│  │ video_render_jobs, challenge_participation_videos,        │  │
│  │ video_assets (générique)                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                               │
                    (Quand Railway revient)
┌──────────────────────────────┴──────────────────────────────────┐
│                 RAILWAY (Backend lourd)                          │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                     │
│  │ Transcod │  │ Studio   │  │ Studio   │                     │
│  │ FFmpeg   │  │ AI (ASR, │  │ Audio    │                     │
│  │ pipeline │  │ analyze) │  │ (mix)    │                     │
│  └──────────┘  └──────────┘  └──────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Packages Flutter gratuits identifiés (tous open-source, 0€)

### 2.1 Éditeur vidéo

| Package | Licence | Rôle | Avantage |
|---|---|---|---|
| **`easy_video_editor: ^0.1.3`** | MIT | Trim, merge, speed, crop, rotate, flip, compress, thumbnails | **Pas de dépendance FFmpeg**, API chainable, natif Android/iOS |
| **`video_editor: ^3.0.0`** | (GPL v3 depuis FFmpeg) | Trim, crop, rotate avec UI (slider thumbnails) | UI de trimming prête à l'emploi |
| **`video_player: ^2.10.1`** | BSD | Lecture vidéo (déjà en place) | Déjà dans le projet |

### 2.2 Feed TikTok vertical

| Package | Licence | Rôle |
|---|---|---|
| **`tiktoklikescroller: ^0.2.4`** | MIT | PageView vertical optimisé pour vidéos (callbacks onChanged) |
| **Ou natif** : `PageView.builder` + pool de `VideoPlayerController` | — | Plus de contrôle, meilleure perf |

### 2.3 Studio scientifique (innovation)

| Package | Licence | Rôle |
|---|---|---|
| **`perfect_freehand: ^2.0.0`** | MIT | Dessin à main levée avec pression (stylet/doigt) — pour écrire des formules |
| **`flutter_drawing_board: ^0.4.0`** | MIT | Whiteboard complet (crayon, gomme, formes, undo/redo) |
| **`math_keyboard: ^0.3.0`** | BSD-3 | Clavier math (déjà intégré) — pour insérer des équations LaTeX |
| **`flutter_math_fork: ^0.7.2`** | MIT | Rendu TeX (déjà intégré) — pour afficher les équations sur la vidéo |
| **`gpt_markdown: ^1.1.5`** | MIT | Rendu Markdown+LaTeX (déjà intégré) |

### 2.4 Capture vidéo

| Package | Licence | Rôle |
|---|---|---|
| **`camera: ^0.11.0`** | BSD | Capture vidéo (déjà en place) |
| **`image_picker: ^1.0.7`** | Apache-2.0 | Sélection depuis galerie (déjà en place) |

### 2.5 Effets et filtres

| Package | Licence | Rôle |
|---|---|---|
| **`colorfilter_generator: ^0.1.0`** | MIT | Filtres couleur (sépia, N&B, warm, cool) appliqués en temps réel via ColorFiltered |
| **`flutter_shaders`** (natif Flutter 3.x) | — | Shaders GLSL pour effets avancés (blur, vignette) |

### 2.6 Audio

| Package | Licence | Rôle |
|---|---|---|
| **`audioplayers: ^6.0.0`** | MIT | Lecture audio (déjà en place) |
| **`record: ^6.1.2`** | MIT | Enregistrement audio (déjà en place) |

### 2.7 Social / Animations

| Package | Licence | Rôle |
|---|---|---|
| **`share_plus: ^7.2.1`** | BSD | Partage natif (déjà en place) |
| **`animate_do: ^4.2.0`** | MIT | Animations (déjà en place) |
| **`lottie`** ou **`rive`** | MIT | Animations cœur (double-tap like) |

---

## 3. Ce qui existe déjà vs ce qui manque

### 3.1 Déjà implémenté (à conserver et améliorer)

| Composant | Fichier(s) | État |
|---|---|---|
| **Feed vidéo** | `student_challenges_tab.dart` | Basique — à transformer en vrai TikTok vertical |
| **Détail challenge** | `student_challenge_detail_screen.dart` | OK — leaderboard, participations |
| **Capture vidéo** | `challenge_camera_capture_screen.dart` | OK — max 60s, switch caméra |
| **Éditeur vidéo** | `student_challenge_video_editor_screen.dart` | Partiel — overlays basiques, pas de trim/merge |
| **Overlays** | `student_challenge_video_overlays.dart` | Modèle JSONB complet (texts, equations, subtitles, stickers, ar_objects, filter, theme) |
| **AR 3D** | `student_challenge_video_ar_screen.dart` | Basique — Duck GLB seulement |
| **Social** | Provider + RPCs | Complet — likes, favorites, comments, reports, bans |
| **Modération** | Admin RPCs | Complet — review, ban, moderation_status |
| **Audio Studio** | Backend `/studio/audio/render` | OK — mix multi-pistes |
| **IA** | Backend `/studio/ai/*` | OK — transcription, analyse, proofread |
| **VideoAsset pipeline** | RPCs + table | Migré SQL, pas déployé backend |
| **Duo/Remix** | DB columns | parent_participation_id + remix_type en place |
| **Notifications** | Triggers | app_notify_challenge_created, app_notify_admin_challenge_participation |
| **Storage** | Buckets | challenge-media (public), video-assets (public) |

### 3.2 Ce qui manque (à implémenter)

| Composant | Priorité | Effort |
|---|---|---|
| **Feed TikTok vertical** (PageView, autoplay, preload, double-tap like) | P0 | 3-4 jours |
| **Éditeur vidéo** (trim, merge, speed, transitions) via easy_video_editor | P0 | 3-4 jours |
| **Studio scientifique** (zones d'écriture, équations sur vidéo, whiteboard) | P0 | 4-5 jours |
| **Export vidéo avec overlays brûlés** (overlay PNG → FFmpeg ou natif) | P1 | 2-3 jours |
| **Filtres live en capture** (ColorFiltered en temps réel) | P1 | 1-2 jours |
| **Duo/Split-screen** (UI pour filmer en réponse) | P2 | 2-3 jours |
| **Transcoding pipeline** (Edge Function Supabase ou Railway) | P1 | 2-3 jours |
| **Son original** (extraction + réutilisation par d'autres) | P2 | 1-2 jours |
| **Recommendation engine** (engagement score, trending) | P3 | 3-5 jours |

---

## 4. Plan d'implémentation rigoureux — 7 phases

### Phase 1 — Feed TikTok vertical (3-4 jours)
**Objectif** : Transformer le flux vidéo en expérience TikTok identique.

**Tâches** :
1. Refactorer `student_challenges_tab.dart` :
   - Remplacer le ListView actuel par un `PageView.builder` vertical plein écran
   - Pool de 3 `VideoPlayerController` (current, next, previous) — dispose les autres
   - Autoplay quand la vidéo est au centre, pause quand elle sort
   - Preload N+1 et N+2 pendant la lecture de N
2. UI par vidéo (overlay transparent sur la vidéo) :
   - Côté droit : boutons verticaux (profil auteur, like ❤️ avec compteur, commentaires 💬, partager ↗️, son 🎵)
   - Bas : nom auteur + description + hashtags du challenge
   - Double-tap → animation cœur + like
   - Barre de progression fine en bas
3. Bottom sheet commentaires (Realtime Supabase)
4. Pagination cursor-based (déjà en RPC `app_student_challenge_video_feed`)

**Packages** : `video_player` (existant), `share_plus` (existant), `animate_do` (existant)
**Supabase** : Aucune modification — RPCs existantes suffisent
**Railway** : Non requis

### Phase 2 — Capture vidéo améliorée (2 jours)
**Objectif** : Capture type TikTok avec timer, filtres live, multi-segments.

**Tâches** :
1. Améliorer `challenge_camera_capture_screen.dart` :
   - Timer visuel (3s, 10s, 60s) avec barre de progression
   - Bouton flash on/off
   - Switch caméra front/back (déjà fait)
   - Filtres live via `ColorFiltered` widget wrappant le CameraPreview
   - Multi-segments : enregistrer plusieurs clips, les concaténer
2. Galerie : sélection depuis galerie (déjà fait via image_picker)

**Packages** : `camera` (existant), `colorfilter_generator` (nouveau)
**Supabase** : Aucune modification
**Railway** : Non requis

### Phase 3 — Éditeur vidéo type CapCut (3-4 jours)
**Objectif** : Éditeur complet pour post-production.

**Tâches** :
1. Refactorer `student_challenge_video_editor_screen.dart` :
   - **Timeline visuelle** : thumbnails de la vidéo avec handles de trim
   - **Trim** : couper début/fin via `easy_video_editor.trim()`
   - **Speed** : 0.5x, 1x, 1.5x, 2x via `easy_video_editor.speed()`
   - **Merge** : combiner plusieurs clips via `easy_video_editor.merge()`
   - **Crop/Rotate** : via `easy_video_editor.crop()` / `.rotate()`
   - **Filtres** : appliquer warm/cool/bw/sepia (métadonnées → rendu export)
2. Preview en temps réel avec `VideoPlayerController`
3. Export avec barre de progression (`onProgress`)

**Packages** : `easy_video_editor: ^0.1.3` (nouveau), `video_player` (existant)
**Supabase** : Aucune modification — overlays JSONB existant
**Railway** : Non requis (tout est natif côté device)

### Phase 4 — Studio scientifique (4-5 jours) ⭐ INNOVATION
**Objectif** : Permettre d'écrire des équations, formules et cours directement sur la vidéo.

**Tâches** :
1. **Zone d'écriture sur vidéo** :
   - Overlay transparent positionné sur la vidéo (Stack + Positioned)
   - L'utilisateur définit une zone rectangulaire (drag to resize) sur l'écran
   - Dans cette zone : whiteboard interactif (`flutter_drawing_board` ou `perfect_freehand`)
   - Dessin à main levée (stylet ou doigt) avec couleurs, épaisseurs, gomme
   - Undo/redo
2. **Insertion d'équations LaTeX** :
   - Bouton "∑" dans la toolbar du studio → ouvre `AcademiaMathButton` (déjà créé)
   - L'équation est rendue via `flutter_math_fork` et positionnée sur la vidéo
   - Drag & drop pour repositionner, pinch to resize
3. **Insertion de texte riche** :
   - Texte avec police, taille, couleur, fond
   - Rendu Markdown+LaTeX via `AcademiaRichContent` (déjà créé)
4. **Multi-zones** :
   - Plusieurs zones d'écriture/équations sur la même vidéo
   - Timeline : chaque zone a un start_time et end_time (apparition/disparition)
5. **Sérialisation** :
   - Toutes les annotations sont sérialisées dans `overlays.layers` (JSONB)
   - Format : `{type: "drawing"|"equation"|"text", data: {...}, position: {x,y,w,h}, time: {start_ms, end_ms}}`
6. **Export** :
   - Stratégie "overlay PNG" : rendre les annotations en PNG transparent (via `PictureRecorder` + `Canvas`)
   - Uploader le PNG overlay vers Supabase Storage
   - Le backend (Railway, quand disponible) brûle l'overlay sur la vidéo via FFmpeg
   - En attendant Railway : la vidéo est lue avec l'overlay en temps réel côté Flutter (Stack)

**Packages** : `perfect_freehand: ^2.0.0` (nouveau), `flutter_drawing_board: ^0.4.0` (nouveau), `math_keyboard` (existant), `flutter_math_fork` (existant)
**Supabase** : Aucune modification — `overlays.layers` JSONB accepte déjà ce format
**Railway** : Préparé mais non requis — export final avec FFmpeg quand Railway revient

### Phase 5 — Pipeline vidéo Supabase-first (2-3 jours)
**Objectif** : Upload, transcoding et playback optimisés via Supabase.

**Tâches** :
1. **Upload optimisé** :
   - Compression côté device avant upload (`easy_video_editor.compress()`)
   - Upload vers bucket `challenge-media` ou `video-assets`
   - Créer un `video_asset` via RPC `app_videoasset_create_upload_intent`
   - Enregistrer le source via `app_videoasset_register_uploaded_source`
2. **Transcoding via Edge Function Supabase** (en attendant Railway) :
   - Créer une Edge Function `transcode-video` qui :
     - Télécharge la vidéo depuis Storage
     - Génère des résolutions (360p, 720p) via un service externe léger (ou stocke tel quel)
     - Génère une thumbnail
     - Met à jour `video_assets.status` = 'ready'
   - Alternative : utiliser les RPCs `app_videoasset_enqueue_processing` + `app_videoasset_complete_job` pour le workflow
3. **Playback adaptatif** :
   - Utiliser `app_videoasset_get_playback_manifest` pour obtenir l'URL de lecture
   - Fallback : URL directe depuis Storage

**Supabase** : Edge Function `transcode-video` (nouvelle)
**Railway** : Quand disponible, le transcoding lourd (FFmpeg multi-résolution, burn overlays) sera migré vers Railway. L'Edge Function Supabase servira de fallback léger.

### Phase 6 — Social complet + Duo (2-3 jours)
**Objectif** : Compléter l'expérience sociale type TikTok.

**Tâches** :
1. **Duo/Remix** :
   - Bouton "Duo" sur chaque vidéo du feed
   - Ouvre la capture en split-screen (vidéo originale à gauche, caméra à droite)
   - Utilise `app_student_start_duo_challenge_video` (RPC existante)
   - `remix_type` = 'duo' ou 'remix'
2. **Son original** :
   - Extraire l'audio d'une vidéo via `easy_video_editor.extractAudio()`
   - Permettre à d'autres de réutiliser ce son
   - Bouton "Utiliser ce son" → ouvre la capture avec l'audio en fond
3. **Partage** :
   - Deep link vers la vidéo (web + app)
   - Share sheet natif via `share_plus`
4. **Notifications enrichies** :
   - "X a aimé ta vidéo", "X a commenté", "Nouveau challenge disponible"
   - Utiliser les triggers existants + push notifications FCM

**Supabase** : RPCs existantes suffisent (duo, like, comment, report)
**Railway** : Non requis

### Phase 7 — Railway-ready : Backend lourd (quand Railway revient)
**Objectif** : Déployer les services lourds sur Railway.

**Tâches** :
1. **Transcoding FFmpeg** :
   - Service Docker avec FFmpeg
   - Input : vidéo brute depuis Supabase Storage
   - Output : multi-résolution (360p, 720p, 1080p) + HLS segments
   - Burn des overlays (PNG transparent) sur la vidéo finale
   - Upload des résultats vers Supabase Storage
2. **Studio AI** (déjà codé dans `academia_bobodo_backend/`) :
   - `/studio/ai/transcribe` — ASR
   - `/studio/ai/analyze` — analyse pédagogique
   - `/studio/ai/proofread` — correction texte
3. **Studio Audio** (déjà codé) :
   - `/studio/audio/render` — mix multi-pistes
4. **Workflow** :
   - Supabase `app_videoasset_enqueue_processing` → Railway poll `app_videoasset_claim_next_job` → traitement → `app_videoasset_complete_job`
   - Tout le code backend existe déjà dans `academia_bobodo_backend/main.py`

**Préparation maintenant (sans Railway)** :
- Toutes les RPCs VideoAsset sont déjà en place
- Le modèle de jobs (`challenge_video_render_jobs`) est prêt
- Le backend Python est prêt (`main.py`)
- Il suffit de `docker build` + `railway up` quand l'accès revient

---

## 5. Dépendances à ajouter au pubspec.yaml

```yaml
# Phase 2 — Filtres live
colorfilter_generator: ^0.1.0

# Phase 3 — Éditeur vidéo
easy_video_editor: ^0.1.3

# Phase 4 — Studio scientifique
perfect_freehand: ^2.0.0
flutter_drawing_board: ^0.4.0
```

**Déjà en place** : `video_player`, `camera`, `image_picker`, `share_plus`, `animate_do`, `audioplayers`, `record`, `math_keyboard`, `flutter_math_fork`, `gpt_markdown`, `cached_network_image`

---

## 6. Résumé des coûts

| Composant | Coût |
|---|---|
| Packages Flutter | **0€** (tous open-source MIT/BSD) |
| Supabase | **Inclus** dans le plan existant |
| Railway | **Inclus** quand l'accès revient |
| Services IA externes (ASR, etc.) | Dépend du provider (OpenRouter déjà configuré) |
| **Total** | **0€ de packages supplémentaires** |

---

## 7. Calendrier estimé

| Phase | Durée | Dépendance |
|---|---|---|
| Phase 1 — Feed TikTok | 3-4 jours | Aucune |
| Phase 2 — Capture améliorée | 2 jours | Aucune (parallélisable avec Phase 1) |
| Phase 3 — Éditeur CapCut | 3-4 jours | Phase 2 |
| Phase 4 — Studio scientifique | 4-5 jours | Phase 3 |
| Phase 5 — Pipeline vidéo | 2-3 jours | Phase 1 |
| Phase 6 — Social + Duo | 2-3 jours | Phase 1 |
| Phase 7 — Railway | 1-2 jours | Accès Railway |
| **Total** | **~17-23 jours** | |

Les phases 1, 2 et 5 peuvent être parallélisées. Les phases 3 et 4 sont séquentielles.

---

## 8. Fichiers Flutter à créer/modifier

### Nouveaux fichiers à créer
- `lib/features/student/challenge_tiktok_feed.dart` — Feed TikTok vertical
- `lib/features/student/challenge_video_trimmer.dart` — UI de trimming
- `lib/features/student/challenge_scientific_studio.dart` — Studio scientifique (whiteboard + équations)
- `lib/features/student/challenge_duo_screen.dart` — Écran duo/split-screen
- `lib/widgets/video_overlay_renderer.dart` — Rendu des overlays sur vidéo en temps réel
- `lib/widgets/draggable_annotation.dart` — Widget draggable/resizable pour annotations
- `supabase/functions/transcode-video/index.ts` — Edge Function transcoding

### Fichiers existants à modifier
- `student_challenges_tab.dart` — Intégrer le nouveau feed TikTok
- `student_challenge_video_editor_screen.dart` — Ajouter trim/merge/speed + studio scientifique
- `challenge_camera_capture_screen.dart` — Filtres live, timer, multi-segments
- `student_challenge_video_overlays.dart` — Étendre le modèle pour les annotations scientifiques
- `student_challenges_provider.dart` — Ajouter méthodes pour le nouveau feed et l'export

---

## 9. Stratégie Supabase-first / Railway-ready

### Principe
- **Tout ce qui peut tourner côté device** tourne côté device (trim, merge, speed, filtres, overlays)
- **Tout ce qui peut tourner via Supabase** tourne via Supabase (storage, RPCs, realtime, edge functions légères)
- **Ce qui nécessite Railway** (FFmpeg lourd, IA, audio mix) est **préparé** mais **non bloquant** — l'app fonctionne sans Railway

### Ce qui fonctionne SANS Railway
- Feed TikTok complet
- Capture vidéo avec filtres
- Éditeur vidéo (trim, merge, speed) — tout natif device
- Studio scientifique (annotations en overlay temps réel)
- Social complet (likes, comments, partage, duo)
- Upload + stockage Supabase
- Playback direct depuis Supabase Storage

### Ce qui nécessite Railway (quand disponible)
- Transcoding multi-résolution (FFmpeg)
- Burn des overlays scientifiques dans la vidéo finale
- IA : transcription ASR, analyse pédagogique, proofread
- Audio : mix multi-pistes serveur

### Transition
Quand Railway revient :
1. `docker build -t academia-backend .` dans `academia_bobodo_backend/`
2. `railway up` pour déployer
3. Configurer les variables d'environnement (SUPABASE_URL, SUPABASE_SERVICE_KEY, etc.)
4. Le backend poll les jobs via `app_videoasset_claim_next_job` et les traite
5. L'Edge Function Supabase peut être désactivée ou gardée comme fallback
