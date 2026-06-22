# AUDIT P7 – VÉRIFICATION DU PLAYER NATIF ANDROID

**Date :** 19 Juin 2026  
**Objectif :** Audit complet de l'implémentation native Android du lecteur vidéo pour identifier la cause de l'écran noir lors de la prévisualisation locale

---

## 1. CODE SOURCE COMPLET DES FICHIERS NATIFS

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\android\app\src\main\kotlin\com\academia\nexiomgroup\app\MainActivity.kt ===

```kotlin
package com.academia.nexiomgroup.app

import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import me.leolin.shortcutbadger.ShortcutBadger

/**
 * Global registry of active ExoPlayer instances so the Activity lifecycle
 * can pause them all when the app goes to background.
 */
object ExoPlayerRegistry {
    private val players = mutableSetOf<ExoPlayer>()

    @Synchronized
    fun register(player: ExoPlayer) { players.add(player) }

    @Synchronized
    fun unregister(player: ExoPlayer) { players.remove(player) }

    @Synchronized
    fun pauseAll() {
        for (p in players) {
            if (p.isPlaying) {
                p.playWhenReady = false
            }
        }
        Log.d("ExoPlayerRegistry", "Paused ${players.size} players (background)")
    }
}

class MainActivity : FlutterActivity() {

    private val BADGE_CHANNEL = "com.academia.app/badge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Pause all ExoPlayer instances when Activity goes to background
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onPause(owner: LifecycleOwner) {
                ExoPlayerRegistry.pauseAll()
            }
        })

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "academia_android_video",
                AcademiaAndroidVideoViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BADGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateBadge" -> {
                        val count = call.argument<Int>("count") ?: 0
                        try {
                            // Update both ShortcutBadger and SharedPreferences
                            val prefs = getSharedPreferences(
                                AcademiaFirebaseMessagingService.PREFS_NAME, MODE_PRIVATE)
                            prefs.edit().putInt(
                                AcademiaFirebaseMessagingService.KEY_BADGE_COUNT, count).apply()
                            if (count > 0) {
                                ShortcutBadger.applyCount(applicationContext, count)
                            } else {
                                ShortcutBadger.removeCount(applicationContext)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "removeBadge" -> {
                        try {
                            val prefs = getSharedPreferences(
                                AcademiaFirebaseMessagingService.PREFS_NAME, MODE_PRIVATE)
                            prefs.edit().putInt(
                                AcademiaFirebaseMessagingService.KEY_BADGE_COUNT, 0).apply()
                            ShortcutBadger.removeCount(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\android\app\src\main\kotlin\com\academia\nexiomgroup\app\AcademiaAndroidVideoView.kt ===

```kotlin
package com.academia.nexiomgroup.app

import android.content.Context
import android.util.Log
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File

/**
 * Shared disk cache for all ExoPlayer instances — 100 MB LRU.
 */
object VideoCacheManager {
    private var cache: SimpleCache? = null
    private var databaseProvider: StandaloneDatabaseProvider? = null

    private const val MAX_CACHE_BYTES: Long = 200L * 1024 * 1024 // 200 MB

    @Synchronized
    fun getCache(context: Context): SimpleCache {
        if (cache == null) {
            val cacheDir = File(context.cacheDir, "exo_video_cache")
            if (!cacheDir.exists()) cacheDir.mkdirs()
            databaseProvider = StandaloneDatabaseProvider(context)
            cache = SimpleCache(
                cacheDir,
                LeastRecentlyUsedCacheEvictor(MAX_CACHE_BYTES),
                databaseProvider!!
            )
        }
        return cache!!
    }

    fun buildCacheDataSourceFactory(context: Context): DataSource.Factory {
        val httpFactory = DefaultHttpDataSource.Factory()
            .setConnectTimeoutMs(5_000)
            .setReadTimeoutMs(5_000)
            .setAllowCrossProtocolRedirects(true)

        return CacheDataSource.Factory()
            .setCache(getCache(context))
            .setUpstreamDataSourceFactory(httpFactory)
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
    }

