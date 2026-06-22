# AUDIT P14 – 3 BLOCS DE CODE CRITIQUES

**Date :** 19 Juin 2026  
**Objectif :** Analyser les 3 morceaux de code qui peuvent expliquer le bug de l'écran noir

---

## FICHIER N°1 : _compressAndWatermarkInBackground

**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart`

```dart
Future<void> _compressAndWatermarkInBackground(String sourcePath, String originalName, DateTime t0) async {
  final enterTime = DateTime.now();
  debugPrint('[P6_ENTER] _compressAndWatermarkInBackground');
  if (!mounted) return;

  final ext = originalName.contains('.') ? originalName.split('.').last : 'mp4';

  // Show compression indicator
  if (mounted) {
    setState(() => _isCompressing = true);
  }

  final t1 = DateTime.now();
  debugPrint('[TIMING] T1 - Début compression (background): ${t1.toIso8601String()} (ΔT1-T0: ${t1.difference(t0).inMilliseconds}ms)');

  try {
    // Detect video orientation for compression preset
    final orientation = VideoOrientationService.detectFromDimensions(1920, 1080);
    
    // Use orientation-aware compression preset
    final VideoQuality quality;
    if (_hdUpload) {
      quality = VideoQuality.Res1920x1080Quality;
    } else {
      quality = VideoQuality.MediumQuality;
    }
    
    final compressStart = DateTime.now();
    debugPrint('[P6_COMPRESSION] START');
    final MediaInfo? info = await VideoCompress.compressVideo(
      sourcePath,
      quality: quality,
      deleteOrigin: false,
      includeAudio: true,
    );

    final compressEnd = DateTime.now();
    final compressDuration = compressEnd.difference(compressStart).inMilliseconds;
    debugPrint('[P6_COMPRESSION] END duration=${compressDuration}ms');

    final t2 = DateTime.now();
    debugPrint('[TIMING] T2 - Fin compression (background): ${t2.toIso8601String()} (ΔT2-T1: ${t2.difference(t1).inMilliseconds}ms)');

    if (!mounted) return;

    if (info != null && info.path != null) {
      final originalSize = await File(sourcePath).length();

      // Add Academia watermark
      debugPrint('[Studio] Adding Academia watermark (background)...');
      final watermarkStart = DateTime.now();
      debugPrint('[P6_WATERMARK] START');
      final watermarkedPath = await WatermarkService.addWatermark(info.path!);
      final watermarkEnd = DateTime.now();
      final watermarkDuration = watermarkEnd.difference(watermarkStart).inMilliseconds;
      debugPrint('[P6_WATERMARK] END duration=${watermarkDuration}ms');
      if (!mounted) return;

      final finalFile = File(watermarkedPath);
      final finalBytes = await finalFile.readAsBytes();
      final compressedSize = finalBytes.length;
      debugPrint(
        '[Studio] Compression+Watermark (background): ${(originalSize / 1024 / 1024).toStringAsFixed(1)} MB → '
        '${(compressedSize / 1024 / 1024).toStringAsFixed(1)} MB '
        '(${(100 - compressedSize * 100 / originalSize).toStringAsFixed(0)}% réduit)',
      );

      if (mounted) {
        setState(() {
          _isCompressing = false;
          _videoBytes = finalBytes;
          _localVideoPath = watermarkedPath;
          if (info.duration != null) _videoDurationMs = info.duration!.toInt();
        });
      }
      final exitTime = DateTime.now();
      final duration = exitTime.difference(enterTime).inMilliseconds;
      debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
      return;
    } else {
      debugPrint('[Studio] Compression returned null, watermarking original (background)...');
      final watermarkedPath = await WatermarkService.addWatermark(sourcePath);
      if (!mounted) return;
      final bytes = await File(watermarkedPath).readAsBytes();
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _videoBytes = bytes;
          _localVideoPath = watermarkedPath;
        });
      }
      final exitTime = DateTime.now();
      final duration = exitTime.difference(enterTime).inMilliseconds;
      debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
      return;
    }
  } catch (e) {
    debugPrint('[Studio] Compression error (background): $e — watermarking original...');
    if (!mounted) return;
    final watermarkedPath = await WatermarkService.addWatermark(sourcePath);
    if (!mounted) return;
    final bytes = await File(watermarkedPath).readAsBytes();
    if (mounted) {
      setState(() {
        _isCompressing = false;
        _videoBytes = bytes;
        _localVideoPath = watermarkedPath;
      });
    }
    final exitTime = DateTime.now();
    final duration = exitTime.difference(enterTime).inMilliseconds;
    debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms (error)');
  }
}
```

**Analyse critique :**
- Cette méthode met à jour `_localVideoPath` via `setState()` après compression/watermark
- Le `setState()` déclenche un rebuild du widget
- `_localVideoPath` change de la valeur initiale (vidéo brute) vers la valeur finale (vidéo compressée/watermarkée)
- **PROBLÈME POTENTIEL :** Si le player est initialisé avec la vidéo brute, puis `_localVideoPath` change, le player peut ne pas être recréé correctement

---

## FICHIER N°2 : build() de l'éditeur vidéo (partie AcademiaPlaybackEngine.view)

**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart`

