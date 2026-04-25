package com.nexus.sheildai.sheild_ai.sos

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.StorageService
import java.io.File

/**
 * VoskManager — Phase 2: Microphone capture + recognition.
 *
 * Responsibilities:
 *  1. Unpack and load Vosk model from assets → internal storage.
 *  2. Open AudioRecord (16 kHz, mono, PCM 16-bit).
 *  3. Feed raw PCM buffers to the Recognizer in a continuous loop.
 *  4. Print partial and final results to Logcat.
 *
 * Runs entirely in the foreground (Activity context). No background services.
 */
class VoskManager(private val context: Context) {

    companion object {
        private const val TAG = "VoskManager"

        /** Must match AudioRecord config and Vosk expectation. */
        private const val SAMPLE_RATE     = 16_000
        private const val SAMPLE_RATE_F   = 16_000.0f

        /**
         * Restricted grammar → Vosk only considers these two outputs.
         *
         * "help"  — the keyword we want to detect.
         * "[unk]" — Vosk's rejection token for anything that doesn't sound like "help".
         *            WITHOUT [unk], Vosk force-fits all audio (noise, silence, other words)
         *            into "help", causing frequent false triggers.
         */
        private const val GRAMMAR = """["help", "[unk]"]"""

        /** Internal storage sub-directory where the model is unpacked. */
        private const val MODEL_DIR = "vosk-model"

        /** Asset folder name that StorageService will look for. */
        private const val ASSET_MODEL = "model-en-us"

        /** Minimum ms that must elapse between successive keyword triggers. */
        private const val DEBOUNCE_MS = 3_000L
    }

    // ─── State ───────────────────────────────────────────────────────────────

    private var model:      Model?      = null
    private var recognizer: Recognizer? = null
    private var audioRecord: AudioRecord? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var captureJob: Job? = null

    /** Epoch-ms of the last accepted keyword trigger (debounce reference). */
    @Volatile private var lastTriggerMs = 0L

    /**
     * Called on the IO dispatcher each time "help" clears the debounce guard.
     * Wire to your SOS trigger logic here or in MainActivity.
     */
    var onKeywordDetected: ((word: String) -> Unit)? = null

    /** True while the mic capture loop is running. */
    @Volatile var isListening: Boolean = false
        private set

    /**
     * Set to true inside [checkForKeyword] the moment a trigger is accepted.
     * Causes [runCaptureLoop] to exit on the next iteration so the mic is
     * released before [AudioRecordingService] tries to open it for SOS.
     */
    @Volatile private var pendingTrigger = false

    // ═════════════════════════════════════════════════════════════════════════
    // Initialization
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Step 1 — Load model and create recognizer.
     *
     * Model resolution order (first match wins):
     *  1. [filesDir]/vosk-model-small-en-us-0.15  — downloaded by VoiceDetectionService
     *  2. [filesDir]/vosk-model                   — previously unpacked by StorageService
     *  3. assets/model-en-us                      — bundled in the APK (requires model in assets)
     *
     * Callback fires on the calling thread or Vosk's internal thread.
     */
    fun initVosk(onComplete: (Boolean) -> Unit) {
        Log.i(TAG, "━━━ Vosk Init ━━━")
        Log.i(TAG, "  Rate    : ${SAMPLE_RATE} Hz")
        Log.i(TAG, "  Grammar : $GRAMMAR")

        // ── Path 1: model downloaded by VoiceDetectionService ──────────────────
        val vdsModel = File(context.filesDir, "vosk-model-small-en-us-0.15")
        if (vdsModel.exists() && vdsModel.isDirectory && (vdsModel.list()?.isNotEmpty() == true)) {
            Log.i(TAG, "  Source  : VoiceDetectionService cache (${vdsModel.absolutePath})")
            loadModelFromPath(vdsModel.absolutePath, onComplete)
            return
        }

        // ── Path 2: previously unpacked by StorageService ──────────────────────
        val unpackedModel = File(context.filesDir, MODEL_DIR)
        if (unpackedModel.exists() && unpackedModel.isDirectory && (unpackedModel.list()?.isNotEmpty() == true)) {
            Log.i(TAG, "  Source  : Cached unpack (${unpackedModel.absolutePath})")
            loadModelFromPath(unpackedModel.absolutePath, onComplete)
            return
        }

        // ── Path 3: unpack from bundled APK assets ─────────────────────────────
        Log.i(TAG, "  Source  : APK assets/$ASSET_MODEL → ${unpackedModel.absolutePath}")
        Log.d(TAG, "  (If no model in assets, this will fail — add model-en-us to assets/)")
        StorageService.unpack(
            context, ASSET_MODEL, MODEL_DIR,
            { loadedModel ->
                model = loadedModel
                buildRecognizer(loadedModel, onComplete)
            },
            { e ->
                Log.e(TAG, "❌ StorageService.unpack failed: ${e.message}", e)
                Log.e(TAG, "   → Make sure assets/model-en-us/ exists in the APK")
                Log.e(TAG, "   → Or say 'help' after VoiceDetectionService downloads the model")
                onComplete(false)
            }
        )
    }

