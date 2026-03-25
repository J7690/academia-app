# Audit Complet — Challenge Video Studio Academia
## 21 Mars 2026

---

## 1. CARTOGRAPHIE FLUTTER

### 1.1 Fichiers du Studio (16 fichiers, ~14 000 lignes)

| Fichier | Lignes | Role |
|---------|--------|------|
| `student_challenges_tab.dart` | 3547 | Feed TikTok plein ecran + barre bas |
| `student_challenge_video_editor_screen.dart` | 5053 | **Studio principal** |
| `challenge_camera_capture_screen.dart` | 820 | Camera TikTok-style |
| `challenge_video_edit_screen.dart` | 592 | Editeur CapCut-style |
| `challenge_scientific_studio_screen.dart` | 1053 | Studio scientifique |
| `video_publish_screen.dart` | 531 | Ecran publication |
| `student_challenge_video_overlays.dart` | 81 | Model overlays |
| `student_challenge_video_ar_screen.dart` | ~400 | AR 3D |
| `student_challenge_video_ar_combined_screen.dart` | ~300 | AR combine |
| `student_challenge_detail_screen.dart` | ~800 | Detail challenge |
| `student_social_profile_screen.dart` | ~600 | Profil TikTok |
| `student_recently_deleted_videos_screen.dart` | ~200 | Corbeille |
| `challenge_live_screen.dart` | 426 | Live TikTok 1-N |
| `challenge_live_duo_screen.dart` | 380 | Live Duo split |
| `admin_challenges_screen.dart` | ~400 | Admin challenges |

### 1.2 Services support (6 fichiers)

| Fichier | Lignes | Role |
|---------|--------|------|
| `videoasset_upload_service.dart` | 145 | Pipeline upload unifie |
| `audio_mix_service.dart` | 333 | Mixage audio DJ via FFmpeg |
| `overlay_burn_in_service.dart` | 175 | Burn-in overlays dans MP4 |
| `studio_video_service.dart` | ~200 | Services video utilitaires |
| `academia_playback_engine.dart` | ~400 | Moteur lecture video unifie |
| `student_challenges_provider.dart` | 2269 | Provider RPCs challenges/videos |

### 1.3 Widgets support (5 fichiers)

| Fichier | Role |
|---------|------|
| `video_overlays_layer.dart` | Rendu overlays temps reel |
| `audio_picker_sheet.dart` | Selection piste audio |
| `dj_mix_sheet.dart` | Mixage DJ (faders volume) |
| `equation_editor.dart` | Editeur equations LaTeX |
| `student_video_player.dart` | Player video generique |

---

## 2. CARTOGRAPHIE SUPABASE

### 2.1 Tables (33 tables dans schema `app`)

**Tables principales Challenge/Video :**

| Table | Colonnes | Role |
|-------|----------|------|
| `challenges` | 17 | Definition des challenges (titre, type, difficulte, points, dates) |
| `challenge_participations` | 23 | Participation etudiant a un challenge (status, score, video_asset_id, playback) |
| `challenge_participation_videos` | 4 | Association participation <-> video clips |
| `challenge_video_assets` | 7 | Assets audio/stickers du studio |
| `challenge_video_overlays` | 4 | Overlays JSON par participation |
| `challenge_video_render_jobs` | 9 | Jobs de rendu video (burn-in overlays) |
| `challenge_comments` | 7 | Commentaires sur challenges |
| `challenge_likes` | 4 | Likes sur challenges |
| `challenge_favorites` | 4 | Favoris challenges |
| `challenge_reports` | 9 | Signalements challenges |
| `challenge_user_bans` | 6 | Bannissements challenges |
| `free_videos` | 18 | Videos libres (hors challenge) |
| `free_video_overlays` | 4 | Overlays JSON par free_video |
| `free_video_render_jobs` | 9 | Jobs de rendu free videos |

**Tables systeme Video :**

| Table | Colonnes | Role |
|-------|----------|------|
| `video_assets` | 15 | Asset video centralise (status, owner, origin, metadata) |
| `video_sources` | 10 | Sources fichier (bucket, path, mime, size, checksum) |
| `video_renditions` | 15 | Renditions transcodees (original, 480p, 720p...) |
| `video_asset_contexts` | 6 | Contexte d'un asset (challenge, free_video, hero...) |
| `video_asset_legacy_map` | 6 | Mapping ancien systeme -> nouveau |
| `video_processing_jobs` | 11 | Jobs de processing video |
| `video_upload_events` | 8 | Evenements d'upload |
| `video_playback_errors` | 9 | Erreurs de lecture telemetrie |
| `video_moderation_history` | 9 | Historique moderation |