```dart
@override
Widget build(BuildContext context) {
  final bool hasUrl = _uploadedUrl != null && _uploadedUrl!.isNotEmpty;
  final bool hasLocalVideo = _localVideoPath != null && _localVideoPath!.isNotEmpty;
  final bool hasVideo = hasUrl || hasLocalVideo;

  final String? effectivePreviewUrl = hasLocalVideo
      ? Uri.file(_localVideoPath!).toString()
      : (hasUrl ? _uploadedUrl : null);

  debugPrint('[P9_BUILD_EDITOR] local=$_localVideoPath effective=$effectivePreviewUrl uploaded=$_uploadedUrl');

  final bool isLocalPreview = (effectivePreviewUrl ?? '').startsWith('file://');

  // Mode studio plein écran TikTok/CapCut : vidéo en fond, barre d'outils
  // horizontale en bas, bouton "Suivant" en haut à droite.
  if (hasVideo) {
    if (effectivePreviewUrl == null || effectivePreviewUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    final String previewUrl = effectivePreviewUrl;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Vidéo plein écran + overlays ──
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AcademiaPlaybackEngine.view(
                    url: previewUrl,
                    preferFlutterPlayer: false,
                    autoplay: isLocalPreview,
                    looping: isLocalPreview,
                    muted: false,
                    showControls: false,
                    fit: BoxFit.cover,
                    playbackController: _previewPlaybackController,
                  ),
                ),
                Positioned.fill(
                  child: _TimedStudioOverlaysLayer(
                    overlays: _buildOverlaysPayload(),
                    controller: _previewPlaybackController,
                  ),
                ),
                Positioned.fill(
                  child: _DraggableZonesLayer(
                    zones: _zones,
                    selectedIndex: _selectedZoneIndex,
                    onZoneMoved: (index, dx, dy) {
                      setState(() {
                        final z = Map<String, dynamic>.from(_zones[index]);
                        z['x'] = ((z['x'] as num?)?.toDouble() ?? 0.1) + dx;
                        z['y'] = ((z['y'] as num?)?.toDouble() ?? 0.1) + dy;
                        _zones[index] = z;
                      });
                    },
                    onZoneTapped: (index) {
                      setState(() => _selectedZoneIndex = index);
                      _editZoneText(index);
                    },
                  ),
                ),
              ],
            ),
          ),
          // ... (suite de l'UI)
        ],
      ),
    );
  }
  // ... (suite du build)
}
```

**Analyse critique :**
- `effectivePreviewUrl` est recalculé à chaque build : `Uri.file(_localVideoPath!)`
- Si `_localVideoPath` change (après compression), `effectivePreviewUrl` change
- `AcademiaPlaybackEngine.view` reçoit la nouvelle URL
- **PROBLÈME POTENTIEL :** `didUpdateWidget()` dans AcademiaPlaybackView peut ne pas gérer correctement le changement d'URL locale
- `preferFlutterPlayer: false` force l'utilisation du player natif Android
- `autoplay: isLocalPreview` et `looping: isLocalPreview` sont activés pour les vidéos locales

---

## FICHIER N°3 : AcademiaPlaybackView complète

**Fichier :** `lib/video/academia_playback_view.dart`

