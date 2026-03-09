package com.academia.app

import android.content.Context
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class AcademiaAndroidVideoView(
    context: Context,
    id: Int,
    creationParams: Map<String, Any>?,
    messenger: BinaryMessenger
) : PlatformView {

    private val playerView: PlayerView = PlayerView(context)
    private val player: ExoPlayer
    private val methodChannel: MethodChannel

    init {
        val url = (creationParams?.get("url") as? String).orEmpty()

        val autoplay = (creationParams?.get("autoplay") as? Boolean) ?: true
        val loop = (creationParams?.get("loop") as? Boolean) ?: true
        val muted = (creationParams?.get("muted") as? Boolean) ?: true
        val showControls = (creationParams?.get("showControls") as? Boolean) ?: false
        val resizeMode = (creationParams?.get("resizeMode") as? String) ?: "cover"

        // Custom codec selector: blacklist unstable hardware codecs (e.g. MediaTek)
        // and prefer remaining decoders (typically software ones like OMX.google.*).
        val safeCodecSelector = MediaCodecSelector { mimeType, requiresSecureDecoder, requiresTunnelingDecoder ->
            val allDecoders: MutableList<MediaCodecInfo> = MediaCodecUtil.getDecoderInfos(
                mimeType,
                requiresSecureDecoder,
                requiresTunnelingDecoder
            )

            // Filter out known problematic hardware codecs (MediaTek, etc.).
            val filtered = allDecoders.filter { info ->
                val name = info.name.lowercase()
                val isMediaTek = name.startsWith("omx.mtk.") || name.contains("mtk")
                val isProblematicC2 = name.startsWith("c2.mtk") || name == "c2.android.avc.decoder" || name == "c2.android.hevc.decoder"
                // You can extend this blacklist if needed for other vendors.
                !isMediaTek && !isProblematicC2
            }

            if (filtered.isNotEmpty()) {
                filtered
            } else {
                val google = allDecoders.filter { it.name.lowercase().startsWith("omx.google") }
                if (google.isNotEmpty()) {
                    google
                } else {
                    // As a fallback, return the original list to avoid hard failure
                    allDecoders
                }
            }
        }

        val renderersFactory = DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)
            .setMediaCodecSelector(safeCodecSelector)

        player = ExoPlayer.Builder(context)
            .setRenderersFactory(renderersFactory)
            .build()

        // Configure playback behaviour
        player.repeatMode = if (loop) Player.REPEAT_MODE_ALL else Player.REPEAT_MODE_OFF
        player.volume = if (muted) 0f else 1f
        player.playWhenReady = autoplay

        // Configure PlayerView appearance
        playerView.useController = showControls
        playerView.resizeMode = when (resizeMode) {
            "cover" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
            "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
            "fitWidth" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH
            "fitHeight" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT
            else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
        }

        playerView.player = player

        if (url.isNotEmpty()) {
            val mediaItem = MediaItem.fromUri(url)
            player.setMediaItem(mediaItem)
            player.prepare()
        }

        // MethodChannel for Flutter ↔ native player control
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
                "isPlaying" -> {
                    result.success(player.isPlaying)
                }
                "getPosition" -> {
                    result.success(player.currentPosition)
                }
                "getDuration" -> {
                    result.success(player.duration)
                }
                "setVolume" -> {
                    val vol = (call.argument<Double>("volume") ?: 1.0).toFloat()
                    player.volume = vol
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = playerView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
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
