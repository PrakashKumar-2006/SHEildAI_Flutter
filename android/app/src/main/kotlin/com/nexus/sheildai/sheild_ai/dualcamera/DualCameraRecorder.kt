package com.nexus.sheildai.sheild_ai.dualcamera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.CompositionSettings
import androidx.camera.core.ConcurrentCamera.SingleCameraConfig
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.nexus.sheildai.sheild_ai.dualcamera.DualCameraConstants.STATUS_INITIALISING
import com.nexus.sheildai.sheild_ai.dualcamera.DualCameraConstants.STATUS_RECORDING
import com.nexus.sheildai.sheild_ai.dualcamera.DualCameraConstants.STATUS_STOPPED
import com.nexus.sheildai.sheild_ai.dualcamera.DualCameraConstants.STATUS_UNSUPPORTED
import java.io.File

/**
 * DualCameraRecorder — Core engine for simultaneous front + rear camera recording.
 *
 * Uses CameraX 1.5's [SingleCameraConfig] with [CompositionSettings] to compose two camera
 * streams into a single output surface:
 *   • Front camera → Top half   (Y offset 0.0, scale height 0.5)
 *   • Rear  camera → Bottom half (Y offset 0.5, scale height 0.5)
 *
 * Output: a single 720 × 1440 MP4 file with one shared audio track.
 *
 * Usage:
 *   val recorder = DualCameraRecorder(context, previewView)
 *   recorder.statusCallback = { status -> ... }
 *   recorder.errorCallback  = { msg    -> ... }
 *
 *   // Check hardware first
 *   if (recorder.isConcurrentCameraSupported()) {
 *       recorder.startRecording(outputFile)
 *   }
 *
 *   recorder.stopRecording()
 *   recorder.release()   // always call when done
 */
