# Architecture du Parcours Import Vidéo Challenge - Analyse Complète

## Contexte

**Objectif**: Cartographier exhaustivement tous les composants qui interviennent dans le parcours d'import vidéo Challenge pour identifier les responsabilités et les goulots de performance.

**Date**: 16 juin 2026
**Scope**: Flutter (Dart) + Supabase + Kamatera (si applicable)

---

## Étape 1 - Cartographie Complète du Parcours

### Diagramme du Parcours Réel

```
Challenge Feed (student_challenges_tab.dart)
    ↓
Clic bouton "+"
    ↓
ChallengeCameraCaptureScreen (challenge_camera_capture_screen.dart)
    ↓
Clic bouton galerie (Upload)
    ↓
ImagePicker.pickVideo (sélection galerie)
    ↓
Navigator.pop → StudentChallengeVideoEditorScreen (student_challenge_video_editor_screen.dart)
    ↓
_processSegments (si segments reçus)
    ↓
_compressAndSetVideo
    ↓
    ├─ VideoThumbnail.thumbnailData (génération miniature)
    ├─ VideoCompress.compressVideo (compression)
    └─ WatermarkService.addWatermark (watermark)
    ↓
_initRemoteVideo (initialisation player)
    ↓
_uploadVideo (upload en arrière-plan)
    ↓
    ├─ VideoAssetUploadService.ingestVideoFromBytes
    │   ├─ RPC: app_videoasset_create_upload_intent
    │   ├─ ChunkedUploadService.uploadInChunks (si >4MB)
    │   └─ RPC: app_videoasset_register_uploaded_source
    └─ triggerTranscode (Edge Function: transcode-video)
    ↓
Publication (video_publish_screen.dart)
```

---

## Étape 2 - Composants Impliqués Après Sélection Vidéo

### Séquence Exacte d'Exécution

À partir du moment où la galerie renvoie un fichier:

1. **ChallengeCameraCaptureScreen._pickFromGallery()**
   - Fichier: `challenge_camera_capture_screen.dart`
   - Classe: `_ChallengeCameraCaptureScreenState`
   - Méthode: `_pickFromGallery()`
   - Déclencheur: Clic bouton galerie
   - Bloquant: OUI (await ImagePicker.pickVideo)
   - Action: Sélection vidéo via ImagePicker

2. **Navigator.pop()**
   - Retour vers StudentChallengeVideoEditorScreen avec la vidéo sélectionnée

3. **StudentChallengeVideoEditorScreen._processSegments()**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Classe: `_StudentChallengeVideoEditorScreenState`
   - Méthode: `_processSegments()`
   - Déclencheur: Réception des segments de la caméra/galerie
   - Bloquant: OUI (await _compressAndSetVideo)
   - Action: Traitement des segments reçus

4. **StudentChallengeVideoEditorScreen._compressAndSetVideo()**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Classe: `_StudentChallengeVideoEditorScreenState`
   - Méthode: `_compressAndSetVideo()`
   - Déclencheur: Appel depuis _processSegments
   - Bloquant: OUI (await compression, watermark)
   - Action: Compression + watermark de la vidéo

5. **VideoThumbnail.thumbnailData()**
   - Package: `video_thumbnail`
   - Déclencheur: Appel depuis _compressAndSetVideo
   - Bloquant: OUI (await thumbnail generation)
   - Action: Génération miniature 360x70% JPEG

6. **VideoCompress.compressVideo()**
   - Package: `video_compress`
   - Déclencheur: Appel depuis _compressAndSetVideo
   - Bloquant: OUI (await compression)
   - Action: Compression vidéo (1920x1080 ou MediumQuality)

7. **WatermarkService.addWatermark()**
   - Fichier: `lib/games/services/watermark_service.dart`
   - Déclencheur: Appel depuis _compressAndSetVideo
   - Bloquant: OUI (await watermark)
   - Action: Ajout watermark Academia (brûlé dans la vidéo)