    /** Safe codec selector: skip MediaTek hardware decoders that cause issues. */
    val safeCodecSelector = MediaCodecSelector { mimeType, requiresSecureDecoder, requiresTunnelingDecoder ->
        val allDecoders: MutableList<MediaCodecInfo> = MediaCodecUtil.getDecoderInfos(
            mimeType, requiresSecureDecoder, requiresTunnelingDecoder
        )
        val filtered = allDecoders.filter { info ->
            val name = info.name.lowercase()
            val isMediaTek = name.startsWith("omx.mtk.") || name.contains("mtk")
            val isProblematicC2 = name.startsWith("c2.mtk") || name == "c2.android.avc.decoder" || name == "c2.android.hevc.decoder"
            !isMediaTek && !isProblematicC2
        }
        if (filtered.isNotEmpty()) filtered
        else {
            val google = allDecoders.filter { it.name.lowercase().startsWith("omx.google") }
            if (google.isNotEmpty()) google else allDecoders
        }
    }
}

/**
 * Native video PlatformView that supports instant URL switching via MethodChannel.
 * Instead of destroying and recreating ExoPlayer on each swipe, the same view
 * receives "setUrl" commands to switch content with zero allocation overhead.
 */
class AcademiaAndroidVideoView(
    context: Context,
    id: Int,
    creationParams: Map<String, Any>?,
    messenger: BinaryMessenger
) : PlatformView {

    private val playerView: PlayerView = PlayerView(context)
    private val player: ExoPlayer
    private val methodChannel: MethodChannel
    private var currentUrl: String = ""

    init {
        val url = (creationParams?.get("url") as? String).orEmpty()
        val autoplay = (creationParams?.get("autoplay") as? Boolean) ?: true
        val loop = (creationParams?.get("loop") as? Boolean) ?: true
        val muted = (creationParams?.get("muted") as? Boolean) ?: false
        val showControls = (creationParams?.get("showControls") as? Boolean) ?: false
        val resizeMode = (creationParams?.get("resizeMode") as? String) ?: "cover"

        Log.d("[RUNTIME NATIVE]", "AcademiaAndroidVideoView init - url=${url.take(60)} autoplay=$autoplay loop=$loop muted=$muted")

        val renderersFactory = DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)
            .setMediaCodecSelector(VideoCacheManager.safeCodecSelector)

        val cacheDataSourceFactory = VideoCacheManager.buildCacheDataSourceFactory(context)
        val mediaSourceFactory = DefaultMediaSourceFactory(cacheDataSourceFactory)

        // Aggressive buffer config: start playback with minimal data (TikTok-style)
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                500,    // minBufferMs — keep only 0.5s minimum
                30_000, // maxBufferMs — buffer up to 30s ahead
                300,    // bufferForPlaybackMs — start playing after 300ms of data
                500     // bufferForPlaybackAfterRebufferMs — resume after 500ms
            )
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()

        Log.d("[RUNTIME NATIVE]", "Creating ExoPlayer")
        player = ExoPlayer.Builder(context)
            .setRenderersFactory(renderersFactory)
            .setMediaSourceFactory(mediaSourceFactory)
            .setLoadControl(loadControl)
            .build()

        player.repeatMode = if (loop) Player.REPEAT_MODE_ALL else Player.REPEAT_MODE_OFF
        player.volume = if (muted) 0f else 1f
        player.playWhenReady = autoplay

        playerView.useController = showControls
        playerView.resizeMode = when (resizeMode) {
            "cover" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
            "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
            "fitWidth" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH
            "fitHeight" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT
            else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
        }
        playerView.player = player

        // Register in global registry for lifecycle management
        ExoPlayerRegistry.register(player)

        if (url.isNotEmpty()) {
            currentUrl = url
            Log.d("[RUNTIME NATIVE]", "Calling setMediaItem - url=${url.take(60)}")
            player.setMediaItem(MediaItem.fromUri(url))
            Log.d("[RUNTIME NATIVE]", "Calling prepare() - START")
            val stopwatch = android.os.SystemClock.elapsedRealtime()
            player.prepare()
            val elapsed = android.os.SystemClock.elapsedRealtime() - stopwatch
            Log.d("[RUNTIME NATIVE]", "Calling prepare() - END - duration=${elapsed}ms")
        }

        methodChannel = MethodChannel(messenger, "academia_android_video_$id")
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    Log.d("[RUNTIME NATIVE]", "MethodChannel: play")
                    player.playWhenReady = true
                    result.success(true)
                }
                "pause" -> {
                    Log.d("[RUNTIME NATIVE]", "MethodChannel: pause")
                    player.playWhenReady = false
                    result.success(true)
                }
                "toggle" -> {
                    Log.d("[RUNTIME NATIVE]", "MethodChannel: toggle")
                    player.playWhenReady = !player.playWhenReady
                    result.success(player.playWhenReady)
                }
                "isPlaying" -> result.success(player.isPlaying)
                "getPosition" -> result.success(player.currentPosition)
                "getDuration" -> result.success(player.duration)
                "setVolume" -> {
                    val vol = (call.argument<Double>("volume") ?: 1.0).toFloat()
                    player.volume = vol
                    result.success(true)
                }
                "setUrl" -> {
                    val newUrl = (call.argument<String>("url")).orEmpty()
                    val play = call.argument<Boolean>("autoplay") ?: true
                    Log.d("[RUNTIME NATIVE]", "MethodChannel: setUrl - url=${newUrl.take(60)} autoplay=$play")
                    if (newUrl.isNotEmpty() && newUrl != currentUrl) {
                        currentUrl = newUrl
                        player.setMediaItem(MediaItem.fromUri(newUrl))
                        player.playWhenReady = play
                        Log.d("[RUNTIME NATIVE]", "Calling prepare() after setUrl - START")
                        val stopwatch = android.os.SystemClock.elapsedRealtime()
                        player.prepare()
                        val elapsed = android.os.SystemClock.elapsedRealtime() - stopwatch
                        Log.d("[RUNTIME NATIVE]", "Calling prepare() after setUrl - END - duration=${elapsed}ms")
                    } else if (newUrl == currentUrl) {
                        // Same URL — just control playback
                        player.playWhenReady = play
                        if (!play) {
                            player.seekTo(0)
                        }
                    }
                    result.success(true)
                }
                "seekTo" -> {
                    val posMs = (call.argument<Number>("position"))?.toLong() ?: 0L
                    player.seekTo(posMs)
                    result.success(true)
                }
                "stop" -> {
                    Log.d("[RUNTIME NATIVE]", "MethodChannel: stop")
                    player.stop()
                    currentUrl = ""
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = playerView

    override fun dispose() {
        Log.d("[RUNTIME NATIVE]", "AcademiaAndroidVideoView dispose - releasing ExoPlayer")
        methodChannel.setMethodCallHandler(null)
        ExoPlayerRegistry.unregister(player)
        playerView.player = null
        player.release()
    }
}

class AcademiaAndroidVideoViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<String, Any>
        return AcademiaAndroidVideoView(context, viewId, params, messenger)
    }
}
```

=== FIN FICHIER ===

---

## 2. CARTOGRAPHIE COMPLÈTE FLUTTER → ANDROIDVIEW → EXOPLAYER

### Flux Flutter vers Android

```
Flutter (academia_playback_view.dart)
    ↓
AndroidView(viewType: 'academia_android_video')
    ↓
MainActivity.configureFlutterEngine()
    ↓
registerViewFactory("academia_android_video", AcademiaAndroidVideoViewFactory)
    ↓
AcademiaAndroidVideoViewFactory.create()
    ↓
AcademiaAndroidVideoView(context, viewId, params, messenger)
    ↓
ExoPlayer.Builder(context).build()
    ↓
PlayerView(context) + playerView.player = player
    ↓
MethodChannel("academia_android_video_$id")
```

### Flux de contrôle

```
Flutter
    ↓
AcademiaPlaybackController.toggle/play/pause
    ↓
MethodChannel.invokeMethod("toggle"/"play"/"pause")
    ↓
AcademiaAndroidVideoView.methodChannel handler
    ↓
player.playWhenReady = true/false
```

### Flux de changement d'URL

```
Flutter (didUpdateWidget)
    ↓
