package com.nexus.sheildai.sheild_ai.sos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.nexus.sheildai.sheild_ai.MainActivity

/**
 * SOSPersistentNotification — A single, persistent lock-screen notification
 * that reflects the real-time state of the SOS lifecycle.
 *
 * Design goals:
 *  ① One notification ID (9001) — avoids notification clutter during an emergency.
 *  ② IMPORTANCE_HIGH channel so it survives Doze and is visible on the lock screen.
 *  ③ VISIBILITY_PUBLIC — shown on lock screen without requiring unlock.
 *  ④ Updated from [SOSManager.transitionTo] so it always matches native state.
 *  ⑤ Cleared automatically when state returns to IDLE.
 *
 * Usage:
 *   SOSPersistentNotification.update(context, SOSState.TRIGGERED, sessionStartMs)
 *   SOSPersistentNotification.clear(context)
 */
object SOSPersistentNotification {

    private const val CHANNEL_ID      = "sos_alert_persistent"
    private const val CHANNEL_NAME    = "SOS Alert"
    private const val NOTIFICATION_ID = 9001

    private val mainHandler = Handler(Looper.getMainLooper())

    // ─── Public API ───────────────────────────────────────────────────────────

    /**
     * Posts or updates the persistent SOS notification.
     *
     * Thread-safe: switches to the main thread automatically.
     *
     * @param context       Application context.
     * @param state         Current SOS state — drives title/text/color.
     * @param sessionStartMs Epoch ms when the session began (for elapsed time label).
     *                       Pass 0 for states before recording starts.
     */
    fun update(context: Context, state: SOSState, sessionStartMs: Long = 0L) {
        mainHandler.post {
            ensureChannel(context)
            val nm = context.getSystemService(NotificationManager::class.java)
            // Don't show a notification for idle state
            if (state == SOSState.IDLE) {
                nm.cancel(NOTIFICATION_ID)
                return@post
            }
            nm.notify(NOTIFICATION_ID, buildNotification(context, state, sessionStartMs))
        }
    }

    /** Removes the persistent notification immediately (called on session end). */
    fun clear(context: Context) {
        mainHandler.post {
            context.getSystemService(NotificationManager::class.java)
                .cancel(NOTIFICATION_ID)
        }
    }

    // ─── Notification builder ─────────────────────────────────────────────────

    private fun buildNotification(
        context: Context,
        state: SOSState,
        sessionStartMs: Long,
    ): Notification {
        val tapIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val stopIntent = PendingIntent.getBroadcast(
            context, 1,
            Intent("com.nexus.sheildai.sos.ACTION_STOP_SOS"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val (title, body, icon) = notificationContent(state, sessionStartMs)

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(icon)
            .setContentIntent(tapIntent)
            .setOngoing(true)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setColor(stateColor(state))

        // Show "I'm Safe" stop action during active recording phases
        if (state == SOSState.RECORDING_AUDIO || state == SOSState.RECORDING_VIDEO) {
            builder.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "I'm Safe — Stop SOS",
                stopIntent,
            )
        }

        return builder.build()
    }

    /** Returns (title, body, smallIconRes) for each state. */
    private fun notificationContent(
        state: SOSState,
        sessionStartMs: Long,
    ): Triple<String, String, Int> {
        val elapsed = elapsedLabel(sessionStartMs)
        return when (state) {
            SOSState.TRIGGERED ->
                Triple("🚨 SOS Triggered", "Preparing emergency alert…", android.R.drawable.ic_dialog_alert)
            SOSState.BUFFER ->
                Triple("⏳ SOS Preparing", "Tap to open and cancel$elapsed", android.R.drawable.ic_dialog_alert)
            SOSState.RECORDING_AUDIO ->
                Triple("🎙 SOS — Recording Audio", "Evidence recording active$elapsed", android.R.drawable.ic_btn_speak_now)
            SOSState.RECORDING_VIDEO ->
                Triple("📹 SOS — Recording Video", "Evidence recording active$elapsed", android.R.drawable.ic_menu_camera)
            SOSState.STOPPED ->
                Triple("✅ SOS Ended", "Session finished. Tap to open app.", android.R.drawable.ic_menu_info_details)
            SOSState.COOLDOWN ->
                Triple("🔒 SOS Cooldown", "Available again shortly$elapsed", android.R.drawable.ic_lock_idle_alarm)
            else ->
                Triple("🔴 SOS Active", "Emergency alert in progress$elapsed", android.R.drawable.ic_dialog_alert)
        }
    }

    private fun stateColor(state: SOSState): Int = when (state) {
        SOSState.TRIGGERED, SOSState.BUFFER        -> 0xFFDC2626.toInt() // red
        SOSState.RECORDING_AUDIO                   -> 0xFF7C3AED.toInt() // purple
        SOSState.RECORDING_VIDEO                   -> 0xFF2563EB.toInt() // blue
        SOSState.STOPPED                           -> 0xFF16A34A.toInt() // green
        SOSState.COOLDOWN                          -> 0xFF6B7280.toInt() // grey
        else                                       -> 0xFFDC2626.toInt()
    }

    private fun elapsedLabel(sessionStartMs: Long): String {
        if (sessionStartMs == 0L) return ""
        val secs = (System.currentTimeMillis() - sessionStartMs) / 1000L
        val m = secs / 60
        val s = secs % 60
        return if (m > 0) " — ${m}m ${s}s" else " — ${s}s"
    }

    // ─── Channel ──────────────────────────────────────────────────────────────

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Real-time SOS session status — shown on lock screen during emergencies"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(true)
            enableVibration(false)
            enableLights(true)
            lightColor = 0xFFDC2626.toInt()
            setBypassDnd(true) // emergency channel — bypasses Do Not Disturb
        }
        nm.createNotificationChannel(channel)
    }
}