**Tables sociales Video :**

| Table | Colonnes | Role |
|-------|----------|------|
| `video_comments` | 8 | Commentaires unifies (video_type + video_id) |
| `video_likes` | 5 | Likes unifies |
| `video_favorites` | 5 | Favoris unifies |
| `video_reports` | 10 | Signalements unifies |

**Autres :**

| Table | Role |
|-------|------|
| `hero_videos` | Videos hero landing |
| `hero_video_jobs` | Jobs encoding hero |
| `landing_videos` | Videos landing page |
| `student_home_videos` | Videos page accueil etudiant |
| `league_participations` | Participations ligues |
| `legacy_video_write_attempts` | Tentatives ecriture legacy |

### 2.2 Donnees existantes

| Table | Count |
|-------|-------|
| challenges | 1 |
| challenge_participations | 2 |
| video_assets | 181 |
| free_videos | 103 |

### 2.3 Storage Buckets

| Bucket | Public | Role |
|--------|--------|------|
| `challenge-media` | oui | Videos/medias challenges |
| `video-assets` | oui | Pipeline video unifie |
| `hero_videos` | oui | Videos hero |
| `community-media` | oui | Medias communautes |
| `university-media` | oui | Medias universites |
| `landing-media` | oui | Medias landing |
| `marketplace-media` | oui | Medias marketplace |

### 2.4 RPCs (55+ fonctions)

**Challenge RPCs :**
- `app_admin_create_challenge` / `app_admin_update_challenge`
- `app_admin_list_challenges` / `app_admin_delete_challenge_video`
- `app_admin_list_challenge_reports` / `app_admin_handle_challenge_report`
- `app_student_list_challenges` / `app_student_join_challenge`
- `app_student_submit_challenge` / `app_student_mark_challenge_completed`
- `app_student_list_my_challenge_participations`
- `app_student_list_my_challenge_videos`
- `app_student_get_my_challenge_stats`
- `app_student_set_challenge_main_video`

**Video RPCs :**
- `app_student_add_challenge_video` / `app_student_create_free_video`
- `app_student_unified_video_feed` (feed TikTok unifie)
- `app_student_list_user_videos` / `app_student_list_recently_deleted_videos`
- `app_student_soft_delete_video` / `app_student_restore_video`
- `app_student_set_video_allow_download`
- `app_student_set_free_video_main_renditions`

**Social RPCs :**
- `app_student_like_challenge_video` / `app_student_unlike_challenge_video`
- `app_student_video_like` / `app_student_video_unlike`
- `app_student_video_favorite` / `app_student_video_unfavorite`
- `app_student_favorite_challenge_video` / `app_student_unfavorite_challenge_video`
- `app_student_list_challenge_comments` / `app_student_list_video_comments`
- `app_student_add_challenge_comment` / `app_student_add_video_comment`
- `app_student_delete_challenge_comment` / `app_student_delete_video_comment`
- `app_student_report_challenge_video` / `app_student_report_video`

**Overlays RPCs :**
- `app_student_update_challenge_video_overlays`
- `app_student_update_free_video_overlays`

**Duo RPCs :**
- `app_student_start_duo_challenge_video`
- `app_student_start_duo_video`

**Export RPCs :**
- `app_student_request_video_export_watermarked`
- `app_student_get_video_export_watermarked_status`
- `app_student_list_challenge_video_render_jobs`
- `app_student_list_free_video_render_jobs`

**VideoAsset Pipeline RPCs :**
- `app_videoasset_create_upload_intent`
- `app_videoasset_register_uploaded_source`
- `app_videoasset_enqueue_processing`
- `app_videoasset_claim_next_job` / `app_videoasset_complete_job`
- `app_videoasset_get_playback_manifest`
- `app_videoasset_get_playback_for_direct_url`

### 2.5 Edge Functions