MethodChannel.invokeMethod("setUrl", {url, autoplay})
    ↓
AcademiaAndroidVideoView.methodChannel handler
    ↓
player.setMediaItem(MediaItem.fromUri(newUrl))
    ↓
player.prepare()
```

---

## 3. SUPPORT DES URI FILE://

### Analyse du code natif

Dans `AcademiaAndroidVideoView.init()` :

```kotlin
if (url.isNotEmpty()) {
    currentUrl = url
    player.setMediaItem(MediaItem.fromUri(url))
    player.prepare()
}
```

Dans `setUrl()` :

```kotlin
if (newUrl.isNotEmpty() && newUrl != currentUrl) {
    currentUrl = newUrl
    player.setMediaItem(MediaItem.fromUri(newUrl))
    player.prepare()
}
```

### Conclusion sur file://

**ExoPlayer supporte nativement les URI file:// via MediaItem.fromUri().**

Cependant, le code natif utilise `DefaultMediaSourceFactory` avec `CacheDataSource` :

```kotlin
val cacheDataSourceFactory = VideoCacheManager.buildCacheDataSourceFactory(context)
val mediaSourceFactory = DefaultMediaSourceFactory(cacheDataSourceFactory)
```

`CacheDataSource` est optimisé pour HTTP(S). Pour les fichiers locaux, ExoPlayer utilise normalement `FileDataSource` ou `ContentDataSource`.

**PROBLÈME POTENTIEL :** Le `DefaultMediaSourceFactory` avec `CacheDataSource` peut ne pas gérer correctement les URI file://. ExoPlayer devrait normalement détecter automatiquement le type d'URI et utiliser le bon DataSource, mais la configuration personnalisée avec CacheDataSource pourrait interférer.

---

## 4. SUPPORT DES URI CONTENT://

Même analyse que file://. ExoPlayer supporte content:// via `ContentDataSource`, mais l'utilisation de `CacheDataSource` dans `DefaultMediaSourceFactory` pourrait poser problème.

---

## 5. ANALYSE DES RISQUES D'ÉCRAN NOIR

### RISQUE N°1 : INHÉRENT À L'ARCHITECTURE FLUTTER (CONFIRMÉ)

**Dans academia_playback_view.dart :**

```dart
// Dans _init() :
if (_shouldUseNativeAndroid && !isLocalFileUri) {
  // Utilise PlatformView native
  return;
}

// Dans build() :
if (_shouldUseNativeAndroid) {
  return AndroidView(...);  // TOUJOURS retourne AndroidView
}
```

**PROBLÈME :**
- Pour les fichiers locaux (file://), `_init()` crée un `VideoPlayerController` Flutter
- `build()` retourne quand même un `AndroidView` natif
- Le `VideoPlayerController` Flutter n'est jamais rendu (pas de VideoPlayer widget)
- L'`AndroidView` natif reçoit l'URL locale mais peut ne pas la lire correctement
- **Résultat : écran noir**

### RISQUE N°2 : CONFIGURATION DATASOURCE POUR FICHIERS LOCAUX

Le code natif utilise `CacheDataSource` configuré pour HTTP :

```kotlin
fun buildCacheDataSourceFactory(context: Context): DataSource.Factory {
    val httpFactory = DefaultHttpDataSource.Factory()
        .setConnectTimeoutMs(5_000)
        .setReadTimeoutMs(5_000)
        .setAllowCrossProtocolRedirects(true)

    return CacheDataSource.Factory()
        .setCache(getCache(context))
        .setUpstreamDataSourceFactory(httpFactory)
        .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
}
```

**PROBLÈME :**
- `DefaultHttpDataSource` ne supporte PAS file://
- ExoPlayer devrait normalement détecter le schéma URI et utiliser le bon DataSource
- Mais avec une `MediaSourceFactory` personnalisée, ce mécanisme peut être perturbé
- **Résultat potentiel : erreur silencieuse ou échec de chargement**

### RISQUE N°3 : PERMISSIONS FICHIERS

Les fichiers locaux dans `getTemporaryDirectory()` sont accessibles par l'application, mais il n'y a pas de vérification explicite des permissions dans le code natif.

### RISQUE N°4 : SURFACE NON ATTACHÉE

Le code ne vérifie pas si la `PlayerView` est correctement attachée à la surface. ExoPlayer gère cela normalement automatiquement, mais dans un contexte PlatformView, il pourrait y avoir des problèmes de timing.

---

## 6. ANALYSE DES RISQUES DE FUITE AUDIO

### MÉCANISME DE GESTION LIFECYCLE

**ExoPlayerRegistry :**

```kotlin
object ExoPlayerRegistry {
    private val players = mutableSetOf<ExoPlayer>()

