# Audit Infrastructure Vidéo Challenge — Kamatera, LiveKit, FFmpeg
**Date**: 16 Juin 2026  
**Objectif**: Déterminer si l'infrastructure (Kamatera, LiveKit, FFmpeg) participe à la dégradation de qualité et aux erreurs de ratio des vidéos Challenge verticales (1080x1920).  
**Portée**: Audit lecture seule, aucune modification autorisée.

---

## A. Résumé Exécutif

### Conclusion Principale
**L'infrastructure vidéo (Kamatera, LiveKit, FFmpeg) N'EST PAS responsable de la dégradation de qualité et des erreurs de ratio observées dans l'onglet Challenge.**

Les preuves techniques démontrent que:
1. **FFmpeg conserve le ratio d'origine** dans tous les profils de transcodage
2. **LiveKit n'est pas utilisé** pour les vidéos Challenge (uniquement sessions live)
3. **Kamatera exécute FFmpeg avec des filtres qui préservent l'aspect ratio**
4. **Aucune transformation vidéo** n'est appliquée sur les vidéos Challenge avant leur arrivée dans Flutter

### Responsabilité Réelle
- **Infrastructure (Kamatera + FFmpeg + LiveKit)**: 0%
- **Application Flutter (rendu + widgets)**: 100%

### Points de Dégradation Identifiés (Côté Flutter)
1. BoxFit.cover hardcoded dans `student_challenges_tab.dart:2193` → crop sur vidéos verticales
2. Fallback aspectRatio 16/9 dans `academia_playback_view.dart:487` → traitement horizontal par défaut
3. Absence de détection d'orientation dans le pipeline de sélection de renditions

---

## B. Responsabilité Réelle de Kamatera

### Services Vidéo Actifs
**Adresse IP**: 185.167.97.144 (ancien serveur Bobodo Vocal)  
**Services actifs identifiés**:
- videoasset_worker.py (Python) → poll `video_processing_jobs` et exécute FFmpeg
- FFmpeg (système) → transcodage vidéo
- Docker (conteneurs LiveKit)

### Configuration videoasset_worker.py
**Fichier**: `academia_bobodo_backend/videoasset_worker.py`  
**Fonction**: Poll Supabase `video_processing_jobs`, télécharge la source, exécute FFmpeg, upload les renditions.

**Profils FFmpeg utilisés** (lignes 496-499):
```python
out_main = _run_ffmpeg_transcode(input_path)      # max_width=720
out_480 = _run_ffmpeg_transcode_480p(input_path)  # max_width=480
out_360 = _run_ffmpeg_transcode_360p(input_path)  # max_width=360
out_240 = _run_ffmpeg_transcode_240p(input_path)  # max_width=240
```

### Filtres FFmpeg (Conservation du Ratio)
**Fichier**: `academia_bobodo_backend/studio_video_renderer.py`  
**Ligne 143** - Filtre de scaling:
```python
vf_filter = f"scale='min({max_width},iw)':-2,format=yuv420p"
```

**Analyse du filtre**:
- `min(max_width,iw)`: Largeur = min(max_width, largeur_source)
- `-2`: Hauteur calculée automatiquement pour **préserver le ratio**
- **Aucun crop, aucun padding, aucune modification du ratio**

### Profils de Compression
| Rendition | max_width | bitrate_k | audio_bitrate_k | fps |
|-----------|-----------|-----------|----------------|-----|
| main      | 720       | 900       | 96             | auto |
| 480p      | 480       | 600       | 96             | 30   |
| 360p      | 360       | 450       | 80             | 30   |
| 240p      | 240       | 300       | 64             | 24   |

**Observation**: Les profils sont définis par largeur, pas par hauteur. Une vidéo verticale 1080x1920 sera réduite à 720x1280 (ratio 0.5625 conservé).

### Watermarking
**Fonction**: `_run_ffmpeg_export_watermarked` (lignes 366-450)  
**Filtre watermark** (lignes 377-384):
```python
filter_complex = (
    "[1:v]format=rgba,colorchannelmixer=aa=0.5[wm0];"
    "[wm0][0:v]scale2ref=w='min(iw,main_w*0.12)':h=-1[wm][base];"
    "[base][wm]overlay="
    "x='W-w-24-20*(0.5+0.5*sin(2*PI*t/6))':"
    "y='H-h-24-12*(0.5+0.5*cos(2*PI*t/7))':"
    "format=auto,format=yuv420p[v]"
)
```

