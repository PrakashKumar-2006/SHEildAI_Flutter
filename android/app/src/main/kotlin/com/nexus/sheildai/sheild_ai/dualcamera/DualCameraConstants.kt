package com.nexus.sheildai.sheild_ai.dualcamera

/**
 * Centralised constants for the Flutter ↔ Native dual-camera bridge.
 *
 * ─────────────────────────────────────────────────────────────────────────
 *  CHANNELS
 * ─────────────────────────────────────────────────────────────────────────
 *  [METHOD_CHANNEL]   — Flutter sends commands to Native (start / stop / check)
 *  [EVENT_CHANNEL]    — Native pushes recording status & errors to Flutter
 *  [VIEW_TYPE_ID]     — Identifier used to register the PlatformView factory
 *
 * ─────────────────────────────────────────────────────────────────────────
 *  METHOD CHANNEL CALLS  (Flutter → Native)
 * ─────────────────────────────────────────────────────────────────────────
 *  [METHOD_CHECK_SUPPORT]    — Returns Boolean: true if device supports
 *                              concurrent front+back camera streaming.
 *  [METHOD_START_RECORDING]  — Starts the dual-camera recording session.
 *                              Required argument:
 *                                "outputPath" : String — absolute file path
 *                                               for the output .mp4 file.
 *  [METHOD_STOP_RECORDING]   — Stops the active recording and finalises
 *                              the output file at the path passed to start.
 *
 * ─────────────────────────────────────────────────────────────────────────
 *  EVENT CHANNEL EVENTS  (Native → Flutter)
 * ─────────────────────────────────────────────────────────────────────────
 *  Events are sent as Map<String, Any?>:
 *    "type"    : String  — one of [EVENT_TYPE_STATUS] | [EVENT_TYPE_ERROR]
 *    "payload" : Any?    — status string (see STATUS_* constants) or error
 *                          message string for errors.
 *
 * ─────────────────────────────────────────────────────────────────────────
 *  STATUS PAYLOADS  (inside EVENT_TYPE_STATUS events)
 * ─────────────────────────────────────────────────────────────────────────
 *  [STATUS_INITIALISING]  — Cameras are opening and compositor is setting up.
 *  [STATUS_RECORDING]     — Active recording is in progress.
 *  [STATUS_STOPPED]       — Recording stopped and file is saved to outputPath.
 *  [STATUS_UNSUPPORTED]   — Device does not support concurrent camera access.
 */
object DualCameraConstants {

    // ──────────────────────────────────────────────────────────────────────
    // Channel identifiers
    // ──────────────────────────────────────────────────────────────────────

    /** MethodChannel for Flutter UI → Native command dispatch. */
    const val METHOD_CHANNEL = "com.nexus.sheildai/dual_camera"

    /** EventChannel for Native → Flutter status/error push events. */
    const val EVENT_CHANNEL = "com.nexus.sheildai/dual_camera_events"

    /** PlatformView type identifier used in FlutterPlugin registration. */
    const val VIEW_TYPE_ID = "com.nexus.sheildai/dual_camera_view"

    // ──────────────────────────────────────────────────────────────────────
    // MethodChannel method names (Flutter → Native)
    // ──────────────────────────────────────────────────────────────────────

    /** Check if the current device hardware supports concurrent dual-camera. */
    const val METHOD_CHECK_SUPPORT = "checkSupport"

    /**
     * Start dual-camera recording.
     * Required Flutter argument: "outputPath" : String
     */
    const val METHOD_START_RECORDING = "startRecording"

    /** Stop the current dual-camera recording and flush the output file. */
    const val METHOD_STOP_RECORDING = "stopRecording"

    /**
     * Pause the camera preview streams (called when the app goes to background).
     * Recording is stopped before pausing to avoid a corrupt output file.
     */
    const val METHOD_PAUSE_PREVIEW = "pausePreview"

    /**
     * Resume the camera preview streams (called when the app returns to foreground).
     * Does NOT automatically restart a recording — the Flutter side must call
     * [METHOD_START_RECORDING] again if needed.
     */
    const val METHOD_RESUME_PREVIEW = "resumePreview"

    // ──────────────────────────────────────────────────────────────────────
    // EventChannel event type keys
    // ──────────────────────────────────────────────────────────────────────

    /** Key in the event map that identifies the event type. */
    const val EVENT_KEY_TYPE = "type"

    /** Key in the event map that carries the event payload (String). */
    const val EVENT_KEY_PAYLOAD = "payload"

    /** Event type: a recording status update (use STATUS_* constants). */
    const val EVENT_TYPE_STATUS = "status"

    /** Event type: an error has occurred. Payload is the error message. */
    const val EVENT_TYPE_ERROR = "error"

    // ──────────────────────────────────────────────────────────────────────────
    // Error codes (sent as PlatformException codes via MethodChannel)
    // ──────────────────────────────────────────────────────────────────────────

    /** The CAMERA permission has not been granted by the user. */
    const val ERROR_CAMERA_PERMISSION = "CAMERA_PERMISSION_DENIED"

    /** The RECORD_AUDIO permission has not been granted by the user. */
    const val ERROR_AUDIO_PERMISSION = "AUDIO_PERMISSION_DENIED"

    /** The camera hardware does not support concurrent front+back access. */
    const val ERROR_NOT_SUPPORTED = "NOT_SUPPORTED"

    /** A camera or recording error occurred. Check the message for details. */
    const val ERROR_CAMERA_ERROR = "CAMERA_ERROR"

    // ──────────────────────────────────────────────────────────────────────
    // Status payload values (used inside EVENT_TYPE_STATUS events)
    // ──────────────────────────────────────────────────────────────────────

    /** Cameras are opening and the compositor pipeline is being set up. */
    const val STATUS_INITIALISING = "initialising"

    /** Active dual-camera recording is in progress. */
    const val STATUS_RECORDING = "recording"

    /** Recording has been stopped and the output file is finalised. */
    const val STATUS_STOPPED = "stopped"

    /** Device hardware does not support concurrent front+back camera access. */
    const val STATUS_UNSUPPORTED = "unsupported"

    // ──────────────────────────────────────────────────────────────────────
    // Video composition constants
    // ──────────────────────────────────────────────────────────────────────

    /**
     * Target output width in pixels.
     * Combined output video will be 720 × 1440 (1:2 portrait aspect ratio),
     * with each camera occupying a 720 × 720 square (1:1) half.
     */
    const val OUTPUT_WIDTH_PX = 720

    /**
     * Target output height per camera half.
     * Each camera stream is scaled to fill a 720 × 720 square region.
     */
    const val OUTPUT_HALF_HEIGHT_PX = 720

    /**
     * Total output video height = two camera halves stacked vertically.
     * Front camera: Y range [0, 720]. Rear camera: Y range [720, 1440].
     */
    const val OUTPUT_TOTAL_HEIGHT_PX = OUTPUT_HALF_HEIGHT_PX * 2  // 1440

    // ──────────────────────────────────────────────────────────────────────
    // MethodChannel argument keys
    // ──────────────────────────────────────────────────────────────────────

    /** Argument key for the output file path passed to [METHOD_START_RECORDING]. */
    const val ARG_OUTPUT_PATH = "outputPath"
}