| Fonction | Role |
|----------|------|
| `transcode-video` | Marque video_asset ready + cree rendition "original" |
| `livekit-token` | Token JWT pour sessions live |
| `livekit-recording` | Start/Stop enregistrement egress |

---

## 3. FLUX COMPLET : Bouton "+" du feed -> Publication

### Etape 1 : TAP sur le bouton "+"

**Fichier** : `student_challenges_tab.dart` ligne 1330
**Widget** : `_buildTikTokBottomBar` > bouton central "+"
**Action** : appelle `_openCreateVideoFromFeed(context)`

```
Feed TikTok (PageView vertical)
    |
    v
_buildTikTokBottomBar()  <-- barre TikTok en bas
    |
    [+] bouton central vert gradient
    |
    v
_openCreateVideoFromFeed()  ligne 1470
```

### Etape 2 : Ouverture Camera TikTok

**Fichier** : `student_challenges_tab.dart` ligne 1476
**Action** : `Navigator.push` → `ChallengeCameraCaptureScreen()`

```
_openCreateVideoFromFeed()
    |
    v
ChallengeCameraCaptureScreen(maxDuration: 60s)
    |
    Camera back par defaut (front sur web)
    ResolutionPreset.medium, audio=true
```

### Etape 3 : Capture Video dans la Camera

**Fichier** : `challenge_camera_capture_screen.dart` (820 lignes)

**Fonctionnalites camera :**
1. **Filtres live** : Normal, Chaud, Froid, N&B, Sepia, Vif (ColorFilter.matrix)
2. **Timer countdown** : off, 3s, 5s, 10s avant enregistrement
3. **Multi-segments** : enregistrer plusieurs clips, supprimer le dernier
4. **Flash** : toggle torche (back camera)
5. **Switch camera** : front/back
6. **Vitesse** : 0.5x, 1x, 2x, 3x
7. **Barre progression** : multi-segments coloree
8. **Bouton record** : tap = start/stop, auto-stop quand max duration atteinte

**Flux interne :**
```
_onRecordButtonPressed()
    |
    si countdown > 0 : _startCountdown() -> _startRecording()
    sinon : _startRecording()
    |
    v
controller.startVideoRecording()
    |
    Timer.periodic(100ms) -> track elapsed
    |
    auto-stop si maxDuration atteinte
    |
    v
controller.stopVideoRecording() -> XFile
    |
    _segments.add(RecordedSegment(file, duration))
    |
    [Utilisateur peut re-enregistrer un autre segment ou valider]
    |
    v
_finishRecording()
    |
    Navigator.pop(segments: List<XFile>)
```

### Etape 4 : Retour au Feed -> Ouverture Studio

**Fichier** : `student_challenges_tab.dart` ligne 1486
**Action** : si segments non vides → ouvre le Studio

```
segments = await Navigator.push(ChallengeCameraCaptureScreen)
    |
    si segments != null && non vides
    |
    v
StudentChallengeVideoEditorScreen(
    videoType: 'free',
    initialMode: 'camera',
    initialSegments: segments,
)
```

### Etape 5 : Studio Principal — Traitement initial

**Fichier** : `student_challenge_video_editor_screen.dart` (5053 lignes)

```
initState() -> _handleInitialCaptureMode('camera')
    |
    si initialSegments non vide : _processSegments(segments)
    sinon : _openCameraCaptureFlow()
    |
    v
_processSegments(List<XFile>)
    |
    Lit le premier segment en bytes
    |
    setState: _videoBytes, _fileName, _mimeType, _localVideoPath
    |
    [Video chargee en memoire, prete pour edition]
```

### Etape 5b : Alternative — Upload depuis galerie

```
_handleInitialCaptureMode('gallery')
    |
    v
_pickVideo()
    |
    FilePicker.platform.pickFiles(mp4/mov/webm/mkv)
    |
    v
_compressAndSetVideo(filePath, name)
    |
    1. VideoThumbnail.thumbnailData() -> _thumbnailBytes
    2. VideoCompress.compressVideo(MediumQuality) -> compressed
    3. setState: _videoBytes, _localVideoPath
```

### Etape 6 : Outils d'Edition dans le Studio

Le Studio propose ces outils dans la toolbar :