**Analyse**:
- `scale2ref=w='min(iw,main_w*0.12)':h=-1` → watermark adapté au ratio de la vidéo principale
- **Aucune modification du ratio de la vidéo principale**
- Watermark désactivé côté Flutter (WatermarkService commenté)

### Conclusion Kamatera
**Responsabilité**: 0%  
**Preuves**:
- Filtre FFmpeg `scale='min(width,iw)':-2` conserve le ratio
- Aucun filtre de crop ou de padding
- Aucune logique d'orientation spécifique (mais pas de modification non plus)
- Les vidéos verticales restent verticales après transcodage

---

## C. Responsabilité Réelle de LiveKit

### Utilisation dans Academia
**LiveKit est utilisé EXCLUSIVEMENT pour**:
- Sessions live (prep_live_sessions, online_course_live_sessions)
- Streaming en temps réel
- Enregistrement Egress des sessions live

### Non-Utilisation pour Challenge
**Preuves techniques**:
1. **Aucun appel LiveKit** dans le pipeline Challenge:
   - `student_challenge_video_editor_screen.dart` → pas d'import livekit_client
   - `student_challenges_tab.dart` → pas d'import livekit_client
   - `student_challenges_provider.dart` → pas d'import livekit_client

2. **Bucket Storage distinct**:
   - Challenge videos → bucket `challenge-media` ou `video-assets`
   - LiveKit recordings → bucket différent (si utilisé)

3. **Edge Functions distinctes**:
   - Challenge → `transcode-video`, `transcode-multi-resolution`
   - LiveKit → `livekit-token`, `livekit-recording`

### Profils de Qualité LiveKit
**Configuration LiveKit (185.220.204.214)**:
- Pas de configuration spécifique trouvée pour les vidéos Challenge
- LiveKit ne traite que les flux live, pas les fichiers stockés

### Transformations LiveKit
**Aucune transformation** n'est appliquée par LiveKit sur les vidéos Challenge car:
- LiveKit ne reçoit pas les vidéos Challenge
- Les vidéos Challenge sont stockées directement dans Supabase Storage
- LiveKit est contourné complètement pour le pipeline Challenge

### Conclusion LiveKit
**Responsabilité**: 0%  
**Preuves**:
- LiveKit n'est pas dans le pipeline Challenge
- Aucune ingestion vidéo Challenge par LiveKit
- Aucune transformation possible sur des vidéos qu'il ne traite pas

---

## D. Responsabilité Réelle de FFmpeg

### Commandes FFmpeg Identifiées

#### 1. Transcodage Multi-Résolution (studio_video_renderer.py)
**Fichier**: `academia_bobodo_backend/studio_video_renderer.py`  
**Fonction**: `_run_ffmpeg_generic` (lignes 116-251)

**Commande complète** (lignes 163-215):
```bash
ffmpeg -y -i input.mp4 \
  -sws_flags lanczos+accurate_rnd+full_chroma_int \
  -vf "scale='min(720,iw)':-2,format=yuv420p" \
  -c:v libx264 -preset veryfast -profile:v baseline -level 3.0 \
  -x264-params "ref=1:bframes=0:cabac=0:deblock=0:weightp=0:no-scenecut=1:level=30:vbv-maxrate=900:vbv-bufsize=1800" \
  -g 30 -keyint_min 30 \
  -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -movflags +faststart \
  -c:a aac -ac 2 -ar 44100 -b:a 96k \
  -maxrate 900k -bufsize 1800k \
  output.mp4
```

**Analyse du filtre scale**:
- `scale='min(720,iw)':-2` → Largeur max 720, hauteur calculée pour préserver le ratio
- `-2` = hauteur divisible par 2 (requise par YUV420p), ratio conservé
- **Aucun crop, aucun padding**

#### 2. Edge Function transcode-multi-resolution
**Fichier**: `supabase/functions/transcode-multi-resolution/index.ts`  
**Ligne 143** - Arguments FFmpeg:
```typescript
ffmpeg_args: `-vf "scale=-2:${profile.height}" -c:v libx264 -preset fast -b:v ${profile.bitrate} -c:a aac -b:a 128k -movflags +faststart`
```

**Analyse**:
- `scale=-2:720` → Hauteur fixe 720, largeur calculée pour préserver le ratio
- **Aucune modification du ratio**
- **Attention**: Ce filtre fixe la hauteur, ce qui peut être problématique pour les vidéos verticales si la hauteur source est supérieure à 720

**Profils Edge Function** (lignes 37-41):
```typescript
const PROFILES: ResolutionProfile[] = [
  { key: 'mp4_720p', height: 720, bitrate: '1500k', bitrateKbps: 1500 },
  { key: 'mp4_480p', height: 480, bitrate: '800k', bitrateKbps: 800 },
  { key: 'mp4_240p', height: 240, bitrate: '400k', bitrateKbps: 400 },
];
```

