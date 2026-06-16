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
