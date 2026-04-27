package com.nexus.sheildai.sheild_ai.sos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.NotificationCompat
import com.nexus.sheildai.sheild_ai.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * AudioRecordingService — Foreground service for SOS background audio evidence.
 *
 * Responsibilities:
 *  - Starts a persistent foreground notification (so Android cannot kill it)
 *  - Records microphone audio via [MediaRecorder] (AAC/M4A format)
 *  - Saves to MediaStore.Audio.Media (API 29+) or app-external directory (API 26-28)
 *  - Stops automatically after [MAX_RECORDING_DURATION_MS] (5 minutes)
 *  - Holds a PARTIAL_WAKE_LOCK so recording continues when screen is off
 *
 * Start/stop via the static [startRecording] / [stopRecording] helpers.
 * Registered in AndroidManifest with foregroundServiceType="dataSync".
 * dataSync has no Android 14+ per-service microphone-eligibility restriction;
 * MediaRecorder still records because the process holds RECORD_AUDIO at runtime
 * and VoiceDetectionService (microphone FGS) provides the process-level mic exemption.
 *
 * ┌──────────────────────────────────────────────────────────┐
 * │  Thread model: all recording work on Dispatchers.IO     │
 * │  Timer: coroutine delay on SupervisorJob scope          │
 * │  WakeLock: released in onDestroy() — no leaks          │
 * └──────────────────────────────────────────────────────────┘
 */
class AudioRecordingService : Service() {

    // ─── Companion (static API) ───────────────────────────────────────────────

    companion object {

        private const val TAG = "AudioRecordingService"

        // Notification
        private const val CHANNEL_ID    = "sos_audio_recording"
        private const val CHANNEL_NAME  = "SOS Audio Recording"
        private const val NOTIFICATION_ID = 2001

        // Intent actions
        const val ACTION_START = "com.nexus.sheildai.sos.audio.START"
        const val ACTION_STOP  = "com.nexus.sheildai.sos.audio.STOP"

        /** Maximum recording duration before automatic stop. */
        const val MAX_RECORDING_DURATION_MS = 5 * 60 * 1000L // 5 minutes

        /** Audio quality settings. */
        private const val SAMPLE_RATE_HZ = 44_100
        private const val BIT_RATE_BPS   = 128_000 // 128 kbps

        /** Tracks running state — checked by SOSManager before start. */
        @Volatile
        private var _isRecording = false
        val isRecording: Boolean get() = _isRecording

        // ─── Static start / stop helpers ─────────────────────────────────────

        /**
         * Starts the foreground audio recording service.
         * Safe to call from any thread (including a coroutine).
         *
         * @param context Application context.
         */
        fun startRecording(context: Context) {
            val intent = Intent(context, AudioRecordingService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.i(TAG, "startRecording() — service start requested")
        }

        /**
         * Stops the recording service and finalises the audio file.
         *
         * @param context Application context.
         */
        fun stopRecording(context: Context) {
            val intent = Intent(context, AudioRecordingService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
            Log.i(TAG, "stopRecording() — service stop requested")
        }
    }

    // ─── Instance state ───────────────────────────────────────────────────────

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Auto-stop timer job (cancelled if stopped manually before 5 min). */
    private var durationJob: Job? = null

    /** MediaRecorder instance — null when not recording. */
    private var mediaRecorder: MediaRecorder? = null

    /**
     * URI of the MediaStore entry (API 29+).
     * Used to clear IS_PENDING flag after recording completes.
     */
    private var recordingUri: Uri? = null

    /**
     * Fallback output file (API 26-28).
     * Written directly to app-external directory (no storage permission needed).
     */
    private var outputFile: File? = null

    /**
     * Partial wake lock — ensures CPU stays awake during recording even when
     * the screen is off (e.g., phone in pocket).
     */
    private var wakeLock: PowerManager.WakeLock? = null

    // ═════════════════════════════════════════════════════════════════════════
    // Service lifecycle
    // ═════════════════════════════════════════════════════════════════════════

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "AudioRecordingService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> handleStart()
            ACTION_STOP  -> handleStop()
            else         -> {
                Log.w(TAG, "onStartCommand: unknown action '${intent?.action}' — stopping")
                handleStop()
            }
        }
        return START_NOT_STICKY // Don't restart automatically after process death
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        releaseRecorder()
        releaseWakeLock()
        _isRecording = false
        Log.i(TAG, "AudioRecordingService destroyed")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // START handling
    // ═════════════════════════════════════════════════════════════════════════

    private fun handleStart() {
        if (_isRecording) {
            Log.w(TAG, "handleStart: already recording — ignoring duplicate start")
            return
        }

        // 1. MUST call startForeground() immediately (within 5s of startForegroundService).
        //    Using FOREGROUND_SERVICE_TYPE_DATA_SYNC — avoids the Android 14 per-service
        //    microphone eligibility block. VoiceDetectionService (microphone FGS) running
        //    in the same process provides the RECORD_AUDIO exemption; MediaRecorder works.
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    buildRecordingNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(NOTIFICATION_ID, buildRecordingNotification())
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "startForeground() blocked: ${e.message}. " +
                    "Audio capture will not start, but SOS session (SMS) continues.")
            _isRecording = false
            stopSelf()
            return
        }

