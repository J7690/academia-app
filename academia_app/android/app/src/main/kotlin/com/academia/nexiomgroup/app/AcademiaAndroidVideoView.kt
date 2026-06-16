package com.academia.nexiomgroup.app

import android.content.Context
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
            player.setMediaItem(MediaItem.fromUri(url))
            player.prepare()
        }

        methodChannel = MethodChannel(messenger, "academia_android_video_$id")
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    player.playWhenReady = true
                    result.success(true)
                }
                "pause" -> {
                    player.playWhenReady = false
                    result.success(true)
                }
                "toggle" -> {
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
                    if (newUrl.isNotEmpty() && newUrl != currentUrl) {
                        currentUrl = newUrl
                        player.setMediaItem(MediaItem.fromUri(newUrl))
                        player.playWhenReady = play
                        player.prepare()
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
