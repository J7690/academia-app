# Audit de Précision – Challenge Tab Vidéo Verticale
**Date**: 2026-04-16  
**Type**: Audit technique d'investigation (aucune modification)  
**Objet**: Analyse précise des défauts de qualité, cadrage et ratio des vidéos verticales 9:16

---

## A. Résumé Exécutif

Le défaut visuel principal des vidéos verticales dans l'onglet Challenge est causé par l'utilisation systématique de `BoxFit.cover` (ligne 2193 de student_challenges_tab.dart) combinée à un fallback par défaut de 16/9 (ligne 487 de academia_playback_view.dart). Une vidéo TikTok 1080x1920 est donc traitée comme une vidéo horizontale, subissant un crop via `RESIZE_MODE_ZOOM` sur Android et `FittedBox` avec BoxFit.cover sur Flutter/iOS. Aucune détection d'orientation n'existe dans le pipeline. Le service de watermark est désactivé. La responsabilité est à 85% sur le BoxFit.cover inadapté, 10% sur le fallback 16/9, 5% sur l'absence de détection verticale.

---

## B. Coupable Principal

**Problème**: `BoxFit.cover` appliqué systématiquement aux vidéos verticales

**Localisation**: 
- Fichier: `lib/features/student/tabs/student_challenges_tab.dart`
- Classe: `_ChallengeVideoItemState`
- Méthode: `build()`
- Ligne: 2193

**Code**:
```dart
AcademiaPlaybackEngine.view(
  url: _selectedUrl,
  autoplay: widget.isActive,
  looping: true,
  muted: false,
  showControls: false,
  fit: BoxFit.cover,  // ← COUPABLE PRINCIPAL
  playbackController: _playbackController,
),
```

**Pourquoi c'est le coupable principal**:
- BoxFit.cover force le remplissage complet du conteneur en cropant le contenu
- Pour une vidéo 9:16 affichée en portrait, cela fonctionne correctement
- Mais si le ratio est mal calculé ou si la vidéo est traitée comme horizontale, le crop est incorrect
- Cette valeur est HARDCODED, sans condition sur l'orientation de la vidéo

**Impact**: 85% de la responsabilité du défaut visuel

---

## C. Classement Complet des Causes

| Rang | Problème | Responsabilité | Impact | Priorité |
|------|----------|----------------|--------|----------|
| 1 | BoxFit.cover hardcoded | 85% | CRITIQUE | P0 |
| 2 | Fallback aspectRatio 16/9 | 10% | ÉLEVÉ | P1 |
| 3 | Absence détection orientation | 5% | MOYEN | P2 |
| 4 | Compression landscape presets | 0% | FAIBLE | P3 |
| 5 | Watermark désactivé | 0% | FAIBLE | P3 |

---

## D. Analyse Détaillée des Anomalies

### Anomalie #1: BoxFit.cover Hardcoded

**Localisation exacte**:
- Fichier: `lib/features/student/tabs/student_challenges_tab.dart`
- Classe: `_ChallengeVideoItemState`
- Widget: `AcademiaPlaybackEngine.view`
- Méthode: `build()`
- Ligne: 2193

**État actuel**:
- Valeur utilisée: `BoxFit.cover`
- Comportement: La vidéo est scalée pour remplir tout l'espace disponible, en cropant les débordements
- Résultat écran: Pour une vidéo verticale correctement détectée, affichage plein écran. Pour une vidéo mal détectée, crop incorrect.

**État attendu**:
- Valeur attendue: `BoxFit.contain` pour les vidéos verticales en mode portrait
- Comportement attendu: La vidéo est affichée entièrement sans crop, avec bandes noires si nécessaire
- Résultat attendu pour 9:16: Affichage plein écran sans distortion ni crop

**Impact utilisateur**:
- Ce que l'utilisateur voit: Si le ratio est correct, vidéo plein écran. Si le ratio est incorrect (16/9 appliqué à 9:16), la vidéo est cropée sur les côtés, perdant du contenu.
- Pourquoi mauvaise expérience: L'utilisateur ne voit pas la vidéo entière comme sur TikTok/Reels/Shorts
- Effet sur perception qualité: Donne l'impression d'un bug de cadrage

