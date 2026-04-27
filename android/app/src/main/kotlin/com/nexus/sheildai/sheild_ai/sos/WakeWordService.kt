package com.nexus.sheildai.sheild_ai.sos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * WakeWordService — SUPERSEDED STUB. NOT CURRENTLY ACTIVE.
 *
 * This service is registered in AndroidManifest.xml but is NOT started
 * anywhere in the current codebase.
 *
 * It has been superseded by [VoiceDetectionService], which implements
 * always-on keyword detection using the Vosk offline ASR engine.
 * [VoiceDetectionService] handles all voice trigger responsibilities.
 *
 * This file is kept to avoid breaking the manifest registration while
 * [VoiceDetectionService] is the active implementation. If voice detection
 * is ever redesigned, this stub may be repurposed or removed.
 *
 * foregroundServiceType: microphone
 * (declared in AndroidManifest.xml)
 */
class WakeWordService : Service() {

    companion object {
        const val CHANNEL_ID = "wake_word_service_channel"
        const val NOTIFICATION_ID = 1002
        const val ACTION_START_LISTENING = "ACTION_START_LISTENING"
        const val ACTION_STOP_LISTENING = "ACTION_STOP_LISTENING"

        fun startListening(context: Context) {
            val intent = Intent(context, WakeWordService::class.java).apply {
                action = ACTION_START_LISTENING
            }
            context.startForegroundService(intent)
        }

        fun stopListening(context: Context) {
            val intent = Intent(context, WakeWordService::class.java).apply {
                action = ACTION_STOP_LISTENING
            }
            context.startService(intent)
        }
    }

    private val notificationManager by lazy {
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_LISTENING -> {
                startForeground(NOTIFICATION_ID, buildNotification())
                startWakeWordDetection()
            }
            ACTION_STOP_LISTENING -> {
                stopWakeWordDetection()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopWakeWordDetection()
    }

    // ─── Private Helpers ────────────────────────────────────────────────────

    private fun startWakeWordDetection() {
        // TODO: Phase 2 — integrate speech recognition / wake word engine
    }

    private fun stopWakeWordDetection() {
        // TODO: Phase 2 — release audio resources
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🛡️ SHEild AI — Listening")
            .setContentText("Voice trigger active. Say \"help\" or \"SOS\" to send alert.")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Wake Word Listener",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps microphone active for hands-free SOS trigger"
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(channel)
    }
}