        // 2. Acquire wake lock BEFORE starting recorder
        acquireWakeLock()

        // 3. Set up and start MediaRecorder (may throw — handle gracefully)
        val started = setupAndStartRecorder()

        if (!started) {
            Log.e(TAG, "MediaRecorder setup failed — stopping service")
            stopSelf()
            return
        }

        _isRecording = true
        Log.i(TAG, "🎙️ Audio recording started — max duration: ${MAX_RECORDING_DURATION_MS / 1000}s")

        // 4. Launch auto-stop timer
        durationJob = scope.launch {
            val intervalMs = 5_000L // update notification every 5s
            var elapsedMs = 0L

            while (isActive && elapsedMs < MAX_RECORDING_DURATION_MS) {
                delay(intervalMs)
                elapsedMs += intervalMs
                val remaining = ((MAX_RECORDING_DURATION_MS - elapsedMs) / 1000).toInt()
                Log.d(TAG, "Recording: ${elapsedMs / 1000}s elapsed, ${remaining}s remaining")
                updateNotificationProgress(elapsedMs)
            }

            if (isActive) {
                Log.i(TAG, "⏹️ 5-minute recording limit reached — stopping automatically")
                handleStop()
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // STOP handling
    // ═════════════════════════════════════════════════════════════════════════

    private fun handleStop() {
        durationJob?.cancel()
        durationJob = null

        finaliseRecording()
        releaseWakeLock()
        _isRecording = false

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // ═════════════════════════════════════════════════════════════════════════
    // MediaRecorder setup
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Configures and starts [MediaRecorder].
     *
     * Output strategy:
     *   API 29+  → MediaStore.Audio.Media (shared audio collection)
     *   API ≤28  → app-external directory (no storage permission needed)
     *
     * @return true if setup succeeded, false on error.
     */
    private fun setupAndStartRecorder(): Boolean {
        val fileName = generateFileName()

        return try {
            val recorder = createMediaRecorder()

            // Common configuration
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioSamplingRate(SAMPLE_RATE_HZ)
            recorder.setAudioEncodingBitRate(BIT_RATE_BPS)

            // Output — choose strategy by API level
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                setupMediaStoreOutput(recorder, fileName)
            } else {
                setupLegacyFileOutput(recorder, fileName)
            }

            recorder.prepare()
            recorder.start()
            mediaRecorder = recorder
            true

        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup MediaRecorder: ${e.message}", e)
            false
        }
    }

    /**
     * API 29+ — registers a MediaStore entry (IS_PENDING=1), uses the
     * returned content URI for output so the file appears in shared audio.
     */
    private fun setupMediaStoreOutput(recorder: MediaRecorder, fileName: String) {
        val contentValues = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME,   fileName)
            put(MediaStore.Audio.Media.MIME_TYPE,      "audio/mp4")
            put(MediaStore.Audio.Media.RELATIVE_PATH,  "Music/SHEildAI")
            put(MediaStore.Audio.Media.IS_PENDING,     1)
        }

        val uri = contentResolver.insert(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            contentValues
        ) ?: throw IllegalStateException("MediaStore insert returned null URI")

        recordingUri = uri

        // Use a file descriptor — no file path needed
        val pfd = contentResolver.openFileDescriptor(uri, "w")
            ?: throw IllegalStateException("Could not open ParcelFileDescriptor for $uri")

        recorder.setOutputFile(pfd.fileDescriptor)
        Log.i(TAG, "MediaStore output: $uri")
    }

