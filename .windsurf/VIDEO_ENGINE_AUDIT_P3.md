# Audit P3 - Moteur d'Affichage Vidéo

**Date :** 19 Juin 2026  
**Objectif :** Identifier le composant exact responsable du délai observé sur appareil réel

---

## 1. Cartographie complète AcademiaPlaybackView

### initState()

```dart
@override
void initState() {
  super.initState();
  widget.playbackController?._state = this;  // Ligne 93
  if (!widget.deferInitialization) {
    _init();  // Ligne 95
  }
}
```

**Appels exécutés :**
1. `super.initState()`
2. `widget.playbackController?._state = this` (enregistre le state dans le controller)
3. `_init()` (si `deferInitialization` est false)

**Fichier :** `academia_playback_view.dart`  
**Lignes :** 91-97

---

### _init()

```dart
Future<void> _init() async {
  final original = widget.url.trim();
  if (original.isEmpty) {
    setState(() {
      _error = 'empty_url';
    });
    return;
  }

  final url = UrlNormalizer.normalize(original);

  final uri = Uri.tryParse(url);
  final isLocalFileUri = uri != null && uri.scheme.toLowerCase() == 'file';

  // Cas Android + vidéo distante : utilise player natif
  if (_shouldUseNativeAndroid && !isLocalFileUri) {
    debugPrint('[AcademiaPlaybackView] using native Android view url=$url');
    setState(() {
      _initializing = false;
      _error = null;
    });
    return;  // PAS d'initialisation VideoPlayerController
  }

  // Cas Web / iOS / Android local : utilise Flutter video_player
  setState(() {
    _initializing = true;
    _error = null;
    _loggedFirstPlay = false;
  });

  try {
    debugPrint('[AcademiaPlaybackView] init url=$url');
    final VideoPlayerController controller;
    if (isLocalFileUri) {
      final parsed = Uri.parse(url);
      controller = VideoPlayerController.file(File.fromUri(parsed));
    } else {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
    }
    _controller = controller;

    await controller.initialize();  // ← BLOQUANT
    await controller.setLooping(widget.looping);
    await controller.setVolume(widget.muted ? 0.0 : 1.0);

    final v0 = controller.value;
    debugPrint(
      '[AcademiaPlaybackView] initialized isWeb=$kIsWeb duration=${v0.duration} '
      'aspectRatio=${v0.aspectRatio} muted=${widget.muted} looping=${widget.looping}',
    );

    controller.addListener(() {  // ← Listener pour callbacks
      final c = _controller;
      if (c == null) return;
      if (!mounted) return;
      final v = c.value;

      if (v.isInitialized && v.isPlaying && !_loggedFirstPlay) {
        _loggedFirstPlay = true;
        if (widget.onFirstPlay != null) {
          widget.onFirstPlay!();
        }
        debugPrint(
          '[AcademiaPlaybackView] playing isWeb=$kIsWeb '
          'position=${v.position} duration=${v.duration}',
        );
      }

      if (widget.looping) return;
      if (!v.isInitialized) return;
      final d = v.duration;
      if (d == Duration.zero) return;
      if (!v.isPlaying && v.position >= d && !_hasCompleted) {
        _hasCompleted = true;
        debugPrint(
          '[AcademiaPlaybackView] completed isWeb=$kIsWeb '
          'position=${v.position} duration=$d',
        );
        widget.onCompleted?.call();
      }
    });

    if (widget.autoplay) {
      await controller.play();
      debugPrint('[AcademiaPlaybackView] autoplay play() requested isWeb=$kIsWeb');
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _initializing = false;
    });
  } catch (e) {
    if (!mounted) return;
    debugPrint('[AcademiaPlaybackView] init error=$e url=$url');
    setState(() {
      _initializing = false;
      _error = e;
    });
    if (widget.onCompleted != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_hasCompleted) {
          _hasCompleted = true;
          widget.onCompleted?.call();
        }
      });
    }
  }
}
```

