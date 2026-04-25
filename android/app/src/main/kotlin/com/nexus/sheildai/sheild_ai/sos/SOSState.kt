package com.nexus.sheildai.sheild_ai.sos

/**
 * SOSState — All possible states in the SOS session lifecycle.
 *
 * State transition graph:
 *
 *   IDLE ──[triggerSOS]──► TRIGGERED ──[auto: 1s]──► BUFFER
 *                                                        │
 *                                          [buffer window: 3s cancel OR auto-proceed]
 *                                                        │
 *                                                  RECORDING_AUDIO
 *                                                        │
 *                                             [auto: after audio clip]
 *                                                        │
 *                                                 RECORDING_VIDEO
 *                                                        │
 *                                          [endSession() from any active state]
 *                                                        │
 *                                                     STOPPED
 *                                                        │
 *                                             [startCooldown(): 60s]
 *                                                        │
 *                                                    COOLDOWN
 *                                                        │
 *                                             [cooldown expires]
 *                                                        │
 *                                                      IDLE  ◄──────────────┘
 *
 * Guard rule: Any call to triggerSOS() when state ≠ IDLE is silently rejected.
 */
enum class SOSState {

    /**
     * Default resting state. SOS can only be triggered from here.
     */
    IDLE,

    /**
     * SOS has been requested. Validation checks run here
     * (permissions, connectivity, foreground/background).
     * Transitions to BUFFER automatically after ~1 second.
     */
    TRIGGERED,

    /**
     * Short window (default 3 seconds) where the user can cancel.
     * A countdown notification is shown.
     * If not cancelled, proceeds to RECORDING_AUDIO.
     */
    BUFFER,

    /**
     * Audio recording active. Captures ambient sound as evidence.
     * Runs for a configurable duration (default 30s).
     * Transitions to RECORDING_VIDEO after clip is saved.
     */
    RECORDING_AUDIO,

    /**
     * Video recording active. Camera evidence is being captured.
     * Continues until endSession() is called or max duration reached.
     */
    RECORDING_VIDEO,

    /**
     * SOS session has ended (manually or automatically).
     * Resources are released. Transitions to COOLDOWN.
     */
    STOPPED,

    /**
     * Cooldown period (60 seconds) to prevent accidental re-triggers.
     * Returns to IDLE once the timer expires.
     *
     * Voice detection resumes automatically when IDLE is restored.
     */
    COOLDOWN;

    // ─── Utility extensions ──────────────────────────────────────────────────

    /** Returns true if an active SOS session is in progress. */
    val isActive: Boolean
        get() = this in setOf(TRIGGERED, BUFFER, RECORDING_AUDIO, RECORDING_VIDEO)

    /** Returns true if a new SOS can be triggered. */
    val canTrigger: Boolean
        get() = this == IDLE

    /** Human-readable label for logs and debug UI. */
    val displayName: String
        get() = when (this) {
            IDLE            -> "Idle"
            TRIGGERED       -> "Triggered"
            BUFFER          -> "Buffer (cancel window)"
            RECORDING_AUDIO -> "Recording Audio"
            RECORDING_VIDEO -> "Recording Video"
            STOPPED         -> "Stopped"
            COOLDOWN        -> "Cooldown"
        }
}