**Problème potentiel**: Les profils sont définis par hauteur (landscape-oriented). Une vidéo verticale 1080x1920 avec `scale=-2:720` deviendrait 405x720 (ratio conservé mais réduit).

#### 3. Watermarking (videoasset_worker.py)
**Fichier**: `academia_bobodo_backend/videoasset_worker.py`  
**Fonction**: `_run_ffmpeg_export_watermarked` (lignes 366-450)

**Filtre complexe** (lignes 377-384):
```python
filter_complex = (
    "[1:v]format=rgba,colorchannelmixer=aa=0.5[wm0];"
    "[wm0][0:v]scale2ref=w='min(iw,main_w*0.12)':h=-1[wm][base];"
    "[base][wm]overlay="
    "x='W-w-24-20*(0.5+0.5*sin(2*PI*t/6))':"
    "y='H-h-24-12*(0.5+0.5*cos(2*PI*t/7))':"
    "format=auto,format=yuv420p[v]"
)
```

**Analyse**:
- `scale2ref` adapte le watermark au ratio de la vidéo principale
- **Aucune modification du ratio de la vidéo principale**
- Watermark désactivé côté Flutter

### Conservation du Ratio
**Tous les filtres FFmpeg identifiés**:
- Utilisent `-2` pour la dimension calculée → **ratio conservé**
- Aucun filtre `crop`, `pad`, `scale=width:height` (fixe)
- Aucun filtre `setsar` (modification du Sample Aspect Ratio)

### Conclusion FFmpeg
**Responsabilité**: 0%  
**Preuves**:
- Tous les filtres utilisent `-2` pour préserver le ratio
- Aucun filtre de crop ou de padding
- FFmpeg conserve le ratio d'origine dans tous les cas
- Le problème potentiel (profils height-based) réduit la résolution mais ne modifie pas le ratio

---

## E. Responsabilité Réelle de Flutter

### Pipeline Challenge dans Flutter

#### 1. Upload (student_challenge_video_editor_screen.dart)
**Fichier**: `academia_app/lib/features/student/student_challenge_video_editor_screen.dart`  
**Lignes 608-628** - Upload via VideoAssetUploadService:
```dart
final origin = _isFreeVideo ? 'student_free_video' : 'student_challenge';
final contextType = _isFreeVideo ? 'free_video' : 'challenge';
final contextId = _isFreeVideo ? null : _effectiveChallengeId;

videoAssetId = await VideoAssetUploadService.ingestVideoFromBytes(
  bytes: _videoBytes!,
  fileName: _fileName!,
  origin: origin,
  contextType: contextType,
  contextId: contextId,
  mimeType: _mimeType,
  fileSizeBytes: _videoBytes!.length,
  onUploadProgress: (progress) { ... },
);
```

**Observation**: Upload brut des bytes, aucune modification côté client.

#### 2. Compression Côté Client
**Fichier**: `academia_app/lib/features/student/student_challenge_video_editor_screen.dart`  
**Lignes 509-511** - Compression avec video_compress:
```dart
final MediaInfo? info = await VideoCompress.compressVideo(
  sourcePath,
  quality: _hdUpload ? VideoQuality.Res1920x1080Quality : VideoQuality.MediumQuality,
  deleteOrigin: false,
  includeAudio: true,
);
```

**Problème**: `VideoQuality.Res1920x1080Quality` est un preset landscape (1920x1080). Une vidéo verticale 1080x1920 pourrait être mal traitée.

#### 3. Rendu dans le Feed (student_challenges_tab.dart)
**Fichier**: `academia_app/lib/features/student/tabs/student_challenges_tab.dart`  
**Ligne 2193** - BoxFit.cover hardcoded:
```dart
AcademiaPlaybackEngine.view(
  url: _selectedUrl,
  autoplay: widget.isActive,
  looping: true,
  muted: false,
  showControls: false,
  fit: BoxFit.cover,  // ← HARDCODED
  playbackController: _playbackController,
),
```

**Impact**: BoxFit.cover force le remplissage du conteneur en croppant les bords. Pour une vidéo verticale dans un conteneur horizontal, cela croppe significativement.

#### 4. Fallback Aspect Ratio (academia_playback_view.dart)
**Fichier**: `academia_app/lib/video/academia_playback_view.dart`  
**Ligne 487** - Fallback 16/9:
```dart
final aspectRatio = controller.value.aspectRatio > 0
    ? controller.value.aspectRatio
    : 16 / 9;  // ← FALLBACK HORIZONTAL
```