class DualCameraRecorder(
    private val context: Context,
    private val previewView: PreviewView,
) {

    companion object {
        private const val TAG = "DualCameraRecorder"
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Public callbacks — set these before calling startRecording()
    // ──────────────────────────────────────────────────────────────────────────

    /** Called on Main thread with a STATUS_* constant from [DualCameraConstants]. */
    var statusCallback: ((String) -> Unit)? = null

    /** Called on Main thread when an unrecoverable error occurs. */
    var errorCallback: ((String) -> Unit)? = null

    // ──────────────────────────────────────────────────────────────────────────
    // Internal state
    // ──────────────────────────────────────────────────────────────────────────

    private val mainHandler = Handler(Looper.getMainLooper())
    private val lifecycleOwner = RecorderLifecycleOwner()

    private var cameraProvider: ProcessCameraProvider? = null
    private var activeRecording: Recording? = null

    @Volatile private var _isRecording = false
    val isRecording: Boolean get() = _isRecording

    // ──────────────────────────────────────────────────────────────────────────
    // Concurrent camera support check
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Returns true if the device ISP supports opening front and back cameras simultaneously.
     * Must be called after [ProcessCameraProvider] is available.
     *
     * This performs the check synchronously on the calling thread.
     * For UI use, call this from a background coroutine/thread.
     */
    fun isConcurrentCameraSupported(): Boolean {
        return try {
            val provider = ProcessCameraProvider.getInstance(context).get()
            cameraProvider = provider

            // availableConcurrentCameraInfos lists sets of cameras that can run concurrently.
            // We look for any set that contains both a FRONT and a BACK camera.
            val concurrentSets = provider.availableConcurrentCameraInfos
            Log.d(TAG, "Concurrent camera sets available: ${concurrentSets.size}")

            val supported = concurrentSets.any { cameraInfoSet ->
                val hasFront = cameraInfoSet.any { info ->
                    info.lensFacing == CameraSelector.LENS_FACING_FRONT
                }
                val hasBack = cameraInfoSet.any { info ->
                    info.lensFacing == CameraSelector.LENS_FACING_BACK
                }
                hasFront && hasBack
            }

            Log.i(TAG, "Concurrent Front+Back camera supported: $supported")
            supported
        } catch (e: Exception) {
            Log.e(TAG, "Concurrent camera check failed: ${e.message}", e)
            false
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Start recording
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Opens both cameras, begins compositing, and starts recording to [outputFile].
     *
     * Must be called on the **Main thread**.
     *
     * @param outputFile Absolute path to the target .mp4 file. Parent directories must exist.
     */
    fun startRecording(outputFile: File) {
        if (_isRecording) {
            Log.w(TAG, "Already recording — ignoring duplicate start")
            return
        }

        // ── Permission pre-flight ───────────────────────────────────────────
        // Check CAMERA and RECORD_AUDIO before touching CameraX so we emit
        // a clear, actionable error code rather than a raw SecurityException.
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            val msg = "CAMERA permission not granted — cannot start recording"
            Log.e(TAG, msg)
            emitError("${DualCameraConstants.ERROR_CAMERA_PERMISSION}: $msg")
            return
        }

        Log.i(TAG, "startRecording() → ${outputFile.absolutePath}")
        emitStatus(STATUS_INITIALISING)

        val provider = cameraProvider
        if (provider == null) {
            emitError("${DualCameraConstants.ERROR_CAMERA_ERROR}: CameraProvider not initialised. Call checkSupport() first.")
            return
        }

        try {
            provider.unbindAll()
            lifecycleOwner.start()
            bindConcurrentCamerasAndRecord(provider, outputFile)
        } catch (e: Exception) {
            Log.e(TAG, "startRecording failed: ${e.message}", e)
            emitError("${DualCameraConstants.ERROR_CAMERA_ERROR}: ${e.message}")
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CameraX concurrent binding
    // ──────────────────────────────────────────────────────────────────────────

    private fun bindConcurrentCamerasAndRecord(
        provider: ProcessCameraProvider,
        outputFile: File,
    ) {
        // ── Shared Recorder ─────────────────────────────────────────────────
        // A single Recorder feeds both camera streams into one video track.
        // QualitySelector targets 720p; CameraX picks the closest supported quality.
        val recorder = Recorder.Builder()
            .setQualitySelector(
                QualitySelector.from(
                    Quality.HD,                                        // 720p target
                    androidx.camera.video.FallbackStrategy
                        .lowerQualityOrHigherThan(Quality.SD)          // SD fallback
                )
            )
            .build()

        val videoCapture = VideoCapture.withOutput(recorder)

        // ── Preview use case ─────────────────────────────────────────────────
        // One shared Preview surface is used for both camera configs via
        // PreviewView. CameraX's compositor writes the composed frame here.
        val preview = Preview.Builder().build().also {
            it.surfaceProvider = previewView.surfaceProvider
        }

        // ── Composition layout ────────────────────────────────────────────────
        // Normalised coordinates (0.0–1.0) within the output surface:
        //
        //   Front camera   → top half    : offset (0, 0), scale (1.0w × 0.5h)
        //   Rear  camera   → bottom half : offset (0, 0.5), scale (1.0w × 0.5h)
        //
        // This produces a final 720 × 1440 frame where each camera gets exactly
        // 720 × 720 square pixels.
        val frontComposition = CompositionSettings.Builder()
            .setAlpha(1.0f)
            .setOffset(0.0f, 0.0f)      // top-left corner of output
            .setScale(1.0f, 0.5f)       // full width, top half height
            .build()

        val backComposition = CompositionSettings.Builder()
            .setAlpha(1.0f)
            .setOffset(0.0f, 0.5f)      // starts at the vertical midpoint
            .setScale(1.0f, 0.5f)       // full width, bottom half height
            .build()

        // ── Use-case groups (one per camera) ──────────────────────────────────
        // Each SingleCameraConfig MUST receive its own UseCaseGroup wrapper even
        // though they reference the same underlying UseCase instances (preview +
        // videoCapture). Passing a single shared UseCaseGroup to both configs
        // causes CameraX to bind the use-cases for the first camera only, which
        // results in only the front-camera stream being captured.
        val frontUseCaseGroup = UseCaseGroup.Builder()
            .addUseCase(preview)
            .addUseCase(videoCapture)
            .build()

        val backUseCaseGroup = UseCaseGroup.Builder()
            .addUseCase(preview)
            .addUseCase(videoCapture)
            .build()

        // ── SingleCameraConfig per camera ────────────────────────────────────
        val frontConfig = SingleCameraConfig(
            CameraSelector.DEFAULT_FRONT_CAMERA,
            frontUseCaseGroup,
            frontComposition,
            lifecycleOwner
        )

        val backConfig = SingleCameraConfig(
            CameraSelector.DEFAULT_BACK_CAMERA,
            backUseCaseGroup,
            backComposition,
            lifecycleOwner
        )

        // ── Bind both configs to lifecycle ───────────────────────────────────
        provider.bindToLifecycle(listOf(frontConfig, backConfig))
        Log.i(TAG, "CameraX concurrent cameras bound successfully")

        // ── Start writing to file ─────────────────────────────────────────────
        startFileRecording(videoCapture, outputFile)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // File recording
    // ──────────────────────────────────────────────────────────────────────────

    @androidx.annotation.OptIn(androidx.camera.video.ExperimentalPersistentRecording::class)
    private fun startFileRecording(
        videoCapture: VideoCapture<Recorder>,
        outputFile: File,
    ) {
        val outputOptions = FileOutputOptions.Builder(outputFile).build()

        var pendingRecording = videoCapture.output.prepareRecording(context, outputOptions)

        // Add audio if RECORD_AUDIO permission is granted
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            == PackageManager.PERMISSION_GRANTED
        ) {
            pendingRecording = pendingRecording.withAudioEnabled()
            Log.d(TAG, "Audio recording enabled")
        } else {
            Log.w(TAG, "RECORD_AUDIO permission not granted — recording without audio")
        }

        activeRecording = pendingRecording.start(ContextCompat.getMainExecutor(context)) { event ->
            when (event) {
                is VideoRecordEvent.Start -> {
                    _isRecording = true
                    Log.i(TAG, "🎥 Dual-camera recording started → ${outputFile.name}")
                    emitStatus(STATUS_RECORDING)
                }

                is VideoRecordEvent.Finalize -> {
                    _isRecording = false
                    if (event.hasError()) {
                        val msg = "Recording error (code ${event.error}): ${event.cause?.message}"
                        Log.e(TAG, msg)
                        emitError(msg)
                    } else {
                        Log.i(TAG, "✅ Dual-camera video saved: ${event.outputResults.outputUri}")
                        emitStatus(STATUS_STOPPED)
                    }
                }

                is VideoRecordEvent.Status -> {
                    val stats = event.recordingStats
                    Log.v(
                        TAG,
                        "Recording: ${stats.recordedDurationNanos / 1_000_000_000}s elapsed, " +
                            "${stats.numBytesRecorded / 1024} KB"
                    )
                }

                else -> Unit
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Stop recording
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Stops the active recording and finalises the output file.
     * Safe to call even if not currently recording.
     */
    fun stopRecording() {
        Log.i(TAG, "stopRecording() called — isRecording=$_isRecording")
        activeRecording?.stop()
        activeRecording = null
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Lifecycle pause / resume (app backgrounding)
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Pauses the camera preview by stepping the [RecorderLifecycleOwner] down
     * from RESUMED → STARTED.
     *
     * CameraX interprets STARTED as "paused" and closes the camera sensor,
     * which releases the camera hardware and prevents the
     * "camera resource unavailable" error when another app takes the camera.
     *
     * Any active recording is stopped first to prevent a corrupt output file.
     */
    fun pausePreview() {
        Log.i(TAG, "pausePreview() — stopping recording and pausing lifecycle")
        // Stop recording before pausing — a recording left open while the lifecycle
        // drops will produce a corrupt / incomplete MP4.
        if (_isRecording) {
            stopRecording()
        }
        lifecycleOwner.pause()
    }

    /**
     * Resumes the camera preview after a [pausePreview] call by stepping the
     * [RecorderLifecycleOwner] back up from STARTED → RESUMED.
     *
     * CameraX re-opens the sensors automatically.
     * Note: this does NOT restart a recording — call [startRecording] explicitly.
     */
    fun resumePreview() {
        Log.i(TAG, "resumePreview() — restoring lifecycle to RESUMED")
        lifecycleOwner.start()   // start() sets state to RESUMED
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Release
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Fully releases the camera provider and lifecycle.
     * Must be called when the [DualCameraView] is destroyed to prevent camera leaks.
     */
    fun release() {
        Log.i(TAG, "release() — cleaning up DualCameraRecorder")
        stopRecording()
        mainHandler.post {
            cameraProvider?.unbindAll()
            cameraProvider = null
            lifecycleOwner.destroy()
        }
        _isRecording = false
        statusCallback = null
        errorCallback = null
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────────

    private fun emitStatus(status: String) {
        mainHandler.post { statusCallback?.invoke(status) }
    }

    private fun emitError(message: String) {
        mainHandler.post { errorCallback?.invoke(message) }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // RecorderLifecycleOwner
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Minimal [LifecycleOwner] that drives CameraX without requiring an Activity.
     * Mirrors the pattern used in [VideoRecordingService.ServiceLifecycleOwner].
     */
    private class RecorderLifecycleOwner : LifecycleOwner {
        private val registry = LifecycleRegistry(this)
        override val lifecycle: Lifecycle get() = registry

        fun start() {
            Handler(Looper.getMainLooper()).post {
                registry.currentState = Lifecycle.State.RESUMED
            }
        }

        fun pause() {
            Handler(Looper.getMainLooper()).post {
                registry.currentState = Lifecycle.State.STARTED
            }
        }

        fun destroy() {
            Handler(Looper.getMainLooper()).post {
                if (registry.currentState != Lifecycle.State.DESTROYED) {
                    registry.currentState = Lifecycle.State.DESTROYED
                }
            }
        }
    }
}
