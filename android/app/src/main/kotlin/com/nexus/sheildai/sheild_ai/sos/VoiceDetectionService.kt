package com.nexus.sheildai.sheild_ai.sos

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.nexus.sheildai.sheild_ai.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.ZipInputStream

/**
 * VoiceDetectionService — Always-on foreground service for offline keyword detection.
 *
 * Uses Vosk (https://alphacephei.com/vosk) to run a lightweight on-device speech
 * recognizer that listens for the trigger keywords: "help" / "sos".
 *
 * On detection → [SOSManager.triggerSOS] with [SOSTriggerSource.Voice].
 *
 * ┌──────────────────────────────────────────────────────────────┐
 * │  Mic management: pauses AudioRecord while SOSManager is     │
 * │  active (hands mic to AudioRecordingService / CameraX).     │
 * │  Resumes automatically once SOSManager returns to IDLE.     │
 * │                                                             │
 * │  Model: downloaded once to filesDir/vosk-model on first    │
 * │  launch, then loaded from local storage on subsequent runs. │
 * │                                                             │
 * │  Duplicate guard: SOSManager.canTrigger is checked before  │
 * │  every trigger call — the state machine rejects extras.    │
 * └──────────────────────────────────────────────────────────────┘
 *
 * Manifest: foregroundServiceType="microphone"
 */
class VoiceDetectionService : Service() {

    // ─── Companion ────────────────────────────────────────────────────────────