    /** Loads a Vosk model directly from [path] on a background thread. */
    private fun loadModelFromPath(path: String, onComplete: (Boolean) -> Unit) {
        scope.launch {
            try {
                Log.d(TAG, "Loading model from: $path")
                val loadedModel = Model(path)
                model = loadedModel
                buildRecognizer(loadedModel, onComplete)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Model load failed at $path: ${e.message}", e)
                onComplete(false)
            }
        }
    }

    /** Creates the [Recognizer] from an already-loaded [Model]. */
    private fun buildRecognizer(loadedModel: Model, onComplete: (Boolean) -> Unit) {
        try {
            recognizer = Recognizer(loadedModel, SAMPLE_RATE_F, GRAMMAR)
            Log.i(TAG, "✅ Model loaded + Recognizer created (grammar=$GRAMMAR)")
            onComplete(true)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Recognizer creation failed: ${e.message}", e)
            onComplete(false)
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Microphone capture
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Step 2 — Open AudioRecord and start the recognition loop.
     *
     * Must be called AFTER [initVosk] succeeds.
     * Requires RECORD_AUDIO permission to already be granted.
     */
    fun startListening() {
        if (isListening) {
            Log.w(TAG, "startListening() called but already listening — ignored")
            return
        }

        val rec = recognizer
        if (rec == null) {
            Log.e(TAG, "startListening() called before recognizer is ready — call initVosk() first")
            return
        }

        if (!hasMicPermission()) {
            Log.e(TAG, "RECORD_AUDIO permission not granted — cannot start mic capture")
            return
        }

        pendingTrigger = false  // reset before every new listening session
        captureJob = scope.launch {
            runCaptureLoop(rec)
        }
    }

    /**
     * Stops the mic capture loop and releases AudioRecord.
     * The Vosk recognizer and model remain alive so [startListening] can be called again.
     */
    fun stopListening() {
        captureJob?.cancel()
        captureJob = null
        isListening = false

        audioRecord?.apply {
            if (recordingState == AudioRecord.RECORDSTATE_RECORDING) stop()
            release()
        }
        audioRecord = null

        Log.i(TAG, "🛑 Mic capture stopped")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Core audio loop
    // ═════════════════════════════════════════════════════════════════════════

    @Suppress("MissingPermission")
    private suspend fun runCaptureLoop(rec: Recognizer) = withContext(Dispatchers.IO) {
        // ── Open AudioRecord ──────────────────────────────────────────────────
        val minBuf    = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufSize   = minBuf.coerceAtLeast(4096)
        val buffer    = ShortArray(bufSize / 2)

        Log.d(TAG, "AudioRecord — minBuf=$minBuf  using bufSize=$bufSize")

        val ar = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufSize
            ).also { ar ->
                if (ar.state != AudioRecord.STATE_INITIALIZED) {
                    ar.release()
                    Log.e(TAG, "❌ AudioRecord failed to initialize")
                    return@withContext
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ AudioRecord creation threw: ${e.message}", e)
            return@withContext
        }

        audioRecord = ar
        ar.startRecording()
        isListening = true

        Log.i(TAG, "🎙️ AudioRecord open — capture loop started")

        // ── Capture loop ──────────────────────────────────────────────────────
        try {
            while (isActive && !pendingTrigger) {
                val read = ar.read(buffer, 0, buffer.size)

                // read() returns a negative code on error
                if (read < 0) {
                    Log.e(TAG, "AudioRecord.read() error code: $read — exiting loop")
                    break
                }
                if (read == 0) continue

                // Feed PCM frames to Vosk
                val isFinal = rec.acceptWaveForm(buffer, read)

                if (isFinal) {
                    // ── Final result → keyword check ──────────────────────────
                    val finalJson = rec.result
                    val text = extractText(finalJson)

                    // [unk] = Vosk's rejection token (audio didn't match grammar)
                    // Skip it immediately — never a valid keyword.
                    if (text == "[unk]" || text.isBlank()) {
                        Log.v(TAG, "🔕 REJECTED  : Vosk returned [unk] or empty (noise/silence)")
                    } else {
                        Log.i(TAG, "📝 FINAL     : \"$text\"  (raw=$finalJson)")
                        checkForKeyword(text)
                    }
                } else {
                    // ── Partial result ────────────────────────────────────────
                    val partialJson = rec.partialResult
                    val partial = extractPartial(partialJson)
                    if (partial.isNotBlank()) {
                        Log.v(TAG, "💬 PARTIAL : \"$partial\"")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Capture loop error: ${e.message}", e)
        } finally {
            ar.stop()
            ar.release()
            audioRecord = null
            isListening  = false
            Log.i(TAG, "Capture loop exited + AudioRecord released")
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Helpers
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Checks whether [text] is the exact keyword "help" (case-insensitive, word-boundary match),
     * applying a [DEBOUNCE_MS] guard so rapid detections fire at most once per window.
     *
     * Detection chain:
     *  1. Normalise text to lowercase and strip leading/trailing whitespace.
     *  2. Reject empty strings and Vosk's [unk] rejection token.
     *  3. Split into words and check for EXACT match of "help".
     *     → "helpful" / "helping" / "helpless" do NOT trigger.
     *  4. Reject if fewer than [DEBOUNCE_MS] ms have elapsed since last trigger.
     *  5. Update [lastTriggerMs], set [pendingTrigger], release mic, fire callback.
     */
    private fun checkForKeyword(text: String) {
        val normalised = text.trim().lowercase()
        if (normalised.isBlank() || normalised == "[unk]") return

        // ── Exact word-boundary match ─────────────────────────────────────────
        // Split on whitespace so "helpful" or "helping" never match "help".
        val words = normalised.split("\\s+".toRegex())
        val matched = words.contains("help")
        if (!matched) {
            Log.v(TAG, "🔕 NO MATCH  : words=$words")
            return
        }

        // ── Debounce guard ────────────────────────────────────────────────────
        val now = System.currentTimeMillis()
        val elapsed = now - lastTriggerMs
        if (elapsed < DEBOUNCE_MS) {
            Log.d(TAG, "⏱️ DEBOUNCE  : \"$normalised\" suppressed (${elapsed}ms < ${DEBOUNCE_MS}ms)")
            return
        }

        // ── Accepted ─────────────────────────────────────────────────────────
        lastTriggerMs = now
        pendingTrigger = true   // signals the while-loop to exit after this frame

        Log.w(TAG, "🚨 HELP DETECTED : \"$normalised\" (elapsed: ${elapsed}ms)")

        // Release mic NOW — before the SOS recording service claims the hardware.
        releaseMicImmediate()

        // Fire the callback (MainActivity will add a short delay before triggerSOS).
        onKeywordDetected?.invoke(normalised)
    }

    /**
     * Stops and releases [audioRecord] synchronously on the calling thread.
     *
     * Called immediately after keyword acceptance so the mic hardware is free
     * before [AudioRecordingService] opens it for SOS recording.
     * The loop's [finally] block will safely no-op on the already-released instance.
     */
    private fun releaseMicImmediate() {
        try {
            val ar = audioRecord
            if (ar != null) {
                if (ar.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    ar.stop()
                    Log.i(TAG, "🎤 AudioRecord stopped")
                }
                ar.release()
                audioRecord = null
                isListening  = false
                Log.i(TAG, "✅ Mic fully released — hardware available for SOS recording")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing AudioRecord: ${e.message}", e)
        }
    }

    /**
     * Extracts the "text" field from a Vosk final result JSON.
     * e.g. {"text": "help"} → "help"
     */
    private fun extractText(json: String): String =
        json.substringAfter("\"text\"")
            .substringAfter("\"")
            .substringBefore("\"")
            .trim()

    /**
     * Extracts the "partial" field from a Vosk partial result JSON.
     * e.g. {"partial": "hel"} → "hel"
     */
    private fun extractPartial(json: String): String =
        json.substringAfter("\"partial\"")
            .substringAfter("\"")
            .substringBefore("\"")
            .trim()

    private fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED

    // ═════════════════════════════════════════════════════════════════════════
    // Cleanup
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Full teardown — stops the mic loop and closes the Vosk model.
     * Call from Activity.onDestroy().
     */
    fun release() {
        Log.d(TAG, "Releasing all Vosk resources")
        stopListening()
        scope.cancel()
        recognizer?.close()
        model?.close()
        recognizer = null
        model = null
    }
}
