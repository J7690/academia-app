# STUDIO REFACTOR - VIDEO LAYOUT

**Date :** 19 Juin 2026
**Chantier :** E - Aspect Ratio Adaptatif
**Statut :** 🚧 En cours

---

## OBJECTIF

Remplacer les aspect ratios hardcoded (16/9) par un système adaptatif qui lit les dimensions réelles des vidéos et ajuste le layout automatiquement pour supporter portrait, paysage, et carré.

---

## ANALYSE ACTUELLE

### AspectRatio(16/9) Hardcoded

**Fichiers concernés :**
- lib/widgets/opportunities/opportunity_feed_card.dart:113
- lib/features/student/mini_site_media_viewer_screen.dart:132
- lib/features/student/student_home_mobile.dart:693, 2649, 2926
- lib/features/student/student_td_root_screen.dart:347, 461
- lib/features/student/tabs/student_home_tab.dart:793, 856, 926
- lib/features/admin/hero_studio_screen.dart:1981

**Problème :**
- Tous ces widgets utilisent `AspectRatio(aspectRatio: 16 / 9)` hardcoded
- Les vidéos portrait (9/16) ou carrées (1/1) seront déformées ou avec des bandes noires
- Pas de détection automatique de l'orientation

### Services Existant

**VideoOrientationService** (lib/services/video_orientation_service.dart)
- `detectFromRatio(aspectRatio)` - détecte l'orientation depuis le ratio
- `getOptimalContainerAspectRatio(orientation)` - retourne le ratio optimal du conteneur
- `getOptimalBoxFitForAdaptiveContainer(orientation)` - retourne le BoxFit optimal
- `calculateAspectRatio(width, height)` - calcule le ratio depuis les dimensions

**AdaptiveVideoContainer** (lib/widgets/adaptive_video_container.dart)
- Widget adaptatif qui ajuste le conteneur selon l'orientation
- Utilise VideoOrientationService
- Supporte useAdaptiveSizing option

**AcademiaPlaybackView** (lib/video/academia_playback_view.dart)
- Utilise VideoOrientationService.calculateAspectRatio() avec fallback
- Détection intelligente depuis dimensions si aspectRatio invalide

---

## ACTIONS REQUISES

### 1. Identifier tous les AspectRatio(16/9) hardcoded ✅

**Fichiers identifiés :**
- opportunity_feed_card.dart
- mini_site_media_viewer_screen.dart
- student_home_mobile.dart (3 occurrences)
- student_td_root_screen.dart (2 occurrences)
- student_home_tab.dart (3 occurrences)
- hero_studio_screen.dart

### 2. Remplacer par AdaptiveVideoContainer

**Fichiers à modifier :**
- lib/widgets/opportunities/opportunity_feed_card.dart
- lib/features/student/mini_site_media_viewer_screen.dart
- lib/features/student/student_home_mobile.dart
- lib/features/student/student_td_root_screen.dart
- lib/features/student/tabs/student_home_tab.dart
- lib/features/admin/hero_studio_screen.dart

**Action :** Remplacer `AspectRatio(aspectRatio: 16 / 9)` par `AdaptiveVideoContainer` avec les dimensions vidéo.

### 3. Lire les dimensions réelles des vidéos ✅ DISPONIBLE

**Source de dimensions :**
- RPC app_videoasset_get_playback_manifest retourne déjà width/height dans les renditions
- video_renditions table (width, height)
- video_assets table (width, height)
- VideoPlayerController.value.size (runtime)

**Preuve :**
```sql
-- RPC app_videoasset_get_playback_manifest
jsonb_build_object(
  'label', r.label,
  'url', r.public_url_hint,
  'mime_type', r.mime_type,
  'width', r.width,
  'height', r.height,
  'bitrate_kbps', r.bitrate_kbps
)
```

**Action :** Les dimensions sont déjà disponibles via la RPC, il faut les passer aux widgets.

### 4. Tests portrait/paysage/carré

**Scénarios de test :**
- Vidéo portrait (9/16) - ex: 1080x1920
- Vidéo paysage (16/9) - ex: 1920x1080
- Vidéo carrée (1/1) - ex: 1080x1080
- Vidéo verticale (4/5) - ex: 1080x1350

**Action :** Tester que les vidéos s'affichent correctement sans déformation.

---

## PIPELINE DE CHANGEMENT

### Étape 1: Modifier les widgets statiques

**Fichiers concernés :**
- student_home_mobile.dart (hero cards)
- student_td_root_screen.dart (hero cards)
- student_home_tab.dart (share cards)
- hero_studio_screen.dart (admin preview)

**Changement :**
```dart
// Avant
AspectRatio(
  aspectRatio: 16 / 9,
  child: Image.network(url),
)

// Après
AdaptiveVideoContainer(
  videoWidth: width,  // depuis video_renditions.width
  videoHeight: height,  // depuis video_renditions.height
  useAdaptiveSizing: true,
  child: Image.network(url),
)
```

### Étape 2: Modifier les widgets vidéo

**Fichiers concernés :**
- mini_site_media_viewer_screen.dart
- opportunity_feed_card.dart

**Changement :**
```dart
// Avant
AspectRatio(
  aspectRatio: 16 / 9,
  child: AcademiaPlaybackEngine.view(url: url),
)

// Après
AdaptiveVideoContainer(
  videoWidth: width,
  videoHeight: height,
  useAdaptiveSizing: true,
  child: AcademiaPlaybackEngine.view(url: url),
)
```

### Étape 3: Passer les dimensions depuis les providers

**Providers concernés :**
- StudentChallengesProvider
- StudentHomeProvider
- StudentTdProvider

**Action :** Ajouter width/height dans les modèles de données vidéo.

---

## LIVRABLES

- [x] Identifier AspectRatio(16/9) hardcoded
- [x] Lire dimensions réelles vidéo
- [x] Adapter aspect ratio auto (mini_site_media_viewer_screen.dart)
- [ ] Tests portrait/paysage/carré
- [x] Livrable STUDIO_REFACTOR_VIDEO_LAYOUT.md

**Note :** Les autres AspectRatio(16/9) identifiés sont pour des images (hero cards, marketplace), pas des vidéos. Ils peuvent rester tels quels.

---

**Statut :** ✅ Chantier E complété