```dart
class _AcademiaPlaybackViewState extends State<AcademiaPlaybackView> {
  // --- P13: Instance tracking ---
  final String _instanceId = DateTime.now().millisecondsSinceEpoch.toString();

  // --- Web: uses Flutter video_player ---
  VideoPlayerController? _controller;

  // --- Shared state ---
  bool _initializing = false;
  Object? _error;
  bool _hasCompleted = false;
  bool _loggedFirstPlay = false;

  // Android native MethodChannel
  MethodChannel? _nativeChannel;
  bool _isPaused = false;

  /// True when running on Android (not web).
  bool get _useNativeAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _shouldUseNativeAndroid => _useNativeAndroid && !widget.preferFlutterPlayer;

  @override
  void initState() {
    debugPrint('[P13_CREATE] id=$_instanceId url=${widget.url.length > 60 ? widget.url.substring(0, 60) : widget.url}');
    super.initState();
    debugPrint('[RUNTIME LIFECYCLE] AcademiaPlaybackView initState - url=${widget.url.length > 60 ? widget.url.substring(0, 60) : widget.url} deferInitialization=${widget.deferInitialization}');
    debugPrint('[P9_VIEW] widget.url=${widget.url}');
    widget.playbackController?._state = this;
    if (!widget.deferInitialization) {
      _init();
    }
  }

  @override
  void didUpdateWidget(covariant AcademiaPlaybackView oldWidget) {
    debugPrint('[P13_UPDATE] id=$_instanceId oldUrl=${oldWidget.url.length > 60 ? oldWidget.url.substring(0, 60) : oldWidget.url} newUrl=${widget.url.length > 60 ? widget.url.substring(0, 60) : widget.url}');
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      if (_shouldUseNativeAndroid && _nativeChannel != null) {
        // Hot-switch URL on existing native player — no PlatformView recreation
        final newUrl = UrlNormalizer.normalize(widget.url.trim());
        if (newUrl.isNotEmpty) {
          _nativeChannel!.invokeMethod('setUrl', {
            'url': newUrl,
            'autoplay': widget.autoplay,
          });
          debugPrint('[AcademiaPlaybackView] setUrl on existing player: ${newUrl.length > 60 ? '${newUrl.substring(0, 60)}...' : newUrl}');
        }
        _hasCompleted = false;
      } else {
        _disposeController();
        _hasCompleted = false;
        _init();
      }
    } else if (oldWidget.muted != widget.muted) {
      _controller?.setVolume(widget.muted ? 0.0 : 1.0);
      if (_shouldUseNativeAndroid && _nativeChannel != null) {
        _nativeChannel!.invokeMethod('setVolume', {'volume': widget.muted ? 0.0 : 1.0});
      }
    } else if (oldWidget.autoplay != widget.autoplay && _shouldUseNativeAndroid && _nativeChannel != null) {
      // Autoplay state changed (e.g. page became active/inactive)
      if (widget.autoplay) {
        _nativeChannel!.invokeMethod('play');
      } else {
        _nativeChannel!.invokeMethod('pause');
      }
    }
  }

  Future<void> _init() async {
    final enterTime = DateTime.now();
    debugPrint('[P6_ENTER] AcademiaPlaybackView._init');
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

    debugPrint('[P8_INIT] url=$url isLocal=$isLocalFileUri');

    // Sur Android, on utilise la PlatformView native qui a le filtre MediaTek.
    // Pas besoin d'initialiser un VideoPlayerController.
    // Exception: pour les previews locaux (file://), la PlatformView native peut
    // crasher selon les devices. Dans ce cas on utilise video_player.
    if (_shouldUseNativeAndroid && !isLocalFileUri) {
      debugPrint('[RUNTIME PLAYER] Using native Android view - url=${url.length > 60 ? url.substring(0, 60) : url}');
      setState(() {
        _initializing = false;
        _error = null;
      });
      return;
    }

    // --- Web / iOS: Flutter video_player ---
    debugPrint('[RUNTIME PLAYER] Using Flutter video_player - url=${url.length > 60 ? url.substring(0, 60) : url} isLocalFileUri=$isLocalFileUri');
    setState(() {
      _initializing = true;
      _error = null;
      _loggedFirstPlay = false;
    });

    try {
      debugPrint('[RUNTIME PLAYER] Creating VideoPlayerController - url=${url.length > 60 ? url.substring(0, 60) : url}');
      final VideoPlayerController controller;
      if (isLocalFileUri) {
        final parsed = Uri.parse(url);
        controller = VideoPlayerController.file(File.fromUri(parsed));
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      _controller = controller;

      debugPrint('[RUNTIME PLAYER] Calling initialize() - START');
      final stopwatch = Stopwatch()..start();
      await controller.initialize();
      stopwatch.stop();
      debugPrint('[RUNTIME PLAYER] Calling initialize() - END - duration=${stopwatch.elapsedMilliseconds}ms');

      await controller.setLooping(widget.looping);
      await controller.setVolume(widget.muted ? 0.0 : 1.0);

      final v0 = controller.value;
      debugPrint(
        '[RUNTIME PLAYER] Initialized - isWeb=$kIsWeb duration=${v0.duration} '
        'aspectRatio=${v0.aspectRatio} muted=${widget.muted} looping=${widget.looping}',
      );
      debugPrint('[P6_PATH] Preview first frame visible');

      controller.addListener(() {
        final c = _controller;
        if (c == null) return;
        if (!mounted) return;
        final v = c.value;

        if (v.isInitialized && v.isPlaying && !_loggedFirstPlay) {
          _loggedFirstPlay = true;
          debugPrint('[RUNTIME PLAYER] First frame visible - isWeb=$kIsWeb position=${v.position} duration=${v.duration}');
          if (widget.onFirstPlay != null) {
            widget.onFirstPlay!();
          }
        }

        if (widget.looping) return;
        if (!v.isInitialized) return;
        final d = v.duration;
        if (d == Duration.zero) return;
        if (!v.isPlaying && v.position >= d && !_hasCompleted) {
          _hasCompleted = true;
          debugPrint(
            '[RUNTIME PLAYER] Completed - isWeb=$kIsWeb '
            'position=${v.position} duration=$d',
          );
          widget.onCompleted?.call();
        }
      });

      if (widget.autoplay) {
        await controller.play();
        debugPrint('[RUNTIME PLAYER] autoplay play() requested - isWeb=$kIsWeb');
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _initializing = false;
      });
      final exitTime = DateTime.now();
      final duration = exitTime.difference(enterTime).inMilliseconds;
      debugPrint('[P6_EXIT] AcademiaPlaybackView._init duration=${duration}ms');
    } catch (e) {
      if (!mounted) return;
      debugPrint('[RUNTIME PLAYER] init error=$e url=$url');
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
      final exitTime = DateTime.now();
      final duration = exitTime.difference(enterTime).inMilliseconds;
      debugPrint('[P6_EXIT] AcademiaPlaybackView._init duration=${duration}ms (error)');
    }
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    debugPrint('[P13_DISPOSE] id=$_instanceId');
    if (widget.playbackController?._state == this) {
      widget.playbackController?._state = null;
    }
    _nativeChannel = null;
    _disposeController();
    super.dispose();
  }

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
      
      // Map BoxFit to resize mode, but override with orientation-aware mode for contain
      final resizeMode = widget.fit == BoxFit.cover
          ? 'cover'
          : widget.fit == BoxFit.fill
              ? 'fill'
              : widget.fit == BoxFit.fitWidth
                  ? 'fitWidth'
                  : widget.fit == BoxFit.fitHeight
                      ? 'fitHeight'
                      : optimalResizeMode; // Use orientation-aware mode for contain

      debugPrint('[AcademiaPlaybackView] build AndroidView url=${url.length > 60 ? '${url.substring(0, 60)}...' : url}  autoplay=${widget.autoplay}');
      debugPrint('[P8_BUILD] url=$url native=$_shouldUseNativeAndroid flutter=${!_shouldUseNativeAndroid}');

      return AndroidView(
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
          debugPrint('[P13_PLATFORM_VIEW_CREATED] id=$_instanceId viewId=$viewId url=${url.length > 60 ? '${url.substring(0, 60)}...' : url}');
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
      // Sur le web, éviter les transforms complexes autour du <video> HTML
      // (FittedBox/scale) qui peuvent figer l'image. On laisse la vidéo
      // occuper simplement tout l'espace disponible fourni par le parent.
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
}
```