    companion object {
        private const val TAG = "VoiceDetectionService"
        private const val CHANNEL_ID      = "sos_voice_detection"
        private const val CHANNEL_NAME    = "SOS Voice Detection"
        private const val NOTIFICATION_ID = 2003

        const val ACTION_START = "com.nexus.sheildai.sos.voice.START"
        const val ACTION_STOP  = "com.nexus.sheildai.sos.voice.STOP"

        /** Keyword set — any of these in final result triggers SOS. Case-insensitive. */
        private val TRIGGER_KEYWORDS = listOf("help", "sos")

        /** Grammar passed to Vosk — restricts vocab for faster, accurate detection. */
        private val VOSK_GRAMMAR = """["help", "sos", "[unk]"]"""

        /** Audio configuration required by Vosk. */
        private const val SAMPLE_RATE = 16_000

        /** URL for the small English model (~40 MB download, once). */
        private const val MODEL_URL =
            "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"

        /** Directory inside filesDir where the extracted model is stored. */
        private const val MODEL_DIR_NAME = "vosk-model-small-en-us-0.15"

        /** Minimum ms between successive trigger detections (debounce). */
        private const val TRIGGER_DEBOUNCE_MS = 3_000L

        /** How often the audio loop re-checks RECORD_AUDIO permission (ms). */
        private const val PERM_CHECK_INTERVAL_MS = 30_000L

        /** Wait between SOS-active mic-handoff polls (ms). */
        private const val SESSION_POLL_MS = 500L

        /** Base backoff for mic-unavailable retries; doubles each attempt, max 60 s. */
        private const val MIC_BACKOFF_BASE_MS = 1_000L

        private val _isListening = AtomicBoolean(false)
        val isListening: Boolean get() = _isListening.get()

        fun startDetection(context: Context) {
            val intent = Intent(context, VoiceDetectionService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.i(TAG, "startDetection() requested")
        }

        fun stopDetection(context: Context) {
            context.startService(
                Intent(context, VoiceDetectionService::class.java).apply { action = ACTION_STOP }
            )
            Log.i(TAG, "stopDetection() requested")
        }
    }

    // ─── Instance state ───────────────────────────────────────────────────────

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var listenJob: Job? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var voskModel: Model? = null
    private var lastTriggerMs = 0L

    /**
     * Service-level AudioRecord and Recognizer instances.
     *
     * MUST be instance variables (not local to audioRecognitionLoop) so that
     * the Section-2 mic-handoff code and any concurrent caller all see the
     * SAME reference. Previously these were local variables — a second loop
     * started by a duplicate handleStart() had its own independent audioRecord
     * that was never released, permanently blocking AudioRecordingService.
     */
    @Volatile private var activeAudioRecord: AudioRecord? = null
    @Volatile private var activeRecognizer: Recognizer? = null

    /**
     * Prevents a duplicate keyword detection from racing through the [SOSManager.canTrigger]
     * guard before the first call has advanced the state machine.
     * [compareAndSet] is used so only one caller wins; the loser is silently dropped.
     */
    private val triggerInFlight = AtomicBoolean(false)

    // ═════════════════════════════════════════════════════════════════════════
    // Service lifecycle
    // ═════════════════════════════════════════════════════════════════════════

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "VoiceDetectionService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> handleStart()
            ACTION_STOP  -> handleStop()
            // null intent = Android restarted the service after process death (START_STICKY).
            // Re-arm instead of stopping so voice detection resumes automatically.
            else -> {
                Log.i(TAG, "Null/unknown intent — re-arming after process restart")
                handleStart()
            }
        }
        // STICKY — restart automatically after process death (always-on service)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        releaseModel()
        releaseWakeLock()
        _isListening.set(false)
        SHEildLog.i(TAG, "VoiceDetectionService destroyed")
        Log.i(TAG, "VoiceDetectionService destroyed")
    }

    /**
     * Called when the user swipes the app from the Recents list.
     *
     * START_STICKY is not guaranteed to restart the service on all OEM devices.
     * This schedules an [AlarmManager] one-shot (3 seconds) as a fallback.
     * AlarmManager is not affected by task removal — it survives process death.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        SHEildLog.w(TAG, "Task removed — scheduling AlarmManager restart in 3s")
        Log.w(TAG, "⚠️ Task removed — scheduling restart via AlarmManager")

        try {
            val restartIntent = android.content.Intent(this, VoiceDetectionService::class.java)
                .apply { action = ACTION_START }
            val pendingIntent = android.app.PendingIntent.getService(
                this, 0, restartIntent,
                android.app.PendingIntent.FLAG_ONE_SHOT or android.app.PendingIntent.FLAG_IMMUTABLE,
            )
            val alarmManager = getSystemService(android.app.AlarmManager::class.java)
            alarmManager.set(
                android.app.AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 3_000L,
                pendingIntent,
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule AlarmManager restart: ${e.message}")
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Start
    // ═════════════════════════════════════════════════════════════════════════

    private fun handleStart() {
        // ── Duplicate-start guard: set BEFORE the coroutine launches ─────────
        // Previously _isListening was set inside the coroutine (after model load),
        // leaving a window where a second handleStart() call (e.g. AlarmManager
        // restart racing with first) would pass the guard and start a SECOND
        // audioRecognitionLoop — each with its own local audioRecord holding the
        // mic. The second loop's mic was never released during SOS handoff, so
        // AudioRecordingService could never claim the hardware.
        if (!_isListening.compareAndSet(false, true)) {
            Log.w(TAG, "Already listening — ignoring duplicate start")
            return
        }

        // Must call startForeground() immediately
        startForeground(NOTIFICATION_ID, buildNotification("Initializing…"))
        acquireWakeLock()

        listenJob = scope.launch {
            // Step 1: Ensure RECORD_AUDIO permission
            if (!hasMicPermission()) {
                Log.e(TAG, "RECORD_AUDIO permission not granted — stopping service")
                _isListening.set(false)
                handleStop()
                return@launch
            }

            updateNotification("Loading voice model…")
            val modelPath = ensureModelAvailable()
            if (modelPath == null) {
                Log.e(TAG, "Failed to prepare Vosk model — stopping service")
                updateNotification("Model unavailable — voice trigger disabled")
                _isListening.set(false)
                handleStop()
                return@launch
            }

            Log.i(TAG, "Loading Vosk model from: $modelPath")
            updateNotification("Loading model…")
            val model = try {
                withContext(Dispatchers.IO) { Model(modelPath) }
            } catch (e: Exception) {
                Log.e(TAG, "Model load failed: ${e.message}")
                _isListening.set(false)
                handleStop()
                return@launch
            }
            voskModel = model
            Log.i(TAG, "✅ Vosk model loaded — starting audio loop")
            updateNotification("Listening for 'help'…")

            audioRecognitionLoop(model)
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Audio recognition loop
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Core listen loop — runs until the scope is cancelled or [handleStop] is called.
     *
     * Robustness layers (applied in order each iteration):
     *  1. **Permission check** — re-checks RECORD_AUDIO every [PERM_CHECK_INTERVAL_MS].
     *     If revoked, releases the mic and waits in a 10-second poll loop until
     *     the permission is re-granted or the service is stopped.
     *  2. **Mic handoff** — stops AudioRecord while SOSManager session is active;
     *     resumes automatically when state returns to non-active (COOLDOWN/IDLE).
     *  3. **Backoff-retry** — if the hardware mic is busy (another app holds it),
     *     retries with exponential backoff (1 s → 2 s → 4 s → … → 60 s cap) instead
     *     of breaking the loop and killing voice detection entirely.
     */
    private suspend fun audioRecognitionLoop(model: Model) {
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = minBuffer.coerceAtLeast(4096)

        // Use service-level instance variables (not locals) so the Section-2
        // handoff code can atomically release the mic from ANY caller context.
        // Local aliases kept for readability within the loop.
        var lastPermCheckMs = 0L
        var micRetryCount = 0

        try {
            while (currentCoroutineContext().isActive) {

                // ── 1. Periodic permission re-check ───────────────────────────
                val now = System.currentTimeMillis()
                if (now - lastPermCheckMs >= PERM_CHECK_INTERVAL_MS) {
                    lastPermCheckMs = now
                    if (!hasMicPermission()) {
                        Log.w(TAG, "⚠️ RECORD_AUDIO permission revoked — suspending")
                        updateNotification("Mic permission revoked — voice trigger paused")
                        activeAudioRecord?.stop()
                        activeAudioRecord?.release()
                        activeAudioRecord = null
                        activeRecognizer?.close()
                        activeRecognizer = null
                        // Poll every 10 s until re-granted or service stopped.
                        while (currentCoroutineContext().isActive && !hasMicPermission()) {
                            kotlinx.coroutines.delay(10_000L)
                        }
                        if (!currentCoroutineContext().isActive) break
                        Log.i(TAG, "✅ RECORD_AUDIO permission re-granted — resuming")
                        updateNotification("Listening for 'help'…")
                        lastPermCheckMs = System.currentTimeMillis()
                        micRetryCount = 0
                        continue
                    }
                }

                // ── 2. Mic handoff: pause while SOS session is active ─────────
                if (SOSManager.isSessionActive()) {
                    if (activeAudioRecord != null) {
                        // stop() alone parks the AudioRecord in a stopped state but
                        // keeps the underlying kernel audio HAL resource claimed.
                        // AudioRecordingService's MediaRecorder CANNOT open the same
                        // mic hardware until release() is called.
                        // We use the service-level instance variable (activeAudioRecord)
                        // so this is the single authoritative release — no second loop
                        // can hold a separate reference.
                        if (activeAudioRecord!!.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                            activeAudioRecord!!.stop()
                        }
                        activeAudioRecord!!.release()
                        activeAudioRecord = null
                        activeRecognizer?.close()
                        activeRecognizer = null
                        Log.d(TAG, "🔇 Mic released — SOS session active, mic freed for AudioRecordingService")
                        updateNotification("Paused during SOS session…")
                    }
                    kotlinx.coroutines.delay(SESSION_POLL_MS)
                    continue
                }

                // ── 3. Open AudioRecord (with exponential backoff-retry) ───────
                if (activeAudioRecord == null ||
                    activeAudioRecord!!.recordingState != AudioRecord.RECORDSTATE_RECORDING) {

                    activeAudioRecord?.release()
                    activeRecognizer?.close()
                    activeAudioRecord = null
                    activeRecognizer = null

                    val newRecord = createAudioRecord(bufferSize)
                    if (newRecord == null) {
                        micRetryCount++
                        val backoffMs = (MIC_BACKOFF_BASE_MS * (1L shl minOf(micRetryCount - 1, 6)))
                            .coerceAtMost(60_000L)
                        Log.w(TAG, "🎤 Mic unavailable (attempt $micRetryCount) — retry in ${backoffMs}ms")
                        updateNotification("Mic busy — retrying in ${backoffMs / 1000}s…")
                        kotlinx.coroutines.delay(backoffMs)
                        continue  // retry without exiting the loop
                    }

                    micRetryCount = 0  // success — reset counter
                    activeRecognizer = Recognizer(model, SAMPLE_RATE.toFloat(), VOSK_GRAMMAR)
                    newRecord.startRecording()
                    activeAudioRecord = newRecord
                    Log.d(TAG, "🎙️ Mic opened — listening for keywords")
                    updateNotification("Listening for 'help'…")
                }

                // ── Read audio buffer ─────────────────────────────────────────
                val buffer = ShortArray(bufferSize / 2)
                val read = activeAudioRecord!!.read(buffer, 0, buffer.size)
                if (read <= 0) continue

                // ── Feed to Vosk ──────────────────────────────────────────────
                if (activeRecognizer!!.acceptWaveForm(buffer, read)) {
                    val result = activeRecognizer!!.result
                    processRecognitionResult(result)
                }
                // Note: we skip partial results to avoid premature triggers
            }

        } catch (e: Exception) {
            Log.e(TAG, "Audio loop error: ${e.message}", e)
        } finally {
            activeAudioRecord?.stop()
            activeAudioRecord?.release()
            activeAudioRecord = null
            activeRecognizer?.close()
            activeRecognizer = null
            Log.d(TAG, "Audio loop exited")
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Keyword detection
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Parses the Vosk JSON result and checks for trigger keywords.
     *
     * Guards (applied in order):
     *  1. Result must contain a known trigger keyword.
     *  2. Debounce: [TRIGGER_DEBOUNCE_MS] must have elapsed since last detection.
     *  3. State guard: [SOSManager.currentState] must be IDLE ([canTrigger]).
     *  4. Trigger lock: [triggerInFlight] [AtomicBoolean] prevents a second simultaneous
     *     detection from racing through guards 2–3 before the first has advanced state.
     */
    private fun processRecognitionResult(jsonResult: String) {
        val text = jsonResult
            .substringAfter("\"text\"")
            .substringAfter("\"")
            .substringBefore("\"")
            .trim()
            .lowercase()

        if (text.isBlank() || text == "[unk]") return

        Log.v(TAG, "Vosk result: \"$text\"")

        val matched = TRIGGER_KEYWORDS.any { keyword -> text.contains(keyword) }
        if (!matched) return

        // Debounce guard
        val now = System.currentTimeMillis()
        if (now - lastTriggerMs < TRIGGER_DEBOUNCE_MS) {
            Log.d(TAG, "Debounce — ignoring detection (${now - lastTriggerMs}ms since last)")
            return
        }

        // State guard — SOSManager rejects non-IDLE triggers
        if (!SOSManager.currentState().canTrigger) {
            Log.d(TAG, "SOSManager not in triggerable state — ignoring keyword")
            return
        }

        // Trigger lock — only one winner through the guards above
        if (!triggerInFlight.compareAndSet(false, true)) {
            Log.d(TAG, "Trigger already in flight — ignoring duplicate detection")
            return
        }

        try {
            lastTriggerMs = now
            Log.i(TAG, "🗣️ Keyword detected: \"$text\" → triggering SOS")

            // Load contacts explicitly at trigger time and pass them directly.
            // This is the most reliable approach for voice-triggered SOS because:
            //  • The native cache was pre-warmed by SOSManager.init() on app launch.
            //  • It avoids relying on the lazy fallback inside triggerSOS() which reads
            //    FlutterSharedPreferences — that file may be in an intermediate state
            //    when the Flutter engine is not active.
            //  • Passing contacts explicitly skips the fallback entirely and goes straight
            //    to SMS dispatch with a known-good list.
            val contacts = SOSStateStore.loadTrustedContacts(applicationContext)
            if (contacts.isEmpty()) {
                Log.e(TAG, "⚠️ Voice SOS trigger: no trusted contacts found — SMS will be skipped. " +
                        "User must configure emergency contacts in the app.")
            } else {
                Log.i(TAG, "📋 Voice SOS trigger: loaded ${contacts.size} contact(s) for SMS dispatch")
            }

            SOSManager.triggerSOS(applicationContext, SOSTriggerSource.Voice(text), contacts)
        } finally {
            // SOSManager.triggerSOS transitions state synchronously (AtomicReference),
            // so the lock can be released immediately after return.
            triggerInFlight.set(false)
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Stop
    // ═════════════════════════════════════════════════════════════════════════

    private fun handleStop() {
        listenJob?.cancel()
        listenJob = null
        releaseModel()
        releaseWakeLock()
        _isListening.set(false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun releaseModel() {
        try { voskModel?.close() } catch (_: Exception) {}
        voskModel = null
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Model management — download & cache to filesDir
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Returns the local path to the Vosk model directory.
     *
     * Strategy:
     *  1. If already extracted to [filesDir]/[MODEL_DIR_NAME] → return path immediately
     *  2. Download the zip from [MODEL_URL] → extract → delete zip → return path
     *  3. On any failure → return null (service will disable voice trigger)
     */
    private suspend fun ensureModelAvailable(): String? = withContext(Dispatchers.IO) {
        val modelDir = File(filesDir, MODEL_DIR_NAME)

        if (modelDir.exists() && modelDir.isDirectory && (modelDir.list()?.size ?: 0) > 0) {
            Log.i(TAG, "Model already cached at ${modelDir.absolutePath}")
            return@withContext modelDir.absolutePath
        }

        Log.i(TAG, "Downloading Vosk model from $MODEL_URL …")
        updateNotification("⬇️ Downloading voice model (~40 MB)…")

        return@withContext try {
            val zipFile = File(cacheDir, "vosk-model.zip")
            downloadFile(MODEL_URL, zipFile)
            updateNotification("📦 Extracting model…")
            unzip(zipFile, filesDir)
            zipFile.delete()

            if (modelDir.exists()) {
                Log.i(TAG, "✅ Model extracted to ${modelDir.absolutePath}")
                modelDir.absolutePath
            } else {
                Log.e(TAG, "Model dir not found after extraction — expected: ${modelDir.absolutePath}")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Model download/extract failed: ${e.message}", e)
            null
        }
    }

    /** Downloads [urlString] to [dest]. Follows HTTP redirects. */
    private fun downloadFile(urlString: String, dest: File) {
        var connection: HttpURLConnection? = null
        try {
            connection = URL(urlString).openConnection() as HttpURLConnection
            connection.connectTimeout = 30_000
            connection.readTimeout    = 60_000
            connection.instanceFollowRedirects = true
            connection.connect()

            val responseCode = connection.responseCode
            if (responseCode != HttpURLConnection.HTTP_OK) {
                throw Exception("HTTP $responseCode downloading model")
            }

            connection.inputStream.use { input ->
                FileOutputStream(dest).use { output ->
                    input.copyTo(output, bufferSize = 8192)
                }
            }
            Log.d(TAG, "Downloaded model zip to ${dest.absolutePath} (${dest.length() / 1024} KB)")
        } finally {
            connection?.disconnect()
        }
    }

    /** Extracts a zip archive to [targetDir]. Skips path traversal entries for safety. */
    private fun unzip(zipFile: File, targetDir: File) {
        ZipInputStream(zipFile.inputStream().buffered()).use { zip ->
            var entry = zip.nextEntry
            while (entry != null) {
                // Security: prevent path traversal attacks
                val outFile = File(targetDir, entry.name)
                val canonicalOut = outFile.canonicalPath
                val canonicalTarget = targetDir.canonicalPath
                if (!canonicalOut.startsWith(canonicalTarget + File.separator)) {
                    Log.w(TAG, "Skipping suspicious zip entry: ${entry.name}")
                    entry = zip.nextEntry
                    continue
                }

                if (entry.isDirectory) {
                    outFile.mkdirs()
                } else {
                    outFile.parentFile?.mkdirs()
                    FileOutputStream(outFile).use { output ->
                        zip.copyTo(output, bufferSize = 8192)
                    }
                }
                zip.closeEntry()
                entry = zip.nextEntry
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // AudioRecord factory
    // ═════════════════════════════════════════════════════════════════════════

    @Suppress("MissingPermission")
    private fun createAudioRecord(bufferSize: Int): AudioRecord? {
        return try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION, // tuned for speech
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            ).also { rec ->
                if (rec.state != AudioRecord.STATE_INITIALIZED) {
                    rec.release()
                    Log.e(TAG, "AudioRecord failed to initialize")
                    return null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "AudioRecord creation error: ${e.message}")
            null
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Wake lock
    // ═════════════════════════════════════════════════════════════════════════

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SHEildAI:VoiceDetectionWakeLock"
        ).also {
            it.acquire() // indefinite — released in handleStop() or onDestroy()
        }
        Log.d(TAG, "WakeLock acquired")
    }

    private fun releaseWakeLock() {
        try { wakeLock?.takeIf { it.isHeld }?.release() } catch (_: Exception) {}
        wakeLock = null
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Permission check
    // ═════════════════════════════════════════════════════════════════════════

    private fun hasMicPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Notification
    // ═════════════════════════════════════════════════════════════════════════

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Always-on voice keyword detection for SOS trigger"
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(status: String): Notification {
        val tapIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getService(
            this, 1,
            Intent(this, VoiceDetectionService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🎙️ Voice Trigger Active")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(tapIntent)
            .setOngoing(true)
            .setSilent(true)
            .addAction(android.R.drawable.ic_delete, "Disable", stopIntent)
            .build()
    }

    private fun updateNotification(status: String) {
        try {
            getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, buildNotification(status))
        } catch (_: Exception) {}
    }
}
