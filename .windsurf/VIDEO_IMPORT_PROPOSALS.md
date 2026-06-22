# Propositions de Solutions - Pipeline Import Vidéo Challenge

**Date :** 19 Juin 2026  
**Basé sur :** Audit + Recherches externes (Flutter, TikTok, Instagram, meilleures pratiques)

---

## Résumé des recherches

### 1. Paquets Flutter vidéo compression (2024-2026)

| Paquet | Avantages | Inconvénients | Recommandation |
|--------|-----------|--------------|----------------|
| **v_video_compressor** (v2.0.0) | Global progress stream, 5 quality levels, Media3/AVFoundation, hardware acceleration, zero FFmpeg | Relativement récent, moins de communauté | ⭐⭐⭐⭐⭐ Recommandé |
| **video_compress_kit** (v0.0.3) | Zero binary bloat, MediaCodec/VideoToolbox, faststart, progress stream, cancellation support | Très récent, peu de documentation | ⭐⭐⭐⭐⭐ Recommandé |
| **video_compress_native** (v1.1.27) | Cross-platform, progress monitoring, Media3/AVFoundation | Moins moderne, API plus complexe | ⭐⭐⭐ |
| **native_video_compress** | H264/H265, realtime progress, avoidLargerOutput | Moins maintenu | ⭐⭐⭐ |
| **flutter_video_compressor** | React Native Compressor wrapper, batch processing | Plus lourd, dépendances externes | ⭐⭐ |

### 2. Architecture TikTok

**Techniques clés identifiées :**
- **Device-side compression before upload** : Compression sur l'appareil avant envoi pour réduire bande passante
- **Chunked, resumable uploads** : Upload par segments pour résilience réseau
- **Edge servers and CDNs** : Upload accéléré via serveurs edge
- **GPU-accelerated transcoding** : Transcodage GPU pour disponibilité quasi-instantanée
- **Cloud storage with intelligent caching** : Cache edge pour contenu populaire

**Leçon clé :** TikTok compresse sur device AVANT upload, mais affiche immédiatement pour édition.

### 3. Instagram Edits App

**Caractéristiques :**
- Capture jusqu'à 10 minutes
- "Start editing right away" - édition immédiate
- Export 4K sans watermark
- Timeline frame-accurate
- AI features (voice change, auto captions)

**Leçon clé :** Instagram permet l'édition immédiate sans attendre la compression.

### 4. Meilleures pratiques mobile (2024-2026)

**Architecture moderne :**
- **Stream-centric playback** : Découple decode producer de UI consumer
- **Frame queue** : Producer/consumer pattern pour frames vidéo
- **Hardware acceleration** : MediaCodec (Android) / VideoToolbox (iOS)
- **Progressive download** : Faststart (moov atom au début)
- **Adaptive quality** : Ajustement dynamique selon conditions réseau

---

## Proposition 1 : Résoudre l'écran noir (Affichage vidéo)

### Problème
Initialisation asynchrone de `VideoPlayerController` sans indicateur visuel pendant `_initializing = true`.

### Solution A : Ajouter un indicateur de chargement (Minimal)

**Changement :** Modifier `academia_playback_view.dart` pour afficher un loader pendant l'initialisation.

```dart
// Dans _AcademiaPlaybackViewState.build
if (_initializing) {
  return Container(
    color: Colors.black,
    child: Center(
      child: CircularProgressIndicator(
        color: Colors.white,
      ),
    ),
  );
}
```

**Avantages :**
- Changement minimal
- L'utilisateur sait que quelque chose se passe
- Résout le problème d'écran noir

**Inconvénients :**
- Ne résout pas le problème de lenteur d'initialisation
- L'utilisateur attend quand même

**Effort :** Faible (5-10 minutes)

---

### Solution B : Utiliser le player natif Android pour fichiers locaux (Recommandé)

**Changement :** Modifier la logique dans `academia_playback_view.dart` pour utiliser le player natif Android même pour les fichiers locaux.

**Actuel (ligne 152) :**
```dart
if (_shouldUseNativeAndroid && !isLocalFileUri) {
  // Utilise player natif
}
```

**Proposé :**
```dart
if (_shouldUseNativeAndroid) {
  // Utilise player natif pour TOUT (local et distant)
  // Le player natif Android est plus rapide pour les fichiers locaux
  debugPrint('[AcademiaPlaybackView] using native Android view url=$url');
  setState(() {
    _initializing = false;
    _error = null;
  });
  return;
}
```