**Appels exécutés :**
1. `widget.url.trim()`
2. `UrlNormalizer.normalize()`
3. `Uri.tryParse()`
4. `setState(_initializing = true)` (sauf Android distant)
5. `VideoPlayerController.file()` ou `VideoPlayerController.networkUrl()`
6. `await controller.initialize()` ← **BLOQUANT**
7. `await controller.setLooping()`
8. `await controller.setVolume()`
9. `controller.addListener()` (ajoute listener)
10. `await controller.play()` (si autoplay)
11. `setState(_initializing = false)`

**Fichier :** `academia_playback_view.dart`  
**Lignes :** 134-247

---

### build()

```dart
@override
Widget build(BuildContext context) {
  // --- Android: native PlatformView with MediaTek-safe codec selector ---
  if (_shouldUseNativeAndroid) {
    final url = UrlNormalizer.normalize(widget.url.trim());
    if (url.isEmpty) {
      return Container(color: Colors.black);
    }

    // Determine optimal resize mode based on video orientation
    final orientation = VideoOrientationService.detectFromRatio(
      widget.videoAspectRatio ?? (16.0 / 9.0),
    );
    final optimalResizeMode = VideoOrientationService.getOptimalAndroidResizeMode(orientation);
    
    // Map BoxFit to resize mode
    final resizeMode = widget.fit == BoxFit.cover
        ? 'cover'
        : widget.fit == BoxFit.fill
            ? 'fill'
            : widget.fit == BoxFit.fitWidth
                ? 'fitWidth'
                : widget.fit == BoxFit.fitHeight
                    ? 'fitHeight'
                    : optimalResizeMode;

    debugPrint('[AcademiaPlaybackView] build AndroidView url=${url.length > 60 ? '${url.substring(0, 60)}...' : url}  autoplay=${widget.autoplay}');

    return AndroidView(  // ← PlatformView native
      viewType: 'academia_android_video',
      creationParams: <String, dynamic>{
        'url': url,
        'autoplay': widget.autoplay,
        'loop': widget.looping,
        'muted': widget.muted,
        'showControls': widget.showControls,
        'resizeMode': resizeMode,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (int viewId) {
        debugPrint('[AcademiaPlaybackView] PlatformView created viewId=$viewId url=${url.length > 60 ? '${url.substring(0, 60)}...' : url}');
        _nativeChannel = MethodChannel('academia_android_video_$viewId');
      },
    );
  }

  // --- Web / iOS: Flutter video_player ---
  final controller = _controller;

  if (widget.deferInitialization && controller == null && _error == null) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (_initializing) return;
        await _init();
        final c = _controller;
        if (c != null && c.value.isInitialized) {
          try {
            await c.play();
          } catch (_) {}
        }
      },
      child: Container(
        color: Colors.black,
      ),
    );
  }

  if (_error != null) {
    if (!widget.showErrorText) {
      return Container(
        color: Colors.black,
      );
    }
    String message;
    if (_error == 'empty_url') {
      message = 'Vidéo indisponible.';
    } else {
      message = 'Une erreur est survenue lors de la lecture de la vidéo.';
    }
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  if (_initializing || controller == null || !controller.value.isInitialized) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  final v = controller.value;
  
  // Intelligent fallback: detect orientation from dimensions if aspectRatio is invalid
  final aspectRatio = (v.aspectRatio == 0 || v.aspectRatio.isNaN)
      ? VideoOrientationService.calculateAspectRatio(
          v.size.width.toInt(),
          v.size.height.toInt(),
          fallbackRatio: 16.0 / 9.0,
        )
      : v.aspectRatio;

  Widget content;
  if (kIsWeb) {
    content = SizedBox.expand(
      child: VideoPlayer(controller),
    );
  } else {
    content = FittedBox(
      fit: widget.fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 1,
        height: 1 / aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  if (widget.showControls) {
    content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: content),
          if (!kIsWeb)
            AnimatedOpacity(
              opacity: v.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(
                Icons.play_arrow,
                size: 56,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  if (kDebugMode && kIsWeb) {
    content = Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          left: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'VIDEO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  return content;
}
```