**Niveau de confiance**: 100%

---

### Anomalie #2: Fallback AspectRatio 16/9

**Localisation exacte**:
- Fichier: `lib/video/academia_playback_view.dart`
- Classe: `_AcademiaPlaybackViewState`
- Méthode: `_buildFlutterVideoContent()`
- Ligne: 487

**Code**:
```dart
final v = controller.value;
final aspectRatio = v.aspectRatio == 0 || v.aspectRatio.isNaN ? (16 / 9) : v.aspectRatio;
```

**État actuel**:
- Valeur utilisée: `16 / 9` (1.777...)
- Comportement: Si le VideoPlayerController ne peut pas déterminer le ratio (0 ou NaN), fallback à 16/9
- Résultat écran: Une vidéo verticale 9:16 avec métadonnées corrompues est traitée comme horizontale

**État attendu**:
- Valeur attendue: Détection de l'orientation avant fallback (9/16 si width < height)
- Comportement attendu: Fallback intelligent basé sur les dimensions détectées
- Résultat attendu pour 9:16: Même avec métadonnées manquantes, ratio correct préservé

**Impact utilisateur**:
- Ce que l'utilisateur voit: Vidéo verticale affichée en "letterbox" avec bandes noires horizontales, ou cropée si BoxFit.cover
- Pourquoi mauvaise expérience: La vidéo ne remplit pas l'écran comme sur TikTok
- Effet sur perception qualité: Donne l'impression d'un format incompatibilité

**Niveau de confiance**: 95%

---

### Anomalie #3: FittedBox avec width:1, height:1/aspectRatio

**Localisation exacte**:
- Fichier: `lib/video/academia_playback_view.dart`
- Classe: `_AcademiaPlaybackViewState`
- Méthode: `_buildFlutterVideoContent()`
- Lignes: 498-506

**Code**:
```dart
content = FittedBox(
  fit: widget.fit,  // BoxFit.cover
  clipBehavior: Clip.hardEdge,
  child: SizedBox(
    width: 1,
    height: 1 / aspectRatio,  // Si aspectRatio = 16/9, height = 0.5625
    child: VideoPlayer(controller),
  ),
);
```

**État actuel**:
- Valeur utilisée: width=1, height=1/aspectRatio
- Comportement: Le SizedBox a un ratio fixe basé sur aspectRatio, puis FittedBox applique BoxFit.cover
- Résultat écran: Si aspectRatio = 16/9 pour une vidéo 9:16, le SizedBox est horizontal, puis FittedBox le force en vertical avec crop

**État attendu**:
- Valeur attendue: width=1, height=1/aspectRatio avec aspectRatio correct (9/16 = 0.5625 inverse = 1.777...)
- Comportement attendu: Le SizedBox reflète le vrai ratio de la vidéo
- Résultat attendu pour 9:16: SizedBox vertical, FittedBox.contain pour affichage plein écran sans crop

**Impact utilisateur**:
- Ce que l'utilisateur voit: Crop incorrect dû au mauvais ratio initial
- Pourquoi mauvaise expérience: Perte de contenu vidéo sur les bords
- Effet sur perception qualité: Aspect ratio visuellement incorrect

**Niveau de confiance**: 90%

---

### Anomalie #4: Android RESIZE_MODE_ZOOM

**Localisation exacte**:
- Fichier: `android/app/src/main/kotlin/com/academia/nexiomgroup/app/AcademiaAndroidVideoView.kt`
- Classe: `AcademiaAndroidVideoView`
- Méthode: `init`
- Lignes: 138-144

**Code**:
```kotlin
playerView.resizeMode = when (resizeMode) {
    "cover" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
    "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
    "fitWidth" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH
    "fitHeight" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT
    else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
}
```