**Avantages :**
- Player natif Android plus rapide (MediaCodec hardware acceleration)
- Pas d'initialisation asynchrone Flutter
- Affichage quasi-instantané
- Compatible avec l'architecture existante

**Inconvénients :**
- Risque de crash sur certains devices (commentaire existant dans le code)
- Nécessite tests sur différents devices

**Effort :** Faible (5 minutes)

**Risque :** Moyen

---

### Solution C : Pré-charger le player avant navigation (Avancé)

**Changement :** Initialiser le player dans `ChallengeCameraCaptureScreen` avant de naviguer vers `StudentChallengeVideoEditorScreen`.

```dart
// Dans ChallengeCameraCaptureScreen._confirm
final controller = VideoPlayerController.file(File(segments.first.path));
await controller.initialize();

Navigator.of(context).pop<List<XFile>>(
  _segments.map((s) => s.file).toList(),
  controller: controller, // Passer le controller
);
```

**Avantages :**
- Player déjà initialisé à l'arrivée
- Affichage instantané
- Utilise Flutter video_player (stable)

**Inconvénients :**
- Plus complexe
- Nécessite modification de la signature de navigation
- Gestion du cycle de vie du controller

**Effort :** Moyen (30-45 minutes)

---

**Recommandation :** **Solution B** (Utiliser player natif Android pour tous les fichiers)

---

## Proposition 2 : Résoudre le bouton Suivant (Upload)

### Problème
Bouton disponible mais upload échoue si compression pas terminée (`_videoBytes` null).

### Solution A : Désactiver le bouton jusqu'à fin compression (Simple)

**Changement :** Modifier la condition du bouton "Suivant".

**Actuel (ligne 5403) :**
```dart
onTap: _localVideoPath == null
    ? null
    : _openPublishScreen,
```

**Proposé :**
```dart
onTap: _localVideoPath == null || _isCompressing
    ? null
    : _openPublishScreen,
```

**Avantages :**
- Changement minimal
- Empêche l'utilisateur de cliquer trop tôt
- Clair pour l'utilisateur (bouton désactivé)

**Inconvénients :**
- L'utilisateur doit attendre la compression (3-8 secondes)
- Ne résout pas le problème de fond

**Effort :** Très faible (1 minute)

---

### Solution B : Upload du fichier brut, compression en arrière-plan (Recommandé)

**Changement :** Modifier `_uploadVideo` pour accepter soit `_videoBytes` (compressé) soit `_localVideoPath` (brut).

```dart
Future<void> _uploadVideo() async {
  debugPrint('[Studio] ===== _uploadVideo START =====');
  
  // Priorité : utiliser les bytes compressés si disponibles
  Uint8List? bytesToUpload = _videoBytes;
  String? fileNameToUpload = _fileName;
  
  // Fallback : utiliser le fichier brut si compression pas terminée
  if (bytesToUpload == null && _localVideoPath != null) {
    debugPrint('[Studio] Compression not finished, uploading raw file');
    bytesToUpload = await File(_localVideoPath!).readAsBytes();
    fileNameToUpload = _fileName;
  }
  
  if (bytesToUpload == null || fileNameToUpload == null) {
    debugPrint('[Studio] ABORT: no video bytes or fileName');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sélectionne d\'abord une vidéo.')),
    );
    return;
  }
  
  // ... suite du code avec bytesToUpload
}
```

**Avantages :**
- Bouton "Suivant" fonctionne immédiatement
- Upload commence même si compression pas terminée
- UX similaire à TikTok/Instagram
- Compression continue en arrière-plan pour prochain upload

**Inconvénients :**
- Fichier plus gros uploadé (plus lent)
- Server-side compression nécessaire (déjà implémenté via Edge Function)

**Effort :** Faible (10-15 minutes)

---

### Solution C : Upload chunked avec compression progressive (Avancé)

**Changement :** Implémenter un upload chunked avec compression progressive.

**Architecture :**
1. Compresser les premiers segments du vidéo
2. Upload chunk 1 (début de vidéo)
3. Continuer compression + upload des chunks suivants
4. Server-side reassembly

**Avantages :**
- Upload commence très rapidement
- Progression visible
- Résilience réseau

**Inconvénients :**
- Très complexe à implémenter
- Nécessite modifications server-side
- Beaucoup de temps de développement