| Outil | Action | Fichier |
|-------|--------|---------|
| **Filmer** | Relance la camera | `_recordVideoWithCamera()` |
| **Uploader** | Ouvre FilePicker | `_pickVideo()` |
| **Upload** | Envoie au serveur | `_uploadVideo()` |
| **Texte** | Ajoute overlay texte | `_overlayTextController` |
| **Equation** | Ajoute LaTeX | `EquationEditor` |
| **Sous-titres** | Ajoute sous-titres | `_subtitleController` |
| **Sticker** | Ajoute sticker | `_selectedSticker` |
| **Filtre** | Applique filtre | `_selectedFilter` (none/warm/cool/bw) |
| **Theme** | Change background | `_backgroundTheme` |
| **Audio/DJ** | Mixage audio | `AudioPickerSheet` + `DjMixSheet` |
| **Science** | Whiteboard+LaTeX | `ChallengeScientificStudioScreen` |
| **AR 3D** | Objets AR | `StudentChallengeVideoArScreen` |
| **Edit** | Trim/crop/rotate | `ChallengeVideoEditScreen` |
| **Zones** | Zones interactives | `_zones` list |
| **Multi-clips** | Extra clips | `_extraClips` |
| **Publier** | Ecran publication | `VideoPublishScreen` |

### Etape 7 : Upload Video au Serveur

**Fichier** : `student_challenge_video_editor_screen.dart` ligne 560

```
_uploadVideo()
    |
    ========= PIPELINE PRIMAIRE: VideoAssetUploadService =========
    |
    1. app_videoasset_create_upload_intent(origin, context_type, mime, size)
       |
       -> Retourne: storage_bucket, storage_path, source_id
    |
    2. Supabase.storage.from(bucket).uploadBinary(path, bytes)
       |
       -> Upload physique vers bucket "video-assets"
    |
    3. app_videoasset_register_uploaded_source(source_id)
       |
       -> Retourne: video_asset_id
    |
    4. Edge Function "transcode-video"(video_asset_id)
       |
       -> Marque video_asset ready
       -> Cree rendition "original"
       -> Retourne: playback {best_url, poster_url}
    |
    ========= FALLBACK: Upload direct Storage =========
    (si pipeline echoue)
    |
    provider.uploadFreeVideo(bytes, fileName)
    ou provider.uploadChallengeVideo(bytes, fileName, challengeId)
       |
       -> Upload direct vers bucket "challenge-media"
       -> Retourne: URL publique
    |
    ========= RESOLUTION PLAYBACK =========
    |
    Cascade de resolution :
    1. Resultat transcode (playback)
    2. fetchPlaybackForVideoAsset(videoAssetId)
    3. fetchPlaybackForDirectUrl(directUrl)
    4. fetchPublicUrlForVideoAssetSource(videoAssetId)
    5. Ultimate fallback: directUploadUrl brute
    |
    ========= ENREGISTREMENT EN DB =========
    |
    si free_video :
        provider.createFreeVideo(videoAssetId, playback)
        ou provider.updateFreeVideoMainRenditions(...)
    si challenge :
        stocker pendingChallengeVideoAssetId + pendingChallengePlayback
```

### Etape 8 : Ecran de Publication

**Fichier** : `video_publish_screen.dart` (531 lignes)

```
VideoPublishScreen(
    videoUrl, videoType, challengeId, participationId,
    freeVideoId, overlays, thumbnailBytes,
    pendingVideoAssetId, pendingPlayback,
)
    |
    v
Affichage :
    - Apercu video (AcademiaPlaybackEngine)
    - Champ caption (TextEditingController)
    - Champ hashtags
    - Selecteur visibilite (public/friends/private)
    - Bouton "Publier"
```

### Etape 9 : Publication finale

