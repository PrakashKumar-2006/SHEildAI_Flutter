package com.nexus.sheildai.sheild_ai.dualcamera

import android.content.Context
import android.util.Log
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File

/**
 * DualCameraView — Flutter PlatformView that hosts the dual-camera preview and recording.
 *
 * Lifecycle:
 *  • Created by [DualCameraViewFactory] when Flutter first renders the AndroidView widget.
 *  • Flutter communicates via [DualCameraConstants.METHOD_CHANNEL]:
 *      "checkSupport"    → Boolean
 *      "startRecording"  → void  (arg: "outputPath": String)
 *      "stopRecording"   → void
 *  • Status and errors are pushed to Flutter via [DualCameraConstants.EVENT_CHANNEL].
 *  • [dispose] is called by Flutter when the widget leaves the tree — releases all resources.
 *
 * Threading:
 *  • Camera setup must happen on Main. [DualCameraRecorder] handles this internally.
 *  • [checkSupport] is I/O-blocking so it runs on [Dispatchers.IO] via a coroutine.
 */
class DualCameraView(
    private val context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView {

    companion object {
        private const val TAG = "DualCameraView"
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Views
    // ──────────────────────────────────────────────────────────────────────────

    private val previewView: PreviewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.PERFORMANCE
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Core recorder
    // ──────────────────────────────────────────────────────────────────────────

    private val recorder = DualCameraRecorder(context, previewView)

    // ──────────────────────────────────────────────────────────────────────────
    // Coroutine scope (for blocking isConcurrentCameraSupported() call)
    // ──────────────────────────────────────────────────────────────────────────

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // ──────────────────────────────────────────────────────────────────────────
    // Flutter channels
    // ──────────────────────────────────────────────────────────────────────────

    private val methodChannel = MethodChannel(
        messenger,
        "${DualCameraConstants.METHOD_CHANNEL}/$viewId"
    )

    private val eventChannel = EventChannel(
        messenger,
        "${DualCameraConstants.EVENT_CHANNEL}/$viewId"
    )

    // EventChannel sink — held so we can push events; set when Flutter subscribes
    private var eventSink: EventChannel.EventSink? = null

    init {
        Log.d(TAG, "DualCameraView[$viewId] created")
        setupEventChannel()
        setupMethodChannel()
        setupRecorderCallbacks()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // PlatformView contract
    // ──────────────────────────────────────────────────────────────────────────

    override fun getView(): View = previewView

    override fun dispose() {
        Log.d(TAG, "DualCameraView disposed — releasing recorder")
        // Stop recording and release all camera resources
        recorder.release()
        // Signal Flutter the event stream is ending before nulling the sink
        eventSink?.endOfStream()
        eventSink = null
        // Remove method handler so stale calls don't dispatch after destruction
        methodChannel.setMethodCallHandler(null)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Channel setup
    // ──────────────────────────────────────────────────────────────────────────

    private fun setupEventChannel() {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                Log.d(TAG, "EventChannel: Flutter is listening")
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "EventChannel: Flutter cancelled stream")
                eventSink = null
            }
        })
    }

    private fun setupMethodChannel() {
        methodChannel.setMethodCallHandler { call, result ->
            Log.d(TAG, "MethodChannel ← ${call.method}")

            when (call.method) {

                // ── checkSupport ─────────────────────────────────────────────
                // Blocking hardware query — run on IO, return result on Main.
                DualCameraConstants.METHOD_CHECK_SUPPORT -> {
                    scope.launch(Dispatchers.IO) {
                        val supported = recorder.isConcurrentCameraSupported()
                        if (!supported) {
                            pushEvent(DualCameraConstants.EVENT_TYPE_STATUS, DualCameraConstants.STATUS_UNSUPPORTED)
                        }
                        // Reply on Main thread (required by Flutter MethodChannel)
                        launch(Dispatchers.Main) {
                            result.success(supported)
                        }
                    }
                }

                // ── startRecording ───────────────────────────────────────────
                DualCameraConstants.METHOD_START_RECORDING -> {
                    val outputPath = call.argument<String>(DualCameraConstants.ARG_OUTPUT_PATH)
                    if (outputPath.isNullOrBlank()) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "outputPath is required and cannot be blank",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val outputFile = File(outputPath)
                    // Ensure parent directories exist
                    outputFile.parentFile?.mkdirs()

                    recorder.startRecording(outputFile)
                    result.success(null)
                }

                // ── stopRecording ────────────────────────────────────────────
                DualCameraConstants.METHOD_STOP_RECORDING -> {
                    recorder.stopRecording()
                    result.success(null)
                }

                // ── pausePreview ───────────────────────────────────────────
                // Triggered by Flutter WidgetsBindingObserver when app goes
                // to background. Stops any active recording, then drops the
                // CameraX lifecycle to STARTED to release the camera sensor.
                DualCameraConstants.METHOD_PAUSE_PREVIEW -> {
                    recorder.pausePreview()
                    result.success(null)
                }

                // ── resumePreview ──────────────────────────────────────────
                // Triggered by Flutter WidgetsBindingObserver when app returns
                // to foreground. Restores the lifecycle to RESUMED so CameraX
                // re-opens the sensors and renders frames to PreviewView again.
                DualCameraConstants.METHOD_RESUME_PREVIEW -> {
                    recorder.resumePreview()
                    result.success(null)
                }

                else -> {
                    Log.w(TAG, "Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Recorder callbacks → EventChannel push
    // ──────────────────────────────────────────────────────────────────────────

    private fun setupRecorderCallbacks() {
        recorder.statusCallback = { status ->
            Log.d(TAG, "Recorder status: $status")
            pushEvent(DualCameraConstants.EVENT_TYPE_STATUS, status)
        }

        recorder.errorCallback = { message ->
            Log.e(TAG, "Recorder error: $message")
            pushEvent(DualCameraConstants.EVENT_TYPE_ERROR, message)
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Event push helper
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Pushes a typed event to the Flutter EventChannel sink.
     *
     * Event map structure:
     *   {
     *     "type"    : String  — [DualCameraConstants.EVENT_TYPE_STATUS] or EVENT_TYPE_ERROR
     *     "payload" : String  — the status value or error message
     *   }
     */
    private fun pushEvent(type: String, payload: String) {
        eventSink?.success(
            mapOf(
                DualCameraConstants.EVENT_KEY_TYPE    to type,
                DualCameraConstants.EVENT_KEY_PAYLOAD to payload,
            )
        )
    }
}