    /**
     * API 26-28 — writes to the app's external files directory.
     * No WRITE_EXTERNAL_STORAGE permission is needed for this directory.
     */
    private fun setupLegacyFileOutput(recorder: MediaRecorder, fileName: String) {
        val dir = getExternalFilesDir("SHEildAI_SOS") ?: filesDir
        if (!dir.exists()) dir.mkdirs()

        val file = File(dir, fileName)
        outputFile = file
        recorder.setOutputFile(file.absolutePath)
        Log.i(TAG, "Legacy file output: ${file.absolutePath}")
    }

    /**
     * Creates a [MediaRecorder] using the appropriate constructor for the API level.
     * API 31+: `MediaRecorder(Context)` is preferred (deprecated constructor removed in future).
     * API 26-30: `MediaRecorder()` is used.
     */
    private fun createMediaRecorder(): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Finalise (stop recorder + clear MediaStore pending flag)
    // ═════════════════════════════════════════════════════════════════════════

    private fun finaliseRecording() {
        val recorder = mediaRecorder ?: return

        try {
            recorder.stop()
            Log.i(TAG, "✅ MediaRecorder stopped")
        } catch (e: Exception) {
            Log.e(TAG, "MediaRecorder.stop() threw: ${e.message}")
        } finally {
            recorder.release()
            mediaRecorder = null
        }

        // Clear IS_PENDING so the file becomes visible in MediaStore (API 29+)
        recordingUri?.let { uri ->
            try {
                val values = ContentValues().apply {
                    put(MediaStore.Audio.Media.IS_PENDING, 0)
                }
                contentResolver.update(uri, values, null, null)
                Log.i(TAG, "✅ MediaStore IS_PENDING cleared — file is now visible: $uri")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to clear IS_PENDING: ${e.message}")
            }
            recordingUri = null
        }

        // Log legacy path for API 26-28
        outputFile?.let { f ->
            if (f.exists()) {
                Log.i(TAG, "✅ Audio file saved: ${f.absolutePath} (${f.length() / 1024} KB)")
            } else {
                Log.w(TAG, "Output file not found after stop: ${f.absolutePath}")
            }
            outputFile = null
        }
    }

    private fun releaseRecorder() {
        try {
            mediaRecorder?.release()
        } catch (_: Exception) { }
        mediaRecorder = null
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Wake lock — keeps CPU running with screen off
    // ═════════════════════════════════════════════════════════════════════════

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SHEildAI:AudioRecordingWakeLock"
        ).also {
            it.acquire(MAX_RECORDING_DURATION_MS + 30_000L) // +30s buffer
            Log.d(TAG, "WakeLock acquired")
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.takeIf { it.isHeld }?.release()
        } catch (e: Exception) {
            Log.e(TAG, "WakeLock release failed: ${e.message}")
        }
        wakeLock = null
        Log.d(TAG, "WakeLock released")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Notification
    // ═════════════════════════════════════════════════════════════════════════

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW // Silent — don't disturb during emergency
            ).apply {
                description = "Used during SOS sessions to record audio evidence"
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildRecordingNotification(elapsedMs: Long = 0): Notification {
        // Tap notification → open app
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Stop action in notification drawer
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, AudioRecordingService::class.java).apply {
                action = ACTION_STOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val elapsed = if (elapsedMs > 0) {
            val min = elapsedMs / 60000
            val sec = (elapsedMs % 60000) / 1000
            " — ${min}m ${sec}s"
        } else ""

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🎙️ SOS Recording Active")
            .setContentText("Recording audio evidence$elapsed")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Stop Recording",
                stopPendingIntent
            )
            .setProgress(
                (MAX_RECORDING_DURATION_MS / 1000).toInt(),
                (elapsedMs / 1000).toInt(),
                false
            )
            .build()
    }

    private fun updateNotificationProgress(elapsedMs: Long) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildRecordingNotification(elapsedMs))
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Helpers
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Generates a timestamped file name.
     * Example: SOS_audio_20260424_004908.m4a
     */
    private fun generateFileName(): String {
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        return "SOS_audio_$timestamp.m4a"
    }
}