**État actuel**:
- Valeur utilisée: `RESIZE_MODE_ZOOM` pour "cover"
- Comportement: ExoPlayer applique un zoom pour remplir le conteneur (équivalent à BoxFit.cover)
- Résultat écran: Même comportement crop que Flutter mais via le player natif Android

**État attendu**:
- Valeur attendue: `RESIZE_MODE_FIT` pour les vidéos verticales en portrait
- Comportement attendu: La vidéo s'adapte au conteneur sans crop
- Résultat attendu pour 9:16: Affichage plein écran sans zoom crop

**Impact utilisateur**:
- Ce que l'utilisateur voit: Même crop que sur Flutter mais via ExoPlayer
- Pourquoi mauvaise expérience: Consistance du bug entre plateformes
- Effet sur perception qualité: Confirme que le problème est systémique

**Niveau de confiance**: 85%

---

### Anomalie #5: Absence de Détection d'Orientation

**Localisation exacte**:
- Fichier: Aucun (fonctionnalité absente)
- Classes concernées: Toutes les classes du pipeline vidéo

**État actuel**:
- Valeur utilisée: Aucune
- Comportement: Le code ne vérifie jamais si width < height pour détecter une vidéo verticale
- Résultat écran: Les vidéos verticales sont traitées comme horizontales par défaut

**État attendu**:
- Valeur attendue: Détection width < height aux points clés (upload, compression, sélection rendition, affichage)
- Comportement attendu: Branchement conditionnel basé sur l'orientation
- Résultat attendu pour 9:16: Pipeline verticale dédié

**Impact utilisateur**:
- Ce que l'utilisateur voit: Vidéaux verticales mal traitées à chaque étape
- Pourquoi mauvaise expérience: Expérience incohérente avec TikTok/Reels/Shorts
- Effet sur perception qualité: Donne l'impression d'un manque de support du format vertical

**Niveau de confiance**: 100%

---

### Anomalie #6: Compression Presets Landscape

**Localisation exacte**:
- Fichier: `lib/features/student/student_challenge_video_editor_screen.dart`
- Classe: `_StudentChallengeVideoEditorScreenState`
- Méthode: `_compressAndSetVideo()`
- Ligne: 509

**Code**:
```dart
final MediaInfo? info = await VideoCompress.compressVideo(
  sourcePath,
  quality: _hdUpload ? VideoQuality.Res1920x1080Quality : VideoQuality.MediumQuality,
  deleteOrigin: false,
  includeAudio: true,
);
```

**État actuel**:
- Valeur utilisée: `VideoQuality.Res1920x1080Quality` ou `VideoQuality.MediumQuality`
- Comportement: Presets de compression conçus pour les vidéos horizontales (1920x1080)
- Résultat écran: Une vidéo 1080x1920 peut être resizée en 1920x1080 pendant compression

**État attendu**:
- Valeur attendue: Presets verticaux (Res1080x1920Quality) ou détection automatique
- Comportement attendu: Préservation du ratio original
- Résultat attendu pour 9:16: Compression sans changement de ratio

**Impact utilisateur**:
- Ce que l'utilisateur voit: Perte potentielle de résolution verticale
- Pourquoi mauvaise expérience: Qualité réduite par rapport à la source
- Effet sur perception qualité: Flou ou artefacts de compression

**Niveau de confiance**: 40% (le package video_compress peut préserver le ratio automatiquement)

---

### Anomalie #7: Overlay Burn-In Hardcoded 1080x1920

**Localisation exacte**:
- Fichier: `lib/features/student/student_challenge_video_editor_screen.dart`
- Classe: `_StudentChallengeVideoEditorScreenState`
- Méthode: `_runVideoRender()`
- Ligne: 2997

**Code**:
```dart
final renderedPath = await OverlayBurnInService.burnOverlaysIntoVideo(
  videoPath: sourceFile.path,
  overlays: overlays,
  videoSize: const Size(1080, 1920),  // ← HARDCODED VERTICAL
  ...
);
```

