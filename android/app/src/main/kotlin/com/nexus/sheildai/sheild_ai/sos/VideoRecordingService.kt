package com.nexus.sheildai.sheild_ai.sos

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.MediaStoreOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.nexus.sheildai.sheild_ai.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * VideoRecordingService — Foreground service for SOS front-camera video evidence.
 *
 * Activated when the app is in the foreground (camera access allowed).
 * Records up to [MAX_RECORDING_DURATION_MS] (2 minutes) of video+audio via CameraX.
 *
 * Architecture:
 *  - CameraX [VideoCapture] with [Recorder] — saves directly to MediaStore.Video
 *  - [ServiceLifecycleOwner] — custom LifecycleOwner so CameraX can bind in a Service
 *  - [PARTIAL_WAKE_LOCK] — CPU stays alive when screen turns off
 *  - 1-second start delay allows AudioRecordingService to fully release the mic
 *
 * Manifest: foregroundServiceType="camera|microphone"
 */
class VideoRecordingService : Service() {

    // ─── Companion ────────────────────────────────────────────────────────────

    companion object {
        private const val TAG = "VideoRecordingService"
        private const val CHANNEL_ID      = "sos_video_recording"
        private const val CHANNEL_NAME    = "SOS Video Recording"
        private const val NOTIFICATION_ID = 2002

        const val ACTION_START = "com.nexus.sheildai.sos.video.START"
        const val ACTION_STOP  = "com.nexus.sheildai.sos.video.STOP"

        /** 2-minute maximum — keeps file size manageable. */
        const val MAX_RECORDING_DURATION_MS = 2 * 60 * 1000L

        /** Buffer before camera opens — lets AudioRecordingService fully release the mic. */
        private const val MIC_HANDOFF_DELAY_MS = 1_000L

        @Volatile private var _isRecording = false
        val isRecording: Boolean get() = _isRecording

        fun startRecording(context: Context) {
            val intent = Intent(context, VideoRecordingService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.i(TAG, "startRecording() requested")
        }

        fun stopRecording(context: Context) {
            context.startService(
                Intent(context, VideoRecordingService::class.java).apply { action = ACTION_STOP }
            )
            Log.i(TAG, "stopRecording() requested")
        }
    }

    // ─── Instance fields ──────────────────────────────────────────────────────

    /** Coroutine scope for timers. Camera setup runs on Dispatchers.Main via Handler. */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var durationJob: Job? = null

    private val lifecycleOwner = ServiceLifecycleOwner()
    private var cameraProvider: ProcessCameraProvider? = null
    private var activeRecording: Recording? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // ═════════════════════════════════════════════════════════════════════════
    // Service lifecycle
    // ═════════════════════════════════════════════════════════════════════════

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> handleStart()
            ACTION_STOP  -> handleStop()
            else         -> handleStop()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        lifecycleOwner.destroy()
        releaseCamera()
        releaseWakeLock()
        _isRecording = false
        Log.i(TAG, "VideoRecordingService destroyed")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Start — must call startForeground() immediately
    // ═════════════════════════════════════════════════════════════════════════

    private fun handleStart() {
        if (_isRecording) {
            Log.w(TAG, "Already recording — ignoring duplicate start")
            return
        }

        // MUST call startForeground() immediately (within 5s of startForegroundService).
        // VideoRecordingService uses foregroundServiceType="camera|microphone" — both are
        // foreground-only on Android 14. If this is ever reached from background (race
        // condition: user locks screen in the ~1s mic handoff window), the SecurityException
        // would propagate to the Android framework and kill the process.
        // Catching it here means audio SOS continues uninterrupted even if video cannot start.
        try {
            startForeground(NOTIFICATION_ID, buildNotification())
        } catch (e: SecurityException) {
            Log.e(TAG, "startForeground() blocked by Android 14 background restriction: ${e.message}. " +
                    "Video capture cannot start from background — audio SOS continues.")
            _isRecording = false
            stopSelf()
            return
        }

        acquireWakeLock()

        // 1-second mic handoff buffer, then open camera
        scope.launch {
            Log.i(TAG, "⏳ Waiting ${MIC_HANDOFF_DELAY_MS}ms for mic handoff...")
            delay(MIC_HANDOFF_DELAY_MS)

            // Camera setup MUST happen on the main thread
            Handler(Looper.getMainLooper()).post {
                setupCameraAndRecord()
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Camera setup (main thread)
    // ═════════════════════════════════════════════════════════════════════════

    private fun setupCameraAndRecord() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener({
            try {
                val provider = cameraProviderFuture.get()
                cameraProvider = provider

                // Build Recorder with HD quality (falls back to lower if unsupported)
                val recorder = Recorder.Builder()
                    .setQualitySelector(
                        QualitySelector.from(
                            Quality.HD,
                            androidx.camera.video.FallbackStrategy.lowerQualityOrHigherThan(Quality.SD)
                        )
                    )
                    .build()

                val videoCapture = VideoCapture.withOutput(recorder)

                // Prefer front camera (user-facing evidence), fallback to back
                val cameraSelector = if (provider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) {
                    CameraSelector.DEFAULT_FRONT_CAMERA
                } else {
                    CameraSelector.DEFAULT_BACK_CAMERA
                }

                // Bind to our custom LifecycleOwner (service-managed)
                provider.unbindAll()
                lifecycleOwner.start()
                provider.bindToLifecycle(lifecycleOwner, cameraSelector, videoCapture)

                startRecordingToMediaStore(videoCapture)

            } catch (e: Exception) {
                Log.e(TAG, "Camera setup failed: ${e.message}", e)
                handleStop()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    @androidx.annotation.OptIn(androidx.camera.video.ExperimentalPersistentRecording::class)
    private fun startRecordingToMediaStore(videoCapture: VideoCapture<Recorder>) {
        val fileName = "SOS_video_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())}.mp4"

        val contentValues = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/SHEildAI")
            }
        }

        val outputOptions = MediaStoreOutputOptions.Builder(
            contentResolver,
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        ).setContentValues(contentValues).build()

        // Prepare recording — add audio if permission granted
        var pending = videoCapture.output.prepareRecording(this, outputOptions)
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            == PackageManager.PERMISSION_GRANTED
        ) {
            pending = pending.withAudioEnabled()
        }

        activeRecording = pending.start(ContextCompat.getMainExecutor(this)) { event ->
            when (event) {
                is VideoRecordEvent.Start -> {
                    _isRecording = true
                    Log.i(TAG, "🎥 Video recording started → Movies/SHEildAI/$fileName")
                    startDurationTimer()
                }
                is VideoRecordEvent.Finalize -> {
                    if (event.hasError()) {
                        Log.e(TAG, "Recording error (code ${event.error}): ${event.cause?.message}")
                    } else {
                        Log.i(TAG, "✅ Video saved: ${event.outputResults.outputUri}")
                    }
                    _isRecording = false
                }
                is VideoRecordEvent.Status -> {
                    val stats = event.recordingStats
                    Log.v(TAG, "Recording: ${stats.recordedDurationNanos / 1_000_000_000}s, " +
                            "${stats.numBytesRecorded / 1024} KB")
                }
                else -> Unit
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Stop
    // ═════════════════════════════════════════════════════════════════════════

    private fun handleStop() {
        durationJob?.cancel()
        durationJob = null

        activeRecording?.stop()
        activeRecording = null

        releaseCamera()
        releaseWakeLock()
        _isRecording = false

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun releaseCamera() {
        try {
            Handler(Looper.getMainLooper()).post {
                cameraProvider?.unbindAll()
                cameraProvider = null
                lifecycleOwner.stop()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Camera release error: ${e.message}")
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Duration timer
    // ═════════════════════════════════════════════════════════════════════════

    private fun startDurationTimer() {
        durationJob = scope.launch {
            val tickMs = 5_000L
            var elapsed = 0L

            while (isActive && elapsed < MAX_RECORDING_DURATION_MS) {
                delay(tickMs)
                elapsed += tickMs
                val remaining = ((MAX_RECORDING_DURATION_MS - elapsed) / 1000).toInt()
                Log.d(TAG, "Video: ${elapsed / 1000}s elapsed, ${remaining}s remaining")
                updateNotificationProgress(elapsed)
            }

            if (isActive) {
                Log.i(TAG, "⏹️ 2-minute video limit reached — stopping")
                Handler(Looper.getMainLooper()).post { handleStop() }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Wake lock
    // ═════════════════════════════════════════════════════════════════════════

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SHEildAI:VideoRecordingWakeLock"
        ).also { it.acquire(MAX_RECORDING_DURATION_MS + 30_000L) }
        Log.d(TAG, "WakeLock acquired")
    }

    private fun releaseWakeLock() {
        try { wakeLock?.takeIf { it.isHeld }?.release() } catch (_: Exception) {}
        wakeLock = null
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Notification
    // ═════════════════════════════════════════════════════════════════════════

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "SOS video evidence recording"
                setShowBadge(false)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(elapsedMs: Long = 0): Notification {
        val tapIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getService(
            this, 1,
            Intent(this, VideoRecordingService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val elapsed = if (elapsedMs > 0) {
            " — ${elapsedMs / 60000}m ${(elapsedMs % 60000) / 1000}s"
        } else ""

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("📹 SOS Video Recording")
            .setContentText("Recording video evidence$elapsed")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(tapIntent)
            .setOngoing(true)
            .setSilent(true)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopIntent)
            .setProgress(
                (MAX_RECORDING_DURATION_MS / 1000).toInt(),
                (elapsedMs / 1000).toInt(),
                false
            )
            .build()
    }

    private fun updateNotificationProgress(elapsedMs: Long) {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(elapsedMs))
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ServiceLifecycleOwner — lets CameraX bind without an Activity
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * A minimal [LifecycleOwner] implementation for use inside a Service.
     * CameraX requires a [LifecycleOwner] for [ProcessCameraProvider.bindToLifecycle].
     * All state mutations happen on the main thread via the parent service's Handler.
     */
    private inner class ServiceLifecycleOwner : LifecycleOwner {
        private val registry = LifecycleRegistry(this)
        override val lifecycle: Lifecycle get() = registry

        fun start() {
            Handler(Looper.getMainLooper()).post {
                registry.currentState = Lifecycle.State.STARTED
            }
        }

        fun stop() {
            Handler(Looper.getMainLooper()).post {
                registry.currentState = Lifecycle.State.CREATED
            }
        }

        fun destroy() {
            Handler(Looper.getMainLooper()).post {
                registry.currentState = Lifecycle.State.DESTROYED
            }
        }
    }
}