**Effort :** Très élevé (plusieurs jours)

---

**Recommandation :** **Solution B** (Upload du fichier brut, compression en arrière-plan)

---

## Proposition 3 : Résoudre l'audio du feed persistant

### Problème
`_pauseAllControllers()` appelé uniquement avant CameraCapture, pas avant VideoEditor.

### Solution A : Appeler pause avant chaque navigation (Simple)

**Changement :** Ajouter `_pauseAllControllers()` dans `StudentChallengeVideoEditorScreen.initState`.

```dart
@override
void initState() {
  super.initState();
  
  // Pause tous les contrôleurs du feed
  // Note : Nécessite un accès global aux contrôleurs
  // Solution : utiliser un service global ou InheritedWidget
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Appeler un service global pour pause les vidéos du feed
    VideoFeedService.pauseAll();
  });
  
  // ... reste du code
}
```

**Avantages :**
- Simple conceptuellement
- Audio arrêté à l'ouverture de l'éditeur

**Inconvénients :**
- Nécessite un service global (VideoFeedService)
- Couplage entre écrans

**Effort :** Moyen (30-45 minutes)

---

### Solution B : Utiliser un service global de gestion audio (Recommandé)

**Changement :** Créer un service singleton `AudioManager` qui gère tous les players vidéo.

```dart
// lib/services/audio_manager.dart
class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();
  
  final Map<String, AcademiaPlaybackController> _controllers = {};
  
  void registerController(String id, AcademiaPlaybackController controller) {
    _controllers[id] = controller;
  }
  
  void unregisterController(String id) {
    _controllers.remove(id);
  }
  
  void pauseAll() {
    for (final controller in _controllers.values) {
      controller.pause();
    }
  }
  
  void muteAll() {
    // Si muting est supporté
  }
}
```

**Utilisation :**
- Dans `student_challenges_tab.dart` : enregistrer les contrôleurs
- Dans `StudentChallengeVideoEditorScreen.initState` : appeler `AudioManager().pauseAll()`

**Avantages :**
- Architecture propre
- Réutilisable pour d'autres écrans
- Centralise la gestion audio

**Inconvénients :**
- Nécessite refactoring de l'existant
- Plus de code à maintenir

**Effort :** Moyen (1-2 heures)

---

### Solution C : Pause lors de la navigation depuis CameraCapture (Alternative)

**Changement :** Appeler `_pauseAllControllers()` dans `ChallengeCameraCaptureScreen` avant de pop vers VideoEditor.

**Problème :** `ChallengeCameraCaptureScreen` n'a pas accès aux contrôleurs du feed.

**Solution :** Passer un callback lors de la navigation.

```dart
// Dans student_challenges_tab.dart
final segments = await Navigator.of(context).push<List<XFile>?>(
  MaterialPageRoute(
    builder: (_) => const ChallengeCameraCaptureScreen(),
  ),
);

// Pause AVANT de naviguer vers VideoEditor
_pauseAllControllers();

if (segments != null && segments.isNotEmpty) {
  // ... navigation vers VideoEditor
}
```

**Avantages :**
- Changement minimal
- Utilise l'infrastructure existante

**Inconvénients :**
- Ne couvre pas le cas gallery → VideoEditor direct
- Pause à deux endroits (redondant)

**Effort :** Très faible (5 minutes)

---

**Recommandation :** **Solution C** (Pause lors de la navigation depuis CameraCapture)

---

## Proposition 4 : Optimiser la compression

### Problème
Compression actuelle (`video_compress`) est lente (3-8 secondes pour 1 minute).

### Solution A : Remplacer par video_compress_kit (Recommandé)

**Changement :** Remplacer `video_compress` par `video_compress_kit`.

**Pourquoi :**
- Zero binary bloat (pas de FFmpeg inclus)
- MediaCodec/VideoToolbox (hardware acceleration)
- Faststart (moov atom au début pour streaming rapide)
- Progress stream plus moderne
- Cancellation support

**Migration :**
```yaml
# pubspec.yaml
dependencies:
  video_compress_kit: ^0.0.3  # Remplacer video_compress
```

```dart
// Remplacer VideoCompress.compressVideo par VideoCompressKit
final result = await VideoCompressKit.compressVideo(
  path: sourcePath,
  config: CompressionConfig(
    quality: VideoQuality.medium,
    resolution: Resolution(1280, 720),
  ),
);
```