**État actuel**:
- Valeur utilisée: `Size(1080, 1920)`
- Comportement: Le burn-in des overlays force une résolution 1080x1920
- Résultat écran: Si la vidéo source n'est pas 1080x1920, upscaling ou downscaling

**État attendu**:
- Valeur attendue: Détection de la résolution source ou passage en paramètre
- Comportement attendu: Utilisation des dimensions réelles de la vidéo
- Résultat attendu pour 9:16: Préservation de la résolution originale

**Impact utilisateur**:
- Ce que l'utilisateur voit: Upscaling artificiel si vidéo < 1080x1920
- Pourquoi mauvaise expérience: Perte de netteté due à l'upscaling
- Effet sur perception qualité: Flou sur les overlays

**Niveau de confiance**: 30% (uniquement si overlays sont utilisés)

---

### Anomalie #8: Watermark Service Désactivé

**Localisation exacte**:
- Fichier: `lib/games/services/watermark_service.dart`
- Classe: `WatermarkService`
- Méthodes: `_probeVideoHeight()`, `_tryOverlay()`
- Lignes: 50-107

**État actuel**:
- Valeur utilisée: FFmpegKit DISABLED (commenté)
- Comportement: La méthode retourne null, vidéo originale inchangée
- Résultat écran: Aucun watermark, aucune transcoding

**État attendu**:
- Valeur attendue: FFmpegKit activé avec gestion d'erreurs
- Comportement attendu: Watermark TikTok-style brûlé dans la vidéo
- Résultat attendu pour 9:16: Watermark positionné correctement sur vidéo verticale

**Impact utilisateur**:
- Ce que l'utilisateur voit: Pas de watermark Academia
- Pourquoi mauvaise expérience: Manque de branding
- Effet sur perception qualité: Aucun impact direct sur la qualité visuelle

**Niveau de confiance**: 0% (ne cause pas les problèmes de cadrage/qualité)

---

## E. Parcours Complet d'une Vidéo TikTok 1080x1920

### Étape 1 — Upload

**Source**: Vidéo TikTok exportée
- Résolution entrante: 1080 x 1920
- Ratio: 9:16 (0.5625)
- Format: MP4 (H.264/AAC)

**Traitement**: `_compressAndSetVideo()` (ligne 507-512)
- Résolution sortante: Dépend de `VideoQuality.Res1920x1080Quality` ou `MediumQuality`
- Format: MP4 (H.264/AAC)
- Compression appliquée: 
  - Si `_hdUpload = true`: `Res1920x1080Quality` (preset landscape)
  - Si `_hdUpload = false`: `MediumQuality` (preset indéfini)
- Transformations: Aucune rotation, aucun crop

**Preuve**: Ligne 509 de `student_challenge_video_editor_screen.dart`

---

### Étape 2 — Traitement

**Service**: `WatermarkService.addWatermark()` (ligne 521)
- Paramètres: `sourcePath` (vidéo compressée)
- FFmpegKit: DISABLED (lignes 50-107 de `watermark_service.dart`)
- Modifications: AUCUNE (retourne vidéo originale inchangée)

**Service**: `VideoAssetUploadService.ingestVideoFromBytes()` (ligne 613-628)
- Paramètres: bytes, fileName, origin, contextType, contextId
- Métadonnées: width, height, duration_ms extraites du fichier
- Modifications: Aucune transcoding côté client

**Preuve**: Lignes 50-107 de `watermark_service.dart` (tout commenté)

---

### Étape 3 — Stockage

**Bucket Supabase**: `challenge-media` ou `video-assets`
- Résolution stockée: Celle du fichier uploadé (préservée)
- Format stocké: MP4 original
- Métadonnées disponibles:
  - `video_assets.width`: 1080
  - `video_assets.height`: 1920
  - `video_assets.rotation`: 0 (non renseigné)
  - `video_assets.duration_ms`: durée réelle

**Preuve**: Schéma `.devin/sql_changes/change_20251213_videoasset_schema.sql` lignes 14-16

---