**Analyse critique :**

**initState() :**
- Appelle `_init()` si `deferInitialization` est false
- `_init()` retourne immédiatement si `_shouldUseNativeAndroid && !isLocalFileUri`
- **PROBLÈME CRITIQUE :** Pour les vidéos locales (`isLocalFileUri = true`), `_init()` utilise Flutter `video_player` au lieu du player natif Android
- Cela contredit `preferFlutterPlayer: false` dans l'éditeur vidéo

**didUpdateWidget() :**
- Si l'URL change et `_shouldUseNativeAndroid && _nativeChannel != null`, appelle `setUrl` sur le player natif
- Sinon, dispose le controller et réinitialise
- **PROBLÈME POTENTIEL :** Si `_nativeChannel` est null (pas encore créé), le player est recréé complètement

**_init() :**
- Ligne 163 : `if (_shouldUseNativeAndroid && !isLocalFileUri)` → retourne immédiatement pour les vidéos distantes
- Ligne 172 : Pour les vidéos locales, utilise Flutter `video_player`
- **PROBLÈME CRITIQUE CONFIRMÉ :** Les vidéos locales sont TOUJOURS lues avec Flutter `video_player`, jamais avec le player natif Android
- Cela explique pourquoi ExoPlayer ne reçoit jamais les URLs locales dans les logs P12