**Avantages :**
- Plus rapide (hardware acceleration)
- Plus moderne
- Meilleure gestion des erreurs
- Progress stream plus robuste

**Inconvénients :**
- Nécessite migration du code
- API différente
- Tests nécessaires

**Effort :** Moyen (2-3 heures)

---

### Solution B : Remplacer par v_video_compressor (Alternative)

**Changement :** Remplacer `video_compress` par `v_video_compressor`.

**Pourquoi :**
- Global progress stream (accessible de partout)
- 5 quality levels
- Meilleure documentation
- Plus mature que video_compress_kit

**Migration :**
```yaml
# pubspec.yaml
dependencies:
  v_video_compressor: ^2.0.0
```

**Avantages :**
- API plus simple
- Global progress stream
- Plus de fonctionnalités

**Inconvénients :**
- Plus récent (moins testé)
- Dépendances supplémentaires

**Effort :** Moyen (2-3 heures)

---

### Solution C : Réduire la qualité de compression (Quick fix)

**Changement :** Utiliser une qualité plus basse pour compression plus rapide.

**Actuel :**
```dart
quality: VideoQuality.MediumQuality
```

**Proposé :**
```dart
quality: VideoQuality.LowQuality  // Plus rapide
```

**Avantages :**
- Changement immédiat
- Compression plus rapide

**Inconvénients :**
- Qualité vidéo réduite
- Ne résout pas le problème de fond

**Effort :** Très faible (1 minute)

---

**Recommandation :** **Solution A** (Remplacer par video_compress_kit)

---

## Plan d'implémentation recommandé

### Phase 1 : Corrections immédiates (1-2 heures)

1. **Solution B pour écran noir** : Utiliser player natif Android pour tous les fichiers
   - Fichier : `academia_playback_view.dart`
   - Temps : 5 minutes
   - Risque : Moyen

2. **Solution C pour audio feed** : Pause lors de la navigation depuis CameraCapture
   - Fichier : `student_challenges_tab.dart`
   - Temps : 5 minutes
   - Risque : Faible

3. **Solution A pour bouton Suivant** : Désactiver pendant compression
   - Fichier : `student_challenge_video_editor_screen.dart`
   - Temps : 1 minute
   - Risque : Faible

### Phase 2 : Améliorations UX (2-3 heures)

4. **Solution B pour upload** : Upload du fichier brut, compression en arrière-plan
   - Fichier : `student_challenge_video_editor_screen.dart`
   - Temps : 10-15 minutes
   - Risque : Faible

5. **Solution A pour compression** : Remplacer par video_compress_kit
   - Fichiers : `student_challenge_video_editor_screen.dart`, `pubspec.yaml`
   - Temps : 2-3 heures
   - Risque : Moyen

### Phase 3 : Architecture propre (1-2 heures, optionnel)

6. **Solution B pour audio** : Service global AudioManager
   - Fichiers : `lib/services/audio_manager.dart`, `student_challenges_tab.dart`, `student_challenge_video_editor_screen.dart`
   - Temps : 1-2 heures
   - Risque : Faible

---

## Résumé des propositions

| # | Problème | Solution recommandée | Effort | Risque | Impact |
|---|----------|---------------------|--------|--------|--------|
| 1 | Écran noir | Player natif Android pour tous les fichiers | 5 min | Moyen | Haut |
| 2 | Bouton Suivant | Upload fichier brut + compression arrière-plan | 15 min | Faible | Haut |
| 3 | Audio feed | Pause lors navigation CameraCapture | 5 min | Faible | Moyen |
| 4 | Compression lente | Remplacer par video_compress_kit | 2-3h | Moyen | Haut |

**Temps total estimé :** 2-4 heures pour toutes les corrections

---

## Questions pour validation

1. **Acceptez-vous d'utiliser le player natif Android pour les fichiers locaux ?** (Risque de crash sur certains devices)

2. **Acceptez-vous d'uploader le fichier brut si compression pas terminée ?** (Fichier plus gros, mais server-side compression existe déjà)

3. **Acceptez-vous de remplacer `video_compress` par `video_compress_kit` ?** (Nécessite migration et tests)

4. **Voulez-vous implémenter le service global AudioManager ou la solution simple (pause lors navigation) ?**

5. **Priorité :** Voulez-vous d'abord les corrections immédiates (Phase 1) ou tout implémenter ensemble ?