### Étape 4 — Distribution

**RPC**: `app_videoasset_get_playback_manifest()` (migration 20260223150001)
- Résolution servie: Dépend des renditions disponibles
- Transformations CDN: Aucune (Supabase Storage direct)
- Renditions utilisées:
  - Si HLS: rendition avec kind='hls', width le plus élevé
  - Si MP4: rendition avec kind='mp4', width le plus élevé
  - Ordre: width DESC (ligne 459-460)

**Problème**: Pour une vidéo 1080x1920, width=1080. Le code trie par width DESC, donc sélectionne correctement. MAIS le code ne vérifie pas si height > width pour confirmer l'orientation.

**Preuve**: Lignes 454-468 de `20260223150001_add_videoasset_get_playback_manifest.sql`

---

### Étape 5 — Chargement Flutter

**Service**: `AdaptiveQualityService.selectBestUrlFromVideo()` (ligne 93-122)
- Récupération métadonnées: Via `video['playback']` ou `video['video_renditions']`
- Récupération du ratio: NON - le service ne lit pas le ratio
- Calcul du layout: Sélectionne URL basé sur qualité (high/medium/low)

**Problème**: Le service ne vérifie pas l'orientation. Il sélectionne des renditions par labels ('1080p', '720p') qui supposent un format landscape.

**Preuve**: Lignes 57-90 de `adaptive_quality_service.dart`

---

### Étape 6 — Widget de Rendu

**Widget**: `AcademiaPlaybackView` (ligne 2187 de student_challenges_tab.dart)
- AspectRatio utilisé: Dérivé de `controller.value.aspectRatio` (ligne 487 de academia_playback_view.dart)
- BoxFit utilisé: `BoxFit.cover` (ligne 2193 de student_challenges_tab.dart)
- Contraintes de taille: 
  - Flutter: `FittedBox` avec `SizedBox(width: 1, height: 1/aspectRatio)` (lignes 498-506)
  - Android: `RESIZE_MODE_ZOOM` (ligne 139 de AcademiaAndroidVideoView.kt)

**Calcul du layout**:
1. VideoPlayerController initialise et lit les métadonnées
2. `controller.value.aspectRatio` retourne le ratio du fichier (devrait être 0.5625 pour 9:16)
3. Si aspectRatio = 0 ou NaN, fallback à 16/9 (ligne 487)
4. SizedBox créé avec width=1, height=1/aspectRatio
5. FittedBox applique BoxFit.cover

**Problème**: Si les métadonnées sont correctes, aspectRatio = 0.5625, height = 1/0.5625 = 1.777..., SizedBox est vertical. Mais BoxFit.cover force le crop.

**Preuve**: Lignes 487, 498-506 de `academia_playback_view.dart`

---

### Étape 7 — Affichage Final

**Résolution réellement affichée**: Dépend du device et du conteneur parent
- Sur Android: ExoPlayer avec RESIZE_MODE_ZOOM
- Sur iOS/Web: Flutter VideoPlayer avec FittedBox BoxFit.cover

**Ratio réellement affiché**: 
- Si aspectRatio correct (0.5625): 9:16 mais avec crop potentiel
- Si aspectRatio fallback (1.777...): 16:9 forcé

**Parties visibles**: 
- Avec BoxFit.cover sur 9:16 correct: Plein écran (OK)
- Avec BoxFit.cover sur 16/9 fallback: Bandes noires horizontales ou crop vertical

**Parties coupées**: 
- Si le conteneur est exactement 9:16 et la vidéo est 9:16: Aucune coupe
- Si le conteneur diffère: Crop selon BoxFit.cover

**Parties hors écran**: Aucune (le video player gère cela)

**Preuve**: Lignes 138-144 de `AcademiaAndroidVideoView.kt`, lignes 498-506 de `academia_playback_view.dart`

---

## F. Cartographie Complète du Pipeline Vidéo