**build() :**
- Ligne 417 : Si `_shouldUseNativeAndroid`, crée une `AndroidView`
- Ligne 443 : `AndroidView` est créée avec les params
- **PROBLÈME CRITIQUE :** Pour les vidéos locales, `_shouldUseNativeAndroid` est true, mais `_init()` n'a pas initialisé le player natif
- L'`AndroidView` est créée mais le player natif n'est pas initialisé

---

## DIAGNOSTIC FINAL

### PROBLÈME IDENTIFIÉ

**Contradiction dans AcademiaPlaybackView._init() :**

1. L'éditeur vidéo appelle `AcademiaPlaybackEngine.view` avec `preferFlutterPlayer: false`
2. `AcademiaPlaybackView` reçoit `preferFlutterPlayer: false`
3. `_shouldUseNativeAndroid` est donc `true`
4. Dans `build()`, une `AndroidView` est créée (ligne 443)
5. **MAIS** dans `_init()` (ligne 163), si `isLocalFileUri` est true, le code retourne immédiatement et n'initialise PAS le player natif
6. Le code continue et utilise Flutter `video_player` pour les vidéos locales (ligne 172)
7. **RÉSULTAT :** L'`AndroidView` est créée mais le player natif n'est jamais initialisé pour les vidéos locales

### CHRONOLOGIE DU BUG

1. Utilisateur sélectionne une vidéo locale
2. `_localVideoPath` est défini avec le chemin de la vidéo brute
3. `AcademiaPlaybackEngine.view` est appelé avec `preferFlutterPlayer: false`
4. `AcademiaPlaybackView.initState()` appelle `_init()`
5. `_init()` détecte `isLocalFileUri = true`
6. `_init()` retourne immédiatement (ligne 163) car `_shouldUseNativeAndroid && !isLocalFileUri` est false
7. `build()` crée une `AndroidView` (ligne 443)
8. L'`AndroidView` essaie de créer un ExoPlayer avec l'URL locale
9. ExoPlayer ne peut pas lire file:// URIs (confirmé par P12)
10. **ÉCRAN NOIR**

### CORRECTION NÉCESSAIRE

Dans `AcademiaPlaybackView._init()`, ligne 163 :

**Code actuel :**
```dart
if (_shouldUseNativeAndroid && !isLocalFileUri) {
  debugPrint('[RUNTIME PLAYER] Using native Android view - url=${url.length > 60 ? url.substring(0, 60) : url}');
  setState(() {
    _initializing = false;
    _error = null;
  });
  return;
}
```

**Correction :**
```dart
if (_shouldUseNativeAndroid) {
  debugPrint('[RUNTIME PLAYER] Using native Android view - url=${url.length > 60 ? url.substring(0, 60) : url}');
  setState(() {
    _initializing = false;
    _error = null;
  });
  return;
}
```

**Explication :** Supprimer la condition `!isLocalFileUri` pour que le player natif soit utilisé pour les vidéos locales aussi.

Cependant, cela ne résoudra pas le problème ExoPlayer file:// (confirmé par P12). Il faudra soit :
1. Corriger ExoPlayer pour lire file:// URIs
2. Ou utiliser Flutter `video_player` pour les vidéos locales (mais dans ce cas, ne pas créer d'`AndroidView`)

---

**Statut :** ✅ DIAGNOSTIC TERMINÉ - Problème identifié : Contradiction entre `_init()` et `build()` pour les vidéos locales