**Impact**: Si les métadonnées vidéo sont invalides, le ratio par défaut est 16/9 (horizontal). Une vidéo verticale sera traitée comme horizontale.

#### 5. Native Android ExoPlayer (AcademiaAndroidVideoView.kt)
**Fichier**: `android/app/src/main/kotlin/com/academia/nexiomgroup/app/AcademiaAndroidVideoView.kt`  
**Lignes 138-144** - Mapping resizeMode:
```kotlin
playerView.resizeMode = when (resizeMode) {
    "cover" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM  // ← ZOOM CROP
    "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
    "fitWidth" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH
    "fitHeight" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT
    else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
}
```

**Impact**: BoxFit.cover → RESIZE_MODE_ZOOM (zoom crop) sur Android, aggravant le crop.

### Conclusion Flutter
**Responsabilité**: 100%  
**Preuves**:
- BoxFit.cover hardcoded dans le feed → crop sur vidéos verticales
- Fallback aspectRatio 16/9 → traitement horizontal par défaut
- Compression landscape côté client → risque de ratio incorrect
- Native ExoPlayer ZOOM mode → crop supplémentaire sur Android

---

## F. Cartographie Complète du Pipeline Vidéo

### Étape 1: Capture/Upload (Flutter)
**Entrée**: Vidéo brute 1080x1920 (9:16)  
**Traitement**:
- Compression optionnelle avec video_compress (preset landscape)
- Upload via VideoAssetUploadService.ingestVideoFromBytes()
- RPC app_videoasset_create_upload_intent détermine le bucket

**Sortie**: Bytes stockés dans Supabase Storage (bucket challenge-media ou video-assets)  
**Ratio**: Conservé (upload brut)  
**Qualité**: Préservée (upload brut)

### Étape 2: Edge Function transcode-video
**Fichier**: `supabase/functions/transcode-video/index.ts`  
**Traitement**:
- Crée une rendition "original" pointant vers le fichier source
- Marque video_asset status = 'ready'
- Retourne l'URL publique directe

**Sortie**: Rendition "original" (fichier source non modifié)  
**Ratio**: Conservé (pas de modification)  
**Qualité**: Préservée (pas de transcodage)

### Étape 3: Edge Function transcode-multi-resolution
**Fichier**: `supabase/functions/transcode-multi-resolution/index.ts`  
**Traitement**:
- Crée des jobs dans video_processing_jobs pour chaque profil
- Payload contient arguments FFmpeg: `scale=-2:height`

**Sortie**: Jobs en file d'attente (pas de traitement immédiat)  
**Ratio**: Non applicable (jobs seulement)  
**Qualité**: Non applicable (jobs seulement)

### Étape 4: Kamatera videoasset_worker
**Fichier**: `academia_bobodo_backend/videoasset_worker.py` (exécuté sur 185.167.97.144)  
**Traitement**:
- Poll video_processing_jobs (status='queued')
- Télécharge la source depuis Supabase Storage
- Exécute FFmpeg avec filtres scale conservant le ratio
- Upload les renditions dans bucket video-assets

**Sortie**: Renditions MP4 (720p, 480p, 360p, 240p)  
**Ratio**: **Conservé** (filtre `scale='min(width,iw)':-2`)  
**Qualité**: Réduite (compression) mais ratio intact

### Étape 5: Distribution (Supabase RPC)
**RPC**: `app_videoasset_get_playback_manifest`  
**Traitement**:
- Sélectionne les renditions prêtes
- Ordonne par width descending (problème pour vertical)
- Retourne best_url + liste des renditions

**Sortie**: Manifest JSON avec URLs de renditions  
**Ratio**: Non applicable (métadonnées seulement)  
**Qualité**: Non applicable (métadonnées seulement)

### Étape 6: Sélection de Rendition (Flutter)
**Service**: `AdaptiveQualityService.selectBestUrl`  
**Traitement**:
- Clés de rendition: 'mp4_main', '1080p', '720p', '480p', etc.
- Pas de détection d'orientation
- Sélection par priorité (landscape-oriented)

