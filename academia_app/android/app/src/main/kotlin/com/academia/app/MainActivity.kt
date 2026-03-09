package com.academia.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import me.leolin.shortcutbadger.ShortcutBadger

class MainActivity : FlutterActivity() {

    private val BADGE_CHANNEL = "com.academia.app/badge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