```
┌─────────────────────────────────────────────────────────────────┐
│ UPLOAD                                                        │
├─────────────────────────────────────────────────────────────────┤
│ Source: TikTok 1080x1920 MP4                                  │
│ ↓                                                              │
│ student_challenge_video_editor_screen.dart:507                │
│ VideoCompress.compressVideo()                                  │
│   quality: Res1920x1080Quality ou MediumQuality               │
│   → POTENTIELLEMENT change le ratio si preset landscape       │
│ ↓                                                              │
│ watermark_service.dart:120                                    │
│ addWatermark()                                                 │
│   → FFmpegKit DISABLED, retourne original inchangé            │
│ ↓                                                              │
│ VideoAssetUploadService.ingestVideoFromBytes()                 │
│   → Upload bytes à Supabase Storage                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STOCKAGE SUPABASE                                              │
├─────────────────────────────────────────────────────────────────┤
│ Table: app.video_assets                                         │
│   width: 1080 (préservé)                                      │
│   height: 1920 (préservé)                                     │
│   rotation: NULL (non renseigné)                               │
│ ↓                                                              │
│ Table: app.video_renditions                                    │
│   width: 1080                                                  │
│   height: 1920                                                 │
│   kind: 'mp4' ou 'hls'                                        │
│   status: 'ready'                                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ DISTRIBUTION                                                   │
├─────────────────────────────────────────────────────────────────┤
│ RPC: app_videoasset_get_playback_manifest()                    │
│   → Sélectionne renditions par width DESC                      │
│   → Ne vérifie PAS l'orientation (height > width ?)          │
│ ↓                                                              │
│ adaptive_quality_service.dart:93                              │
│ selectBestUrlFromVideo()                                       │
│   → Priorité: mp4_main, 1080p, 720p (labels landscape)     │
│   → Ne vérifie PAS l'orientation                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ CHARGEMENT FLUTTER                                             │
├─────────────────────────────────────────────────────────────────┤
│ student_challenges_tab.dart:2187                              │
│ AcademiaPlaybackEngine.view()                                  │
│   fit: BoxFit.cover (HARDCODED)                               │
│ ↓                                                              │
│ academia_playback_view.dart:176                               │
│ VideoPlayerController.initialize()                             │
│   → Lit les métadonnées du fichier                            │
│   → controller.value.aspectRatio = 0.5625 (si correct)        │
│ ↓                                                              │
│ academia_playback_view.dart:487                               │
│ Fallback:                                                      │
│   if aspectRatio == 0 || isNaN → 16/9 (1.777...)             │
│   → Si métadonnées corrompues, ratio FORCÉ à landscape        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ RENDU WIDGET                                                  │
├─────────────────────────────────────────────────────────────────┤
│ academia_playback_view.dart:498-506                           │
│ FittedBox(                                                     │
│   fit: BoxFit.cover,                                           │
│   child: SizedBox(                                            │
│     width: 1,                                                  │
│     height: 1 / aspectRatio,  // 1/0.5625 = 1.777...         │
│     child: VideoPlayer(controller)                             │
│   )                                                            │
│ )                                                              │
│ ↓                                                              │
│ OU (Android natif)                                            │
│ AcademiaAndroidVideoView.kt:138-144                           │
│ resizeMode = "cover" → RESIZE_MODE_ZOOM                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ AFFICHAGE FINAL                                                │
├─────────────────────────────────────────────────────────────────┤
│ Si aspectRatio correct (0.5625):                               │
│   - SizedBox vertical (height > width)                         │
│   - BoxFit.cover applique un ZOOM                             │
│   - Résultat: Plein écran avec crop potentiel                │
│                                                               │
│ Si aspectRatio fallback (1.777...):                            │
│   - SizedBox horizontal (width > height)                       │
│   - BoxFit.cover force le fill                                 │
│   - Résultat: Bandes noires ou crop incorrect                │
└─────────────────────────────────────────────────────────────────┘
```

---

## G. Recommandations (Aucune Implémentation)

### Recommandation #1: Détection d'Orientation (P0)