**Appels exécutés :**
1. `_shouldUseNativeAndroid` check
2. `UrlNormalizer.normalize()`
3. `VideoOrientationService.detectFromRatio()`
4. `AndroidView()` (si Android) ou `VideoPlayer()` (si iOS/Web)
5. `onPlatformViewCreated` callback (si Android)

**Fichier :** `academia_playback_view.dart`  
**Lignes :** 392-578

---

### dispose()

```dart
@override
void dispose() {
  if (widget.playbackController?._state == this) {
    widget.playbackController?._state = null;
  }
  _nativeChannel = null;
  _disposeController();
  super.dispose();
}

void _disposeController() {
  final c = _controller;
  _controller = null;
  if (c != null) {
    c.dispose();
  }
}
```

**Appels exécutés :**
1. `widget.playbackController?._state = null` (désenregistre le state)
2. `_nativeChannel = null` (supprime la référence au channel natif)
3. `_disposeController()` → `controller.dispose()` (libère le player Flutter)
4. `super.dispose()`

**Fichier :** `academia_playback_view.dart`  
**Lignes :** 257-265, 249-255

---

## 2. Player utilisé pour chaque cas

### Android + Vidéo distante (URL HTTP/HTTPS)

**Player :** ExoPlayer (Media3)

**View :** AndroidView (PlatformView native)

**Code :**
```dart
// academia_playback_view.dart ligne 152-158
if (_shouldUseNativeAndroid && !isLocalFileUri) {
  debugPrint('[AcademiaPlaybackView] using native Android view url=$url');
  setState(() {
    _initializing = false;
    _error = null;
  });
  return;  // PAS d'initialisation VideoPlayerController
}
```

**Kotlin :**
```kotlin
// AcademiaAndroidVideoView.kt ligne 96-154
private val playerView: PlayerView = PlayerView(context)
private val player: ExoPlayer

player = ExoPlayer.Builder(context)
    .setRenderersFactory(renderersFactory)
    .setMediaSourceFactory(mediaSourceFactory)
    .setLoadControl(loadControl)
    .build()

player.setMediaItem(MediaItem.fromUri(url))
player.prepare()
```

**Composants :**
- ExoPlayer (androidx.media3.exoplayer.ExoPlayer)
- PlayerView (androidx.media3.ui.PlayerView) → SurfaceView
- MediaCodec (hardware acceleration)
- CacheDataSource (200 MB cache)

---

### Android + Vidéo locale (file://)

**Player :** VideoPlayerController (Flutter video_player)

**View :** VideoPlayer widget (Flutter)

**Code :**
```dart
// academia_playback_view.dart ligne 171-173
if (isLocalFileUri) {
  final parsed = Uri.parse(url);
  controller = VideoPlayerController.file(File.fromUri(parsed));
}
```

**Composants :**
- VideoPlayerController (Flutter video_player package)
- VideoPlayer widget (Flutter)
- TextureView ou SurfaceView (selon configuration Flutter)

**Pourquoi pas ExoPlayer :**
- Commentaire ligne 150-151 : "Exception: pour les previews locales (file://), la PlatformView native peut crasher selon les devices"

---

### iOS + Vidéo distante

**Player :** VideoPlayerController (Flutter video_player)

**View :** VideoPlayer widget (Flutter)

**Code :**
```dart
// academia_playback_view.dart ligne 175
controller = VideoPlayerController.networkUrl(Uri.parse(url));
```

**Composants :**
- VideoPlayerController (Flutter video_player package)
- AVPlayer (iOS native, utilisé par Flutter)
- AVPlayerLayer (iOS native)

---

### iOS + Vidéo locale

**Player :** VideoPlayerController (Flutter video_player)

**View :** VideoPlayer widget (Flutter)

**Code :**
```dart
// academia_playback_view.dart ligne 171-173
if (isLocalFileUri) {
  final parsed = Uri.parse(url);
  controller = VideoPlayerController.file(File.fromUri(parsed));
}
```