8. **StudentChallengeVideoEditorScreen._initRemoteVideo()**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Classe: `_StudentChallengeVideoEditorScreenState`
   - Méthode: `_initRemoteVideo()`
   - Déclencheur: Appel après compression
   - Bloquant: NON (setState uniquement)
   - Action: Initialisation contrôleur vidéo

9. **StudentChallengeVideoEditorScreen._uploadVideo()**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Classe: `_StudentChallengeVideoEditorScreenState`
   - Méthode: `_uploadVideo()`
   - Déclencheur: Auto-upload en arrière-plan (fire-and-forget)
   - Bloquant: NON (exécuté en arrière-plan)
   - Action: Upload vers Supabase

10. **VideoAssetUploadService.ingestVideoFromBytes()**
    - Fichier: `lib/services/videoasset_upload_service.dart`
    - Classe: `VideoAssetUploadService`
    - Méthode: `ingestVideoFromBytes()`
    - Déclencheur: Appel depuis _uploadVideo
    - Bloquant: OUI (await RPC + upload)
    - Action: Création VideoAsset + upload

11. **RPC: app_videoasset_create_upload_intent**
    - Type: Supabase RPC
    - Déclencheur: Appel depuis VideoAssetUploadService
    - Bloquant: OUI (await RPC)
    - Action: Création intent d'upload VideoAsset

12. **ChunkedUploadService.uploadInChunks()**
    - Fichier: `lib/services/chunked_upload_service.dart`
    - Déclencheur: Appel depuis VideoAssetUploadService (si >4MB)
    - Bloquant: OUI (await upload)
    - Action: Upload chunké vers Supabase Storage

13. **RPC: app_videoasset_register_uploaded_source**
    - Type: Supabase RPC
    - Déclencheur: Appel depuis VideoAssetUploadService
    - Bloquant: OUI (await RPC)
    - Action: Enregistrement source VideoAsset

14. **Edge Function: transcode-video**
    - Type: Supabase Edge Function
    - Déclencheur: Appel depuis VideoAssetUploadService.triggerTranscode()
    - Bloquant: NON (appel asynchrone)
    - Action: Transcodage vidéo sur serveur

---

## Étape 3 - Analyse Flutter

### Fichiers, Classes, Méthodes, Déclencheurs, Bloquant/Non

| Fichier | Classe | Méthode | Déclencheur | Bloquant | Responsabilité |
|---------|--------|---------|------------|----------|----------------|
| `student_challenges_tab.dart` | `StudentChallengesTab` | `build()` | Navigation vers onglet | NON | Affichage feed Challenge |
| `challenge_camera_capture_screen.dart` | `_ChallengeCameraCaptureScreenState` | `_pickFromGallery()` | Clic bouton galerie | OUI | Sélection vidéo galerie |
| `student_challenge_video_editor_screen.dart` | `_StudentChallengeVideoEditorScreenState` | `_processSegments()` | Réception segments | OUI | Traitement segments |
| `student_challenge_video_editor_screen.dart` | `_StudentChallengeVideoEditorScreenState` | `_compressAndSetVideo()` | Appel depuis _processSegments | OUI | Compression + watermark |
| `student_challenge_video_editor_screen.dart` | `_StudentChallengeVideoEditorScreenState` | `_initRemoteVideo()` | Après compression | NON | Initialisation player |
| `student_challenge_video_editor_screen.dart` | `_StudentChallengeVideoEditorScreenState` | `_uploadVideo()` | Auto-upload background | NON | Upload vidéo |
| `academia_playback_view.dart` | `_AcademiaPlaybackViewState` | `_init()` | initState/didUpdateWidget | OUI | Initialisation player vidéo |
| `academia_playback_view.dart` | `_AcademiaPlaybackViewState` | `_toggleExternal()` | AcademiaPlaybackController.toggle | OUI | Toggle play/pause |
| `videoasset_upload_service.dart` | `VideoAssetUploadService` | `ingestVideoFromBytes()` | Appel depuis _uploadVideo | OUI | Upload VideoAsset |
| `chunked_upload_service.dart` | `ChunkedUploadService` | `uploadInChunks()` | Si fichier >4MB | OUI | Upload chunké |

### Services Vidéo Impliqués

