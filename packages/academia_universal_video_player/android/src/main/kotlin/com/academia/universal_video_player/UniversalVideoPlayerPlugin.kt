package com.academia.universal_video_player

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.video.VideoRendererEventListener
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.ui.PlayerView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class UniversalVideoPlayerPlugin : FlutterPlugin {
  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    binding.platformViewRegistry.registerViewFactory(
      "academia_universal_video_player",
      UniversalVideoPlayerFactory(binding.binaryMessenger)
    )
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    // no-op
  }
}

private class UniversalVideoPlayerFactory(
  private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    val params = args as? Map<*, *>
    val url = (params?.get("url") as? String)?.trim().orEmpty()
    return UniversalVideoPlayerView(context, url)
  }
}

private class UniversalVideoPlayerView(
  context: Context,
  url: String
) : PlatformView {

  private val root: FrameLayout = FrameLayout(context)
  private val playerView: PlayerView = PlayerView(context)
  private val player: ExoPlayer?

  init {
    root.addView(
      playerView,
      FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT,
        FrameLayout.LayoutParams.MATCH_PARENT
      )
    )

    if (url.isNotEmpty()) {
      val renderersFactory = object : DefaultRenderersFactory(context) {
        override fun buildVideoRenderers(
          context: Context,
          extensionRendererMode: Int,
          mediaCodecSelector: MediaCodecSelector,
          enableDecoderFallback: Boolean,
          eventHandler: Handler,
          eventListener: VideoRendererEventListener,
          allowedVideoJoiningTimeMs: Long,
          out: ArrayList<Renderer>
        ) {
          val googleSelector = MediaCodecSelector { mimeType: String,
            requiresSecureDecoder: Boolean,
            requiresTunnelingDecoder: Boolean ->
            val all = MediaCodecSelector.DEFAULT.getDecoderInfos(
              mimeType,
              requiresSecureDecoder,
              requiresTunnelingDecoder
            )
            if (mimeType == MimeTypes.VIDEO_H264) {
              val google = all.filter { info: MediaCodecInfo ->
                info.name.contains("OMX.google.h264", ignoreCase = true)
              }
              return@MediaCodecSelector if (google.isNotEmpty()) google else all
            }
            all
          }

          super.buildVideoRenderers(
            context,
            extensionRendererMode,
            googleSelector,
            true,
            eventHandler,
            eventListener,
            allowedVideoJoiningTimeMs,
            out
          )
        }
      }

      player = ExoPlayer.Builder(context, renderersFactory)
        .build()
      playerView.useController = false
      playerView.player = player

      val mediaItem = MediaItem.fromUri(url)
      player.setMediaItem(mediaItem)
      player.prepare()
      player.playWhenReady = true
    } else {
      player = null
    }
  }

  override fun getView(): View = root

  override fun dispose() {
    playerView.player = null
    player?.release()
  }
}