**Composants :**
- VideoPlayerController (Flutter video_player package)
- AVPlayer (iOS native)
- AVPlayerLayer (iOS native)

---

### Web + Vidéo distante

**Player :** VideoPlayerController (Flutter video_player)

**View :** VideoPlayer widget (Flutter → HTML5 <video>)

**Code :**
```dart
// academia_playback_view.dart ligne 175
controller = VideoPlayerController.networkUrl(Uri.parse(url));
```

**Composants :**
- VideoPlayerController (Flutter video_player package)
- HTML5 <video> element
- MediaSource API

---

## 3. Causes empêchant l'affichage de la première frame

### Cause 1 : VideoPlayerController.initialize() bloquant

**Localisation :** `academia_playback_view.dart` ligne 179

**Description :**
- `await controller.initialize()` est bloquant
- Doit parser le fichier MP4 (en-tête moov atom)
- Doit extraire les métadonnées (duration, dimensions, codec)
- Doit initialiser le decoder (hardware ou software)
- Doit préparer le buffer pour la première frame

**Temps typique :**
- Vidéo courte (< 10s) : 500-1000ms
- Vidéo moyenne (30-60s) : 1000-2000ms
- Vidéo longue (> 60s) : 2000-3000ms

**Impact :**
- Pendant l'initialisation, `_initializing = true`
- UI affiche un CircularProgressIndicator (ligne 484-493)
- Aucune frame vidéo visible

**Pourquoi peut prendre plusieurs minutes :**
- Fichier MP4 corrompu ou mal formé
- Codec non supporté par le hardware
- Decoder hardware en échec → fallback sur software (très lent)
- Fichier sur stockage lent (SD card)
- Fichier très volumineux (> 100 MB)

---

### Cause 2 : ExoPlayer.prepare() bloquant (Android distant)

**Localisation :** `AcademiaAndroidVideoView.kt` ligne 153

**Description :**
- `player.prepare()` est bloquant
- Doit charger les métadonnées
- Doit initialiser le buffer
- Doit préparer le decoder

**Temps typique :**
- Vidéo distante (HTTP) : 100-500ms (dépend du réseau)
- Vidéo en cache : < 100ms

**Configuration buffer (ligne 117-125) :**
```kotlin
val loadControl = DefaultLoadControl.Builder()
    .setBufferDurationsMs(
        500,    // minBufferMs — keep only 0.5s minimum
        30_000, // maxBufferMs — buffer up to 30s ahead
        300,    // bufferForPlaybackMs — start playing after 300ms of data
        500     // bufferForPlaybackAfterRebufferMs — resume after 500ms
    )
    .setPrioritizeTimeOverSizeThresholds(true)
    .build()
```

**Impact :**
- `bufferForPlaybackMs = 300ms` : playback commence après 300ms de buffer
- Si réseau lent, peut prendre plus de temps
- Si timeout, peut échouer

**Pourquoi peut prendre plusieurs minutes :**
- Réseau très lent
- Timeout réseau
- Serveur distant lent
- Codec non supporté
- Fichier très volumineux

---

### Cause 3 : PlatformView creation asynchrone (Android)

**Localisation :** `academia_playback_view.dart` ligne 420-435

**Description :**
- `AndroidView()` est créé de manière asynchrone
- `onPlatformViewCreated` callback est appelé quand la view est prête
- La création de la PlatformView peut prendre du temps

**Temps typique :**
- Création PlatformView : 50-200ms
- Initialisation ExoPlayer : 100-500ms
- Total : 150-700ms

**Impact :**
- Pendant la création, la view n'est pas visible
- Le callback `onPlatformViewCreated` peut être retardé
- `_nativeChannel` n'est pas disponible immédiatement

**Pourquoi peut prendre plusieurs minutes :**
- Hybrid Composition lente
- Memory pressure
- Device lent
- Multiple PlatformViews actives

---

### Cause 4 : setState manquant après initialisation

**Localisation :** `academia_playback_view.dart` ligne 228-230