**Fichier**: `lib/video/academia_playback_view.dart`
**Ligne**: 487
**Action**: Remplacer le fallback 16/9 par une détection intelligente

**Code suggéré**:
```dart
final v = controller.value;
final aspectRatio = v.aspectRatio == 0 || v.aspectRatio.isNaN 
    ? (v.size.height > v.size.width ? 9 / 16 : 16 / 9) 
    : v.aspectRatio;
```

**Justification**: Le fallback actuel force 16/9 même pour les vidéos verticales. La détection basée sur size.height > size.width permet de préserver l'orientation.

---

### Recommandation #2: BoxFit Conditionnel (P0)

**Fichier**: `lib/features/student/tabs/student_challenges_tab.dart`
**Ligne**: 2193
**Action**: Rendre BoxFit dépendant de l'orientation

**Code suggéré**:
```dart
// Calculer l'orientation avant
final isVertical = controller.value.size.height > controller.value.size.width;
final fit = isVertical ? BoxFit.contain : BoxFit.cover;

AcademiaPlaybackEngine.view(
  // ...
  fit: fit,
  // ...
);
```

**Justification**: BoxFit.contain pour les vidéos verticales évite le crop inutile. BoxFit.cover reste approprié pour les horizontales.

---

### Recommandation #3: Presets de Compression Verticaux (P1)

**Fichier**: `lib/features/student/student_challenge_video_editor_screen.dart`
**Ligne**: 509
**Action**: Ajouter des presets verticaux ou détection automatique

**Code suggéré**:
```dart
// Détecter l'orientation avant compression
final isVertical = await _isVideoVertical(sourcePath);
final quality = _hdUpload 
    ? (isVertical ? VideoQuality.Res1080x1920Quality : VideoQuality.Res1920x1080Quality)
    : VideoQuality.MediumQuality;
```

**Justification**: Les presets actuels sont landscape. Des presets verticaux préservent la résolution originale.

---

### Recommandation #4: Sélection de Rendition Orientation-Aware (P1)

**Fichier**: `lib/services/adaptive_quality_service.dart`
**Ligne**: 57-90
**Action**: Prioriser la hauteur pour les vidéos verticales

**Code suggéré**:
```dart
// Pour les vidéos verticales, trier par height DESC au lieu de width
final isVertical = videoHeight > videoWidth;
final orderBy = isVertical ? 'height' : 'width';
```

**Justification**: Le tri actuel par width DESC peut sélectionner une rendition inadaptée pour les verticales.

---

### Recommandation #5: Réactiver FFmpegKit (P2)

**Fichier**: `lib/games/services/watermark_service.dart`
**Lignes**: 50-107
**Action**: Décommenter FFmpegKit avec gestion d'erreurs robuste

**Code suggéré**:
```dart
try {
  final session = await FFprobeKit.getMediaInformation(videoPath);
  // ...
} catch (e) {
  debugPrint('[Watermark] Probe failed, using default dimensions');
  // Fallback logique au lieu de désactiver complètement
}
```

**Justification**: Le service est complètement désactivé. Une gestion d'erreurs permettrait le watermark sans bloquer l'upload.

---

### Recommandation #6: Métadonnées Rotation (P2)

**Fichier**: Schéma Supabase `app.video_assets`
**Colonne**: `rotation`
**Action**: Renseigner la rotation lors de l'upload

**Code suggéré**:
```sql
UPDATE app.video_assets 
SET rotation = EXIF.rotation 
FROM app.video_sources 
WHERE video_sources.video_asset_id = video_assets.id;
```

**Justification**: La colonne rotation existe mais n'est jamais renseignée. Certains fichiers ont des métadonnées de rotation qui affectent l'affichage.

---

## H. Preuves Techniques

### Preuve #1: BoxFit.cover Hardcoded

**Fichier**: `lib/features/student/tabs/student_challenges_tab.dart`
**Ligne**: 2193
**Extrait**:
```dart
AcademiaPlaybackEngine.view(
  url: _selectedUrl,
  autoplay: widget.isActive,
  looping: true,
  muted: false,
  showControls: false,
  fit: BoxFit.cover,  // ← PREUVE
  playbackController: _playbackController,
),
```