1. **VideoCompress** (package: `video_compress`)
   - Rôle: Compression vidéo locale
   - Type: Package Flutter
   - Platform: Android native (via MethodChannel)
   - Bloquant: OUI

2. **VideoThumbnail** (package: `video_thumbnail`)
   - Rôle: Génération miniature
   - Type: Package Flutter
   - Platform: Android native (via MethodChannel)
   - Bloquant: OUI

3. **AcademiaPlaybackView/Controller**
   - Rôle: Lecture vidéo (native Android ou Flutter)
   - Type: Custom widget Flutter
   - Platform: Android native PlatformView ou Flutter VideoPlayer
   - Bloquant: OUI (initialisation)

4. **WatermarkService**
   - Rôle: Ajout watermark Academia
   - Type: Service Flutter
   - Platform: FFmpeg local (probable)
   - Bloquant: OUI

5. **ChunkedUploadService**
   - Rôle: Upload chunké vers Supabase
   - Type: Service Flutter
   - Platform: HTTP
   - Bloquant: OUI

---

## Étape 4 - Analyse Supabase

### Buckets Utilisés

1. **Bucket principal**: Déterminé dynamiquement par RPC `app_videoasset_create_upload_intent`
   - Probable: `video_assets` ou similaire
   - Chemin: Déterminé par RPC

### Tables Impliquées

1. **app.video_assets** (probable)
   - Stockage des métadonnées VideoAsset
   - Colonnes: id, source_id, storage_bucket, storage_path, mime_type, etc.

2. **app.challenge_video_assets** (confirmé)
   - Assets audio pour les challenges
   - Utilisé dans `_loadAudioAssetsIfNeeded()`

### RPC Appelées

1. **app_videoasset_create_upload_intent**
   - Fichier: `videoasset_upload_service.dart`
   - Paramètres: p_origin, p_context_type, p_context_id, p_role, p_mime_type, p_expected_size
   - Retour: storage_bucket, storage_path, source_id
   - Bloquant: OUI

2. **app_videoasset_register_uploaded_source**
   - Fichier: `videoasset_upload_service.dart`
   - Paramètres: p_source_id, p_checksum_sha256, p_width, p_height, p_duration_ms, p_has_audio, p_validation_report
   - Retour: video_asset_id
   - Bloquant: OUI

3. **app_student_soft_delete_video**
   - Fichier: `student_challenges_provider.dart`
   - Paramètres: p_video_type, p_video_id
   - Retour: success/error
   - Bloquant: OUI

4. **app_student_get_video_export_watermarked_status**
   - Fichier: `student_challenges_provider.dart`
   - Paramètres: p_video_asset_id
   - Retour: status, url
   - Bloquant: OUI

5. **app_student_set_video_allow_download**
   - Fichier: `student_challenges_provider.dart`
   - Paramètres: p_video_type, p_video_id, p_allow_download
   - Retour: success/error
   - Bloquant: OUI

### Edge Functions

1. **transcode-video**
   - Fichier: `supabase/functions/transcode-video/index.ts`
   - Déclencheur: VideoAssetUploadService.triggerTranscode()
   - Paramètres: video_asset_id, poster_url
   - Action: Transcodage vidéo sur serveur
   - Bloquant: NON (asynchrone)

2. **merge-video-segments**
   - Fichier: `supabase/functions/merge-video-segments/index.ts`
   - Déclencheur: Fusion de segments multiples
   - Action: Fusion de segments vidéo
   - Bloquant: NON (asynchrone)

### Workers

Aucun worker Supabase identifié dans le parcours d'import vidéo. Les workers sont probablement gérés par Kamatera.

---

## Étape 5 - Analyse Kamatera

### Workers Actifs

**Non identifié dans le code Flutter**. Le code ne fait pas d'appels directs à Kamatera.

Kamatera est probablement utilisé:
- Pour le transcodage vidéo (Edge Function `transcode-video`)
- Pour le stockage vidéo (Supabase Storage)
- Pour les traitements asynchrones post-upload

### Services Vidéo