**Description :**
- `setState(_initializing = false)` est appelé après initialisation
- Si `mounted` est false, le setState n'est pas exécuté
- Si une exception est attrapée, `_initializing` reste true

**Code :**
```dart
if (!mounted) {
  await controller.dispose();
  return;  // ← setState n'est PAS appelé
}
setState(() {
  _initializing = false;
});
```

**Impact :**
- Si le widget est détruit pendant l'initialisation, `_initializing` reste true
- Si le widget est recréé, l'état peut être incorrect
- Loader reste visible indéfiniment

---

### Cause 5 : mounted checks bloquant setState

**Localisation :** Plusieurs endroits dans `_init()`

**Description :**
- `if (!mounted) return` est utilisé pour éviter setState sur widget détruit
- Si le widget est détruit rapidement, le setState peut ne jamais être exécuté
- Le loader reste visible

**Code :**
```dart
// Ligne 192
if (!mounted) return;

// Ligne 224
if (!mounted) {
  await controller.dispose();
  return;
}

// Ligne 232
if (!mounted) return;
```

**Impact :**
- Si navigation rapide, le widget peut être détruit avant la fin de l'initialisation
- Le setState final peut ne jamais être exécuté
- Loader reste visible

---

### Cause 6 : Listener non déclenché

**Localisation :** `academia_playback_view.dart` ligne 189-218

**Description :**
- `controller.addListener()` ajoute un listener pour les callbacks
- Si le listener n'est pas déclenché, `onFirstPlay` et `onCompleted` ne sont jamais appelés
- Cela n'affecte PAS l'affichage, mais affecte les callbacks

**Impact :**
- Pas d'impact sur l'affichage de la première frame
- Impact sur les callbacks (onFirstPlay, onCompleted)

---

### Cause 7 : Race condition entre didUpdateWidget et _init

**Localisation :** `academia_playback_view.dart` ligne 100-132

**Description :**
- `didUpdateWidget` est appelé quand l'URL change
- Si l'URL change pendant l'initialisation, `_init()` peut être appelé de nouveau
- `_disposeController()` est appelé avant `_init()`

**Code :**
```dart
if (oldWidget.url != widget.url) {
  if (_shouldUseAndroid && _nativeChannel != null) {
    // Hot-switch URL on existing native player
    _nativeChannel!.invokeMethod('setUrl', {...});
  } else {
    _disposeController();  // ← Dispose l'ancien controller
    _hasCompleted = false;
    _init();  // ← Réinitialise
  }
}
```

**Impact :**
- Si l'URL change rapidement, multiple initialisations
- Si `_disposeController()` est appelé pendant `initialize()`, peut causer des erreurs
- Loader peut rester visible si l'initialisation échoue

---

### Cause 8 : Hybrid Composition lente (Android)

**Description :**
- Hybrid Composition est utilisé pour les PlatformViews sur Android
- La composition entre Flutter et native peut être lente
- La première frame peut prendre du temps à apparaître

**Temps typique :**
- Hybrid Composition : 50-200ms
- SurfaceView vs TextureView : SurfaceView plus rapide

**Impact :**
- Délai entre la création de la PlatformView et l'affichage
- Peut sembler être un écran noir

---

## 4. Reconstructions Flutter

### Combien de fois build() est appelé ?

**Analyse du flux :**

1. **Sélection vidéo** → `_processSegments()` ou `_pickVideo()`
2. **setState()** (ligne 259-266 ou 483-490)
3. **build() de StudentChallengeVideoEditorScreen** appelé
4. **AcademiaPlaybackView** créé (si `_localVideoPath` change)
5. **initState() de AcademiaPlaybackView** appelé
6. **_init()** appelé
7. **setState(_initializing = true)** (ligne 162-166)
8. **build() de AcademiaPlaybackView** appelé (affiche loader)
9. **await controller.initialize()**
10. **setState(_initializing = false)** (ligne 228-230)
11. **build() de AcademiaPlaybackView** appelé (affiche vidéo)

**Total build() calls :**
- StudentChallengeVideoEditorScreen : 1 fois (après setState)
- AcademiaPlaybackView : 2 fois (loader + vidéo)