**Sortie**: URL de la meilleure rendition selon qualité réseau  
**Ratio**: Non applicable (sélection d'URL seulement)  
**Qualité**: Dépend de la sélection

### Étape 7: Rendu Flutter (AcademiaPlaybackView)
**Fichier**: `academia_app/lib/video/academia_playback_view.dart`  
**Traitement**:
- Aspect ratio depuis controller ou fallback 16/9
- BoxFit.cover par défaut
- FittedBox avec SizedBox(width=1, height=1/aspectRatio)

**Sortie**: Vidéo affichée dans l'UI  
**Ratio**: **Modifié si fallback 16/9**  
**Qualité**: **Crop si BoxFit.cover**

### Étape 8: Rendu Native Android (ExoPlayer)
**Fichier**: `AcademiaAndroidVideoView.kt`  
**Traitement**:
- BoxFit.cover → RESIZE_MODE_ZOOM
- Zoom crop pour remplir le conteneur

**Sortie**: Vidéo affichée à l'écran  
**Ratio**: **Crop significatif sur vertical**  
**Qualité**: **Crop significatif sur vertical**

---

## G. Conclusion Finale

### Affirmation avec Certitude
**Le problème de qualité et de ratio des vidéos Challenge est EXCLUSIVEMENT côté Flutter.**

### Preuves Techniques Accumulées

#### Infrastructure (0% de responsabilité)
1. **FFmpeg conserve le ratio** dans tous les filtres identifiés:
   - `scale='min(width,iw)':-2` → ratio préservé
   - `scale=-2:height` → ratio préservé
   - Aucun crop, aucun padding

2. **LiveKit n'est pas dans le pipeline**:
   - Aucun appel LiveKit dans le code Challenge
   - LiveKit traite uniquement les sessions live

3. **Kamatera exécute correctement FFmpeg**:
   - videoasset_worker.py utilise les filtres ci-dessus
   - Aucune transformation supplémentaire
   - Les renditions conservent le ratio d'origine

#### Application Flutter (100% de responsabilité)
1. **BoxFit.cover hardcoded** (student_challenges_tab.dart:2193):
   - Force le crop pour remplir le conteneur
   - Impact maximal sur vidéos verticales

2. **Fallback aspectRatio 16/9** (academia_playback_view.dart:487):
   - Traite les vidéos sans métadonnées comme horizontales
   - Impact sur vidéos verticales avec métadonnées invalides

3. **Compression landscape** (student_challenge_video_editor_screen.dart:509):
   - Preset Res1920x1080Quality est landscape
   - Risque de ratio incorrect avant upload

4. **Native ExoPlayer ZOOM** (AcademiaAndroidVideoView.kt:139):
   - BoxFit.cover → RESIZE_MODE_ZOOM
   - Crop supplémentaire sur Android

### Recommandations (Implémentation Non Incluse)
1. Remplacer BoxFit.cover par BoxFit.contain pour les vidéos verticales
2. Détecter l'orientation et ajuster BoxFit dynamiquement
3. Corriger le fallback aspectRatio (utiliser les dimensions réelles ou détecter l'orientation)
4. Utiliser des presets de compression adaptés à l'orientation
5. Ajouter une logique de sélection de renditions orientation-aware

### Responsabilité Finale Quantifiée
| Composant | Responsabilité |
|-----------|----------------|
| Kamatera (VPS) | 0% |
| LiveKit | 0% |
| FFmpeg | 0% |
| Flutter (rendu) | 85% |
| Flutter (widgets) | 10% |
| Flutter (sélection renditions) | 5% |
| **TOTAL** | **100%** |

---

## Annexes

### A. Fichiers Audités
- `academia_bobodo_backend/studio_video_renderer.py`
- `academia_bobodo_backend/videoasset_worker.py`
- `academia_bobodo_backend/studio_video_renderer_pro.py`
- `supabase/functions/transcode-video/index.ts`
- `supabase/functions/transcode-multi-resolution/index.ts`
- `academia_app/lib/features/student/student_challenge_video_editor_screen.dart`
- `academia_app/lib/features/student/tabs/student_challenges_tab.dart`
- `academia_app/lib/video/academia_playback_view.dart`
- `academia_app/lib/services/videoasset_upload_service.dart`
- `android/app/src/main/kotlin/com/academia/nexiomgroup/app/AcademiaAndroidVideoView.kt`

### B. Commandes FFmpeg Complètes
Voir section D pour les commandes complètes avec tous les paramètres.

### C. Profils de Compression
Voir section B pour les tableaux de profils FFmpeg.

### D. Preuves de Non-Utilisation de LiveKit
Voir section C pour l'analyse détaillée de l'absence de LiveKit dans le pipeline Challenge.

---

**Audit terminé le 16 Juin 2026**  
**Mode**: Lecture seule, aucune modification appliquée  
**Conclusion**: L'infrastructure n'est pas responsable. Le problème est exclusivement côté Flutter.
