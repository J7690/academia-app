package com.academia.nexiomgroup.app

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import me.leolin.shortcutbadger.ShortcutBadger

/**
 * Native Firebase Messaging Service that updates the app icon badge count
 * when a push notification arrives — even when the app is closed/killed.
 * This is how WhatsApp shows the red "1" badge on its icon.
 */
class AcademiaFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        const val PREFS_NAME = "academia_badge_prefs"
        const val KEY_BADGE_COUNT = "badge_count"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // Increment badge count
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val currentCount = prefs.getInt(KEY_BADGE_COUNT, 0)
        val newCount = currentCount + 1
        prefs.edit().putInt(KEY_BADGE_COUNT, newCount).apply()

        // Update app icon badge using ShortcutBadger
        try {
            ShortcutBadger.applyCount(applicationContext, newCount)
        } catch (_: Exception) {}
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }
}