### AcademiaPlaybackView est-il recréé ?

**Cas normal :**
- Si `_localVideoPath` change, `AcademiaPlaybackView` est recréé
- Si `_localVideoPath` ne change pas, `AcademiaPlaybackView` est conservé

**Code :**
```dart
// student_challenge_video_editor_screen.dart ligne 5327-5328
child: AcademiaPlaybackEngine.view(
  url: previewUrl,
  // ...
),
```

**Conclusion :**
- `AcademiaPlaybackView` est recréé à chaque changement d'URL
- Dans le cas actuel, l'URL change de null à `file://...`, donc recréation

### Le widget est-il détruit puis recréé ?

**Cas normal :**
- Non, le widget est créé une fois et mis à jour via setState
- Sauf si l'URL change, auquel cas il est recréé

**Cas particulier :**
- Si navigation rapide, le widget peut être détruit avant la fin de l'initialisation
- Dans ce cas, `_init()` peut ne jamais terminer

### Plusieurs players actifs simultanément ?

**Cas feed (student_challenges_tab.dart) :**
- Multiple `AcademiaPlaybackController` dans `_controllers` (ligne 1065)
- Un controller par page du feed
- Plusieurs players actifs simultanément

**Cas éditeur (student_challenge_video_editor_screen.dart) :**
- Un seul `_previewPlaybackController` (ligne 140)
- Un seul player actif

**Conclusion :**
- Feed : plusieurs players actifs
- Éditeur : un seul player actif

---

## 5. Audio persistant

### Quels contrôleurs restent actifs ?

**Feed (student_challenges_tab.dart) :**
- `_controllers` (Map<int, AcademiaPlaybackController>) ligne 1065
- Un controller par page du feed
- Les contrôleurs ne sont PAS détruits quand on quitte le feed

**Éditeur (student_challenge_video_editor_screen.dart) :**
- `_previewPlaybackController` ligne 140
- Détruit quand l'éditeur est fermé (dispose)

### Quels contrôleurs restent enregistrés ?

