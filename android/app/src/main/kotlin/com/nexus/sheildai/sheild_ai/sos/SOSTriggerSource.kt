package com.nexus.sheildai.sheild_ai.sos

/**
 * SOSTriggerSource — Identifies how an SOS session was initiated.
 *
 * Used for:
 *  - Logging and analytics (which trigger paths are most common)
 *  - Controlling buffer duration per source (see [bufferWindowMs])
 *  - Backend telemetry payloads
 */
sealed class SOSTriggerSource {

    /** User tapped the SOS button manually in the UI. */
    data object Button : SOSTriggerSource()

    /** Wake word detected by the voice engine ("help", "SOS", "emergency", etc.). */
    data class Voice(val keyword: String) : SOSTriggerSource()

    /** Device shake pattern detected (future implementation). */
    data object Shake : SOSTriggerSource()

    /** Triggered automatically by the system (e.g., geofence, inactivity timer). */
    data class Auto(val reason: String) : SOSTriggerSource()

    // ─── Utility ─────────────────────────────────────────────────────────────

    /** Human-readable label for logs. */
    val displayName: String
        get() = when (this) {
            is Button -> "Manual Button"
            is Voice  -> "Voice: \"${this.keyword}\""
            is Shake  -> "Shake Detection"
            is Auto   -> "Auto: ${this.reason}"
        }

    /**
     * Buffer window for this trigger source (milliseconds).
     *
     * This value has two different meanings depending on the source:
     *
     * BUTTON / SHAKE / AUTO:
     *   → Human cancel window. The user (or system) gets this many ms to abort
     *     the SOS before recording and SMS begin. Longer = more "undo" time.
     *
     * VOICE:
     *   → Mic handoff buffer ONLY. When Vosk detects "help", VoiceDetectionService
     *     still holds AudioSource.MIC. MediaRecorder cannot open the same source
     *     simultaneously — it needs ~1s for the AudioRecord to fully release.
     *     There is NO cancel window for voice: if the user said "help" deliberately,
     *     they want instant action. False positives are already filtered by Vosk's
     *     keyword model before triggerSOS() is ever called.
     *
     * Timeline comparison:
     *   Voice  → 0s validation + 1s mic handoff → SMS/audio starts  (~1s total)
     *   Button → 1s validation + 3s cancel window → SMS/audio starts (~4s total)
     */
    val bufferWindowMs: Long
        get() = when (this) {
            is Voice  -> 1_000L   // 1s — Vosk mic handoff only; no cancel window
            is Button -> 3_000L   // 3s — human cancel window
            is Shake  -> 4_000L   // 4s — shake is easy to trigger accidentally
            is Auto   -> 2_000L   // 2s — system-initiated; shorter is fine
        }
}