    @Synchronized
    fun register(player: ExoPlayer) { players.add(player) }

    @Synchronized
    fun unregister(player: ExoPlayer) { players.remove(player) }

    @Synchronized
    fun pauseAll() {
        for (p in players) {
            if (p.isPlaying) {
                p.playWhenReady = false
            }
        }
    }
}
```

**Dans MainActivity :**

```kotlin
lifecycle.addObserver(object : DefaultLifecycleObserver {
    override fun onPause(owner: LifecycleOwner) {
        ExoPlayerRegistry.pauseAll()
    }
})
```

**Dans dispose() :**

```kotlin
override fun dispose() {
    methodChannel.setMethodCallHandler(null)
    ExoPlayerRegistry.unregister(player)
    playerView.player = null
    player.release()
}
```

### ANALYSE

**Points positifs :**
- `dispose()` appelle `player.release()` - correct
- `ExoPlayerRegistry.unregister()` est appelé - correct
- Lifecycle observer pause tous les players en background - correct

**Risque potentiel :**
- Si le widget Flutter est détruit sans appeler `dispose()` (cas rare mais possible), le player peut continuer de jouer
- Cependant, l'observer lifecycle devrait gérer cela en pause

**Conclusion :** Le mécanisme de gestion audio semble correct. Les fuites audio sont peu probables.

---

## 7. CAUSE LA PLUS PROBABLE DU COMPORTEMENT OBSERVÉ

### DIAGNOSTIC PRINCIPAL

**L'incohérence entre `_init()` et `build()` dans `academia_playback_view.dart` est la cause principale.**

### SCÉNARIO DÉTAILLÉ

1. **Sélection vidéo locale**
   - `_localVideoPath = "/data/user/0/.../cache/video.mp4"`
   - `effectivePreviewUrl = "file:///data/user/0/.../cache/video.mp4"`

2. **Premier appel à `_init()`**
   - `isLocalFileUri = true`
   - `_shouldUseNativeAndroid && !isLocalFileUri` = `false`
   - **Code entre dans la branche Flutter video_player**
   - Crée `VideoPlayerController.file(File.fromUri(parsed))`
   - Appelle `controller.initialize()` - **BLOQUANT**
   - Écran noir pendant l'initialisation

3. **Premier appel à `build()`**
   - `_shouldUseNativeAndroid = true`
   - **Retourne `AndroidView` native**
   - L'URL locale est passée à `AcademiaAndroidVideoView`
   - ExoPlayer reçoit `file://` mais peut échouer à cause du DataSource

4. **Résultat**
   - Le `VideoPlayerController` Flutter est initialisé mais jamais rendu
   - L'`AndroidView` native est rendu mais ne peut pas lire le fichier local
   - **Écran noir permanent**

5. **Après compression/watermark**
   - `_localVideoPath` change vers le fichier watermarké
   - `didUpdateWidget` détecte le changement d'URL
   - `_init()` est appelé à nouveau
   - Même scénario se répète

6. **Après upload**
   - `_uploadedUrl = "https://..."` (URL distante)
   - `isLocalFileUri = false`
   - `_shouldUseNativeAndroid && !isLocalFileUri` = `true`
   - **Code retourne immédiatement dans `_init()`** (pas de VideoPlayerController)
   - `build()` retourne `AndroidView` native
   - ExoPlayer reçoit une URL HTTP(S) - **FONCTIONNE**
   - **Vidéo visible**