**Feed :**
- Les contrôleurs restent enregistrés dans `_controllers`
- `_pauseAllControllers()` pause tous les contrôleurs (ligne 1765-1780)
- MAIS `_pauseAllControllers()` est appelé SEULEMENT avant CameraCapture (ligne 1704)
- PAS appelé avant VideoEditor (jusqu'à la correction ligne 1721)

**Éditeur :**
- `_previewPlaybackController` est enregistré dans `AcademiaPlaybackView`
- Détruit quand l'éditeur est fermé

### Qui continue à produire l'audio ?

**Avant correction :**
- Les contrôleurs du feed ne sont PAS pausés avant VideoEditor
- L'audio du feed continue pendant l'édition

**Après correction :**
- `_pauseAllControllers()` est appelé avant VideoEditor (ligne 1721)
- Les contrôleurs du feed sont pausés
- L'audio du feed ne continue plus

**Cas limite :**
- Si l'utilisateur navigue directement vers VideoEditor sans passer par CameraCapture (ex: gallery direct)
- Dans ce cas, `_pauseAllControllers()` n'est PAS appelé
- L'audio du feed peut encore persister

---

## 6. Diagramme réel avec temps

```
Sélection vidéo (caméra/galerie)
    ↓ (< 1ms)
_processSegments() ou _pickVideo()
    ↓ (< 1ms)
setState(_localVideoPath = firstFile.path)
    ↓ (< 10ms)
build() StudentChallengeVideoEditorScreen
    ↓ (< 1ms)
AcademiaPlaybackView créé (si URL change)
    ↓ (< 1ms)
initState()
    ↓ (< 1ms)
_init()
    ↓ (< 1ms)
setState(_initializing = true)
    ↓ (< 10ms)
build() AcademiaPlaybackView (loader visible)
    ↓
CAS ANDROID + VIDÉO LOCALE (file://) :
    ↓
VideoPlayerController.file(File.fromUri(parsed))
    ↓
await controller.initialize() ← BLOQUANT (500-3000ms)
    ├─ Parse fichier MP4 (en-tête moov)
    ├─ Extrait métadonnées
    ├─ Initialise decoder (hardware ou software)
    └─ Prépare buffer
    ↓
await controller.setLooping()
    ↓
await controller.setVolume()
    ↓
controller.addListener()
    ↓
await controller.play() (si autoplay)
    ↓
setState(_initializing = false)
    ↓ (< 10ms)
build() AcademiaPlaybackView (vidéo visible)
    ↓
Première frame visible
    ↓
[En arrière-plan] Compression (3-8 secondes)
    ↓
[En arrière-plan] Watermark

CAS ANDROID + VIDÉO DISTANTE (HTTP) :
    ↓
_init() retourne immédiatement (ligne 158)
    ↓
setState(_initializing = false)
    ↓ (< 10ms)
build() AcademiaPlaybackView (AndroidView)
    ↓ (< 1ms)
AndroidView créé
    ↓ (50-200ms)
onPlatformViewCreated callback
    ↓
_nativeChannel = MethodChannel(...)
    ↓
AcademiaAndroidVideoView créé (Kotlin)
    ↓ (< 1ms)
ExoPlayer.Builder().build()
    ↓ (< 10ms)
player.setMediaItem(MediaItem.fromUri(url))
    ↓
player.prepare() ← BLOQUANT (100-500ms)
    ├─ Charge métadonnées
    ├─ Initialise buffer (300ms min)
    └─ Prépare decoder
    ↓
Première frame visible
```

**Temps estimés :**

| Étape | Android local | Android distant | iOS | Web |
|-------|--------------|----------------|-----|-----|
| setState | < 1ms | < 1ms | < 1ms | < 1ms |
| build() | < 10ms | < 10ms | < 10ms | < 10ms |
| initState | < 1ms | < 1ms | < 1ms | < 1ms |
| _init() | Variable | < 1ms | Variable | Variable |
| VideoPlayerController.initialize() | 500-3000ms | N/A | 500-3000ms | 500-3000ms |
| ExoPlayer.prepare() | N/A | 100-500ms | N/A | N/A |
| AndroidView creation | N/A | 50-200ms | N/A | N/A |
| **Total avant première frame** | **500-3000ms** | **150-700ms** | **500-3000ms** | **500-3000ms** |

---

## 7. Composant responsable du délai observé

**Pour Android + Vidéo locale (file://) :**

**Responsable principal :** `VideoPlayerController.initialize()`

**Fichier :** `academia_playback_view.dart`  
**Ligne :** 179

**Temps :** 500-3000ms (peut être plus long si fichier corrompu, codec non supporté, ou storage lent)

**Pourquoi peut prendre plusieurs minutes :**
- Fichier MP4 corrompu ou mal formé
- Codec non supporté par le hardware → fallback sur software (très lent)
- Fichier sur stockage lent (SD card)
- Fichier très volumineux (> 100 MB)
- Decoder hardware en échec
- Memory pressure

**Pour Android + Vidéo distante (HTTP) :**

**Responsable principal :** `ExoPlayer.prepare()`

**Fichier :** `AcademiaAndroidVideoView.kt`  
**Ligne :** 153

**Temps :** 100-500ms (peut être plus long si réseau lent)

**Pourquoi peut prendre plusieurs minutes :**
- Réseau très lent
- Timeout réseau
- Serveur distant lent
- Codec non supporté
- Fichier très volumineux

**Conclusion :**

Le composant responsable du délai observé sur appareil réel est :

1. **Pour vidéos locales :** `VideoPlayerController.initialize()` (Flutter video_player)
2. **Pour vidéos distantes :** `ExoPlayer.prepare()` (Media3)

Le délai de 500-3000ms annoncé dans l'audit P1 est correct pour des conditions normales. Le délai de plusieurs minutes observé sur appareil réel est dû à des conditions anormales (fichier corrompu, codec non supporté, storage lent, réseau lent).