```
_publish()
    |
    1. Upload thumbnail si disponible
       provider.uploadThumbnail(bytes, videoFileName)
    |
    2. Resoudre video_asset_id + playback
       _resolveAssetAndPlayback()
    |
    ====== SI FREE VIDEO ======
    |
    si pas de freeVideoId :
        provider.createFreeVideo(videoAssetId, playback, title, description)
        -> RPC: app_student_create_free_video
        -> INSERT app.free_videos
    |
    sinon :
        provider.updateFreeVideoMainRenditions(freeVideoId, videoAssetId, playback)
        -> RPC: app_student_set_free_video_main_renditions
        -> UPDATE app.free_videos
    |
    Sauvegarder overlays :
        provider.updateFreeVideoOverlays(freeVideoId, layers)
        -> RPC: app_student_update_free_video_overlays
        -> UPSERT app.free_video_overlays
    |
    ====== SI CHALLENGE VIDEO ======
    |
    Sauvegarder overlays :
        provider.updateChallengeVideoOverlays(participationId, layers)
        -> RPC: app_student_update_challenge_video_overlays
        -> UPSERT app.challenge_video_overlays
    |
    Associer video au challenge :
        provider.addChallengeVideo(participationId, videoAssetId, playback)
        -> RPC: app_student_add_challenge_video
        -> UPDATE app.challenge_participations SET video_asset_id, playback
    |
    Soumettre le challenge :
        provider.submitChallenge(participationId, submissionText, submissionUrl)
        -> RPC: app_student_submit_challenge
        -> UPDATE app.challenge_participations SET status='submitted'
    |
    ====== RESULTAT ======
    |
    Navigator.pop(true) -> retour au Studio -> retour au Feed
    Feed se recharge avec la nouvelle video en position 0
```

---

## 4. DIAGRAMME DE FLUX SIMPLIFIE

```
[Feed TikTok] --(tap +)--> [Camera TikTok]
                                |
                            (segments)
                                |
                                v
                         [Studio Principal]
                          /      |      \
                    [Camera] [Gallery] [Edit CapCut]
                         \      |      /
                          v     v     v
                      [Compression video_compress]
                                |
                                v
                        [Upload Serveur]
                    /                       \
        [VideoAsset Pipeline]       [Direct Storage Fallback]
            |                               |
        create_intent               uploadBinary(bucket)
        uploadBinary                        |
        register_source                     v
        transcode-video             URL publique directe
            |
            v
        playback manifest
            |
            v
        [Enregistrement DB]
        free_videos OU challenge_participations
            |
            v
        [Ecran Publication]
        caption + hashtags + visibilite
            |
            v
        [Publication finale]
        create/update free_video
        OU add_challenge_video + submit
        + sauvegarder overlays
            |
            v
        [Retour Feed - video visible]
```

---

## 5. PACKAGES UTILISES

| Package | Version | Role |
|---------|---------|------|
| `camera` | ^0.11.0 | Capture camera native |
| `video_compress` | ^3.1.3 | Compression H.264 hardware |
| `video_thumbnail` | ^0.5.6 | Generation thumbnails JPEG |
| `file_picker` | ^8.0.0 | Selection fichiers galerie |
| `video_player` | ^2.9.2 | Lecture video (editeur CapCut) |
| `easy_video_editor` | ^1.0.0 | Trim/crop/rotate/merge/compress |
| `ffmpeg_kit_flutter_new_audio` | latest | Mixage audio FFmpeg |
| `pro_video_editor` | latest | Burn-in overlays composite |
| `perfect_freehand` | latest | Dessin whiteboard (strokes) |
| `flutter_math_fork` | ^0.7.2 | Rendu LaTeX equations |
| `livekit_client` | ^2.6.4 | WebRTC live streaming |
| `supabase_flutter` | latest | Backend + Storage |

---

## 6. POINTS CRITIQUES / OBSERVATIONS

### Fonctionnel
- **Pipeline VideoAsset** est robuste avec 5 niveaux de fallback pour la resolution playback
- **Multi-segments camera** code mais seul le premier segment est utilise (fusion multi-segments pas encore implementee)
- **Compression** via `video_compress` (MediumQuality), fallback si echec
- **Overlays** sont stockes en JSON dans Supabase, rendus cote client en temps reel
- **Burn-in overlays** existe (`OverlayBurnInService`) pour export watermarke

### Donnees
- 181 video_assets en base, 103 free_videos, 2 participations, 1 challenge
- Bucket `video-assets` et `challenge-media` sont publics sans limite de taille

### Ce qui manque / a ameliorer
- Fusion multi-segments (actuellement seul le 1er segment est utilise)
- Trim/crop dans le Studio ne re-uploade pas automatiquement le resultat edite
- Pas de preview audio mix avant publication
- Pas de watermark automatique a l'export (seulement sur demande)
- Pas de transcoding multi-resolution cote serveur (seulement "original")