### POURQUOI L'AUDIO CONTINUE PARFOIS

Si un ExoPlayer précédent n'est pas correctement libéré (cas edge), il peut continuer de jouer en arrière-plan. Mais le mécanisme de `dispose()` semble correct.

---

## 8. CORRECTIF EXACT RECOMMANDÉ

### SOLUTION 1 : UTILISER TOUJOURS LE PLAYER NATIF (RECOMMANDÉ)

**Avant :**

```dart
// Dans academia_playback_view.dart - _init()

if (_shouldUseNativeAndroid && !isLocalFileUri) {
  debugPrint('[RUNTIME PLAYER] Using native Android view - url=${url.length > 60 ? url.substring(0, 60) : url}');
  setState(() {
    _initializing = false;
    _error = null;
  });
  return;
}
```

**Après :**

```dart
// Dans academia_playback_view.dart - _init()

// Utiliser TOUJOURS le player natif sur Android
if (_shouldUseNativeAndroid) {
  debugPrint('[RUNTIME PLAYER] Using native Android view - url=${url.length > 60 ? url.substring(0, 60) : url} isLocalFileUri=$isLocalFileUri');
  setState(() {
    _initializing = false;
    _error = null;
  });
  return;
}
```

**Explication :** Supprimer la condition `!isLocalFileUri` pour permettre au player natif de gérer aussi les fichiers locaux.

### SOLUTION 2 : CORRIGER LE DATASOURCE NATIF (SI SOLUTION 1 INSUFFISANTE)

Si ExoPlayer ne peut toujours pas lire les fichiers locaux après la Solution 1, modifier `AcademiaAndroidVideoView.kt` :

**Avant :**

```kotlin
val cacheDataSourceFactory = VideoCacheManager.buildCacheDataSourceFactory(context)
val mediaSourceFactory = DefaultMediaSourceFactory(cacheDataSourceFactory)
```

**Après :**

```kotlin
val cacheDataSourceFactory = VideoCacheManager.buildCacheDataSourceFactory(context)
val mediaSourceFactory = DefaultMediaSourceFactory(
    // Utiliser un DataSource.Factory qui supporte tous les types d'URI
    DefaultDataSource.Factory(context, cacheDataSourceFactory)
)
```

**Explication :** `DefaultDataSource.Factory` détecte automatiquement le type d'URI (http, file, content, asset) et utilise le bon DataSource.

### SOLUTION 3 : UTILISER TOUJOURS FLUTTER VIDEO_PLAYER (ALTERNATIVE)

Si le player natif pose trop de problèmes, forcer l'utilisation de Flutter video_player :

**Avant :**

```dart
bool get _shouldUseNativeAndroid => _useNativeAndroid && !widget.preferFlutterPlayer;
```

**Après :**

```dart
bool get _shouldUseNativeAndroid => false; // Désactiver le player natif
```

**Inconvénient :** Perte des optimisations natives (codec selector MediaTek, cache, etc.)

---

## 9. ORDRE DE PRIORITÉ DES CORRECTIFS

1. **SOLUTION 1** (modification Flutter) - **FAIBLE RISQUE, HAUT IMPACT**
2. **SOLUTION 2** (modification native) - **SI SOLUTION 1 INSUFFISANTE**
3. **SOLUTION 3** (désactivation native) - **DERNIER RECOURS**

---

## 10. CONCLUSION

L'audit P7 confirme l'hypothèse principale de l'audit P6 : l'incohérence entre `_init()` et `build()` dans `academia_playback_view.dart` est la cause probable de l'écran noir lors de la prévisualisation locale.

Le player natif Android est correctement implémenté mais n'est pas utilisé pour les fichiers locaux à cause de la condition `!isLocalFileUri`. Le correctif recommandé est de supprimer cette condition pour permettre au player natif de gérer tous les types d'URI, y compris file://.