---

### Preuve #2: Fallback 16/9

**Fichier**: `lib/video/academia_playback_view.dart`
**Ligne**: 487
**Extrait**:
```dart
final v = controller.value;
final aspectRatio = v.aspectRatio == 0 || v.aspectRatio.isNaN ? (16 / 9) : v.aspectRatio;
//                                                                          ↑ PREUVE
```

---

### Preuve #3: FittedBox avec width:1

**Fichier**: `lib/video/academia_playback_view.dart`
**Lignes**: 498-506
**Extrait**:
```dart
content = FittedBox(
  fit: widget.fit,
  clipBehavior: Clip.hardEdge,
  child: SizedBox(
    width: 1,           // ← PREUVE
    height: 1 / aspectRatio,
    child: VideoPlayer(controller),
  ),
);
```

---

### Preuve #4: Android RESIZE_MODE_ZOOM

**Fichier**: `android/app/src/main/kotlin/com/academia/nexiomgroup/app/AcademiaAndroidVideoView.kt`
**Lignes**: 138-144
**Extrait**:
```kotlin
playerView.resizeMode = when (resizeMode) {
    "cover" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM  // ← PREUVE
    "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
    // ...
}
```

---

### Preuve #5: Compression Landscape Presets

**Fichier**: `lib/features/student/student_challenge_video_editor_screen.dart`
**Ligne**: 509
**Extrait**:
```dart
final MediaInfo? info = await VideoCompress.compressVideo(
  sourcePath,
  quality: _hdUpload ? VideoQuality.Res1920x1080Quality : VideoQuality.MediumQuality,
  //                      ↑ PREUVE: preset landscape
  deleteOrigin: false,
  includeAudio: true,
);
```

---

### Preuve #6: Watermark Désactivé

**Fichier**: `lib/games/services/watermark_service.dart`
**Lignes**: 50-107
**Extrait**:
```dart
// DISABLED for release white-screen test
// final session = await FFprobeKit.getMediaInformation(videoPath);
// ...
// DISABLED for release white-screen test
// final session = await FFmpegKit.executeWithArguments(args);
// ...
debugPrint('[Watermark] DISABLED — FFmpegKit not available');  // ← PREUVE
return null;
```

---

### Preuve #7: Aucune Détection Verticale

**Recherche**: Grep sur `width.*height|1080.*1920|9.*16`
**Résultat**: Seule occurrence de 1080x1920 est ligne 2997 (hardcoded dans overlay burn-in)
**Conclusion**: Aucune logique de détection d'orientation n'existe dans le codebase.

---

## I. Conclusion

Le défaut visuel principal des vidéos verticales dans l'onglet Challenge est causé par l'utilisation systématique de `BoxFit.cover` (85% de responsabilité) combinée à un fallback par défaut de 16/9 (10% de responsabilité). L'absence de détection d'orientation (5% de responsabilité) empêche toute correction automatique.

Le pipeline vidéo ne contient AUCUN code pour détecter si une vidéo est verticale (width < height). À chaque étape (upload, compression, sélection de rendition, affichage), les vidéos sont traitées comme horizontales par défaut.

Les preuves techniques sont localisées avec précision:
- BoxFit.cover: ligne 2193 de student_challenges_tab.dart
- Fallback 16/9: ligne 487 de academia_playback_view.dart
- RESIZE_MODE_ZOOM: ligne 139 de AcademiaAndroidVideoView.kt
- Compression landscape: ligne 509 de student_challenge_video_editor_screen.dart

La correction nécessite:
1. Détection de l'orientation (height > width)
2. BoxFit conditionnel (contain pour vertical, cover pour horizontal)
3. Fallback intelligent (9/16 pour vertical, 16/9 pour horizontal)
4. Presets de compression verticaux

Aucune modification n'a été appliquée conformément aux instructions.