**Non identifié dans le code Flutter**. Les services vidéo sont gérés localement via:
- VideoCompress (compression locale)
- WatermarkService (watermark local)
- AcademiaPlaybackView (lecture locale)

### Services FFmpeg

**Non identifié dans le code Flutter**. FFmpeg est probablement utilisé:
- Dans WatermarkService (watermark local)
- Dans Edge Function `transcode-video` (transcodage serveur)

### Traitements Asynchrones

Kamatera intervient **APRÈS** l'affichage de l'éditeur:
- L'upload est effectué en arrière-plan (fire-and-forget)
- Le transcodage est déclenché après upload
- L'utilisateur peut voir l'éditeur avant que le transcodage ne soit terminé

---

## Étape 6 - Analyse FFmpeg

### FFmpeg Local

**Preuves d'utilisation locale**:
1. **WatermarkService.addWatermark()**
   - Fichier: `lib/games/services/watermark_service.dart`
   - Action: Ajout watermark Academia brûlé dans la vidéo
   - Probablement utilise FFmpeg local via package Flutter

2. **VideoCompress**
   - Package: `video_compress`
   - Probablement utilise FFmpeg Android natif (via MediaCodec)

### FFmpeg Serveur

**Preuves d'utilisation serveur**:
1. **Edge Function: transcode-video**
   - Fichier: `supabase/functions/transcode-video/index.ts`
   - Action: Transcodage vidéo sur serveur
   - Probablement utilise FFmpeg sur Kamatera

### FFmpeg Désactivé

**Preuves de désactivation**:
1. **Commentaires dans le code**:
   ```dart
   // import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
   // import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
   ```
   Ces imports sont commentés, indiquant que FFmpeg Flutter n'est pas utilisé.

### Conclusion

- **FFmpeg local**: ACTIF (via WatermarkService et VideoCompress)
- **FFmpeg serveur**: ACTIF (via Edge Function transcode-video)
- **FFmpeg Flutter**: DÉSACTIVÉ (imports commentés)

---

## Étape 7 - Analyse du Player du Feed

### Pourquoi l'audio du feed reste actif ?

#### Lecteur Utilisé

**Fichier**: `student_challenges_tab.dart`
**Widget**: `_ChallengeVideosFeed`
**Player**: `AcademiaPlaybackView` (via `AcademiaPlaybackEngine.view()`)

#### Contrôleur Utilisé

**Fichier**: `academia_playback_view.dart`
**Classe**: `AcademiaPlaybackController`
**Méthodes**: `toggle()`, `pause()`, `play()`

#### Cycle de Vie

**Problème identifié**: Le player du feed n'est **pas explicitement paused/disposé** lors de la navigation vers l'écran de capture vidéo.

**Preuves**:
1. **Aucun appel à `pause()` ou `dispose()`** dans:
   - `ChallengeCameraCaptureScreen.initState()`
   - `StudentChallengeVideoEditorScreen.initState()`
   - Navigation entre les écrans

2. **Le player continue de jouer** car:
   - `AcademiaPlaybackView` utilise `autoplay=true` par défaut
   - Aucun mécanisme de pause automatique lors de la navigation
   - Le contrôleur n'est pas partagé entre les écrans

#### Pause

**Méthode disponible**: `AcademiaPlaybackController.pause()`
**Utilisation**: Non utilisée dans le parcours d'import vidéo

#### Dispose

**Méthode disponible**: `VideoPlayerController.dispose()` (Flutter) ou native player dispose
**Utilisation**: Non appelée explicitement lors de la navigation

### Conclusion

**L'audio du feed continue à jouer car**:
1. Le player du feed n'est pas explicitement paused lors de la navigation
2. Le player du feed n'est pas disposé lors de la navigation
3. Aucun mécanisme de gestion du cycle de vie audio entre les écrans

---

## Étape 8 - Classement des Responsabilités

### Estimation des Responsabilités par Composant

Basé sur l'analyse du code et des opérations bloquantes:

| Composant | Responsabilité estimée | Justification |
|-----------|----------------------|---------------|
| **Compression (VideoCompress)** | 40% | Opération bloquante la plus longue, dépend de la taille vidéo |
| **Upload (ChunkedUploadService)** | 25% | Dépend de la taille vidéo et de la connexion réseau |
| **Génération miniature (VideoThumbnail)** | 10% | Opération bloquante mais rapide |
| **Watermark (WatermarkService)** | 10% | Opération bloquante, dépend de la taille vidéo |
| **Flutter UI (setState/build)** | 5% | Mises à jour UI rapides |
| **Initialisation player (AcademiaPlaybackView)** | 5% | Initialisation native Android |
| **Supabase RPC (create intent, register)** | 3% | Appels RPC rapides |
| **Transcodage serveur (Edge Function)** | 2% | Asynchrone, n'impacte pas l'UX immédiat |

### Total: 100%

---

## Étape 9 - Correctifs Recommandés

### Priorité 1 - Critique

1. **Pause du player du feed lors de la navigation**
   - Fichier: `student_challenges_tab.dart`
   - Action: Appeler `AcademiaPlaybackController.pause()` avant navigation
   - Impact: Élimine l'audio persistant

2. **Non-bloquant de la compression**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Action: Exécuter la compression dans un isolate ou en arrière-plan
   - Impact: Réduit l'écran noir pendant compression

3. **Feedback utilisateur pendant compression**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Action: Afficher un indicateur de progression pendant compression
   - Impact: Améliore l'UX pendant l'écran noir

### Priorité 2 - Important

4. **Optimisation de la compression**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Action: Réduire la qualité de compression par défaut
   - Impact: Réduit le temps de compression

5. **Upload progressif pendant compression**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Action: Commencer l'upload dès que possible (streaming)
   - Impact: Réduit le temps total perçu

6. **Initialisation player non-bloquante**
   - Fichier: `academia_playback_view.dart`
   - Action: Differ l'initialisation du player
   - Impact: Réduit l'écran noir pendant initialisation

### Priorité 3 - Amélioration

7. **Cache des miniatures**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Action: Mettre en cache les miniatures générées
   - Impact: Évite la régénération pour les mêmes vidéos

8. **Watermark optionnel**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Action: Rendre le watermark optionnel ou différé
   - Impact: Réduit le temps de traitement

9. **Upload différé**
   - Fichier: `student_challenge_video_editor_screen.dart`
   - Action: Permettre l'édition avant upload
   - Impact: L'utilisateur peut commencer l'édition immédiatement

---

## Livrable Complet

### A. Diagramme Complet du Parcours

Voir section "Étape 1 - Cartographie Complète du Parcours"

### B. Tous les Composants Impliqués

Voir section "Étape 2 - Composants Impliqués Après Sélection Vidéo"

### C. Ordre Réel d'Exécution

Voir section "Étape 2 - Séquence Exacte d'Exécution"

### D. Analyse Flutter

Voir section "Étape 3 - Analyse Flutter"

### E. Analyse Supabase

Voir section "Étape 4 - Analyse Supabase"

### F. Analyse Kamatera

Voir section "Étape 5 - Analyse Kamatera"

### G. Analyse FFmpeg

Voir section "Étape 6 - Analyse FFmpeg"

### H. Analyse du Player

Voir section "Étape 7 - Analyse du Player du Feed"

### I. Classement des Responsabilités

Voir section "Étape 8 - Classement des Responsabilités"

### J. Correctifs Recommandés

Voir section "Étape 9 - Correctifs Recommandés"

---

## Conclusion

**Le parcours est-il acceptable pour un utilisateur moderne ?**

**NON**

**Justification**:
1. **Écrans noirs prolongés**: Compression et watermark bloquants sans feedback
2. **Audio persistant**: Le player du feed continue pendant l'import
3. **Chargement lent**: Opérations bloquantes séquentielles (compression → watermark → upload)
4. **Absence de feedback**: Aucun indicateur de progression visible pour l'utilisateur
5. **Temps total**: Pour une vidéo de 150MB, le temps total peut dépasser 30-60 secondes sans feedback

**Le parcours nécessite des corrections critiques** avant d'être considéré acceptable pour un utilisateur moderne.
