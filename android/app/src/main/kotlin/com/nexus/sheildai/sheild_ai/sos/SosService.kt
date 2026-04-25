package com.nexus.sheildai.sheild_ai.sos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.nexus.sheildai.sheild_ai.MainActivity

/**
 * SosService — SOS session keepalive foreground service.
 *
 * This service's ONLY responsibility is keeping the process alive during an active
 * SOS session. It holds a foreground notification so Android's Low Memory Killer
 * cannot terminate the process while SOSManager is dispatching SMS or recording.
 *
 * KEY DESIGN DECISION — foregroundServiceType="dataSync" only:
 *   Android 14 (API 34) forbids starting a "microphone" or "camera" type foreground
 *   service from the background. "dataSync" has NO such restriction — it can be started
 *   from background as long as any other foreground service (e.g., VoiceDetectionService)
 *   is already running in the process. This is exactly our case at trigger time.
 *
 * All SOS business logic (SMS, recording, state transitions) lives in [SOSManager].
 * This service has NO side-effects other than the foreground notification lifecycle.
 *
 * Lifecycle:
 *   SOSManager.triggerSOS()  → SosService.startSos()  → ACTION_START_SOS → startForeground()
 *   SOSManager.endSession()  → SosService.stopSos()   → ACTION_STOP_SOS  → stopForeground()
 *   SOSManager.cancelBuffer()→ SosService.stopSos()   (same path)
 *
 * Returns START_NOT_STICKY — the session ends cleanly; no auto-restart desired.
 * (VoiceDetectionService is the always-on service; SosService is session-scoped.)
 */
class SosService : Service() {

    companion object {
        private const val TAG = "SosService"

        const val CHANNEL_ID      = "sos_service_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START_SOS = "com.nexus.sheildai.sos.ACTION_START_SOS"
        const val ACTION_STOP_SOS  = "com.nexus.sheildai.sos.ACTION_STOP_SOS"

        // ─── Static helpers ───────────────────────────────────────────────────

        /**
         * Starts SosService as a foreground keepalive for the current SOS session.
         *
         * Safe to call from background because foregroundServiceType="dataSync" is used
         * in the manifest — not "microphone" or "camera", which are foreground-only on API 34.
         *
         * Prerequisite: at least one other foreground service (VoiceDetectionService) must
         * already be running in the process, satisfying Android 14's "at least one active
         * foreground service" requirement for dataSync background starts.
         */
        fun startSos(context: Context) {
            val intent = Intent(context, SosService::class.java).apply {
                action = ACTION_START_SOS
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.i(TAG, "startSos() — session keepalive requested")
        }

        /**
         * Stops the SosService keepalive and removes the SOS active notification.
         * Called by SOSManager when a session ends (endSession, cancelBuffer, or cooldown start).
         */
        fun stopSos(context: Context) {
            val intent = Intent(context, SosService::class.java).apply {
                action = ACTION_STOP_SOS
            }
            context.startService(intent)
            Log.i(TAG, "stopSos() — session keepalive teardown requested")
        }
    }

    // ─── Instance state ───────────────────────────────────────────────────────

    private val notificationManager by lazy {
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Service lifecycle
    // ═════════════════════════════════════════════════════════════════════════

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "SosService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_SOS -> {
                Log.i(TAG, "ACTION_START_SOS — starting foreground keepalive")
                try {
                    startForeground(NOTIFICATION_ID, buildNotification())
                    Log.i(TAG, "✅ SosService foreground started — process is now LMK-protected")
                } catch (e: SecurityException) {
                    // This should not happen for dataSync type, but guard defensively.
                    Log.e(TAG, "startForeground() blocked unexpectedly: ${e.message}")
                    stopSelf()
                }
            }
            ACTION_STOP_SOS -> {
                Log.i(TAG, "ACTION_STOP_SOS — removing foreground and stopping")
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> {
                Log.w(TAG, "Unknown action '${intent?.action}' — stopping")
                stopSelf()
            }
        }

        // START_NOT_STICKY: session is explicitly scoped — no auto-restart after process death.
        // VoiceDetectionService (START_STICKY) is the always-on anchor; SosService is ephemeral.
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "SosService destroyed")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Notification
    // ═════════════════════════════════════════════════════════════════════════

    private fun buildNotification(): Notification {
        val tapIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🆘 SOS Active")
            .setContentText("Emergency alert is being sent to your contacts.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setSilent(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(tapIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SOS Emergency Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shown during active SOS sessions — keeps process alive for SMS dispatch"
                setShowBadge(true)
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
}
