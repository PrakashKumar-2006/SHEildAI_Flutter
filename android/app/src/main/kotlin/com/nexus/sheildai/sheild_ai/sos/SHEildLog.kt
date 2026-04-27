package com.nexus.sheildai.sheild_ai.sos

import android.util.Log
import java.util.concurrent.atomic.AtomicLong

/**
 * SHEildLog — Structured logging for the SHEild AI SOS system.
 *
 * Why a wrapper?
 *  All SOS log lines are prefixed with [SHEildAI] so you can filter the
 *  entire SOS subsystem with a single adb command:
 *
 *    adb logcat -s SHEildAI
 *
 * Session timestamps let you correlate events even when system timestamps
 * are not aligned:
 *
 *    [SHEildAI] [+04.312s] MILESTONE | SosManager | BUFFER → RECORDING_AUDIO
 *
 * Usage:
 *    SHEildLog.i("SosManager", "Buffer started — ${bufferMs}ms")
 *    SHEildLog.milestone("SosManager", "IDLE → TRIGGERED")
 *    SHEildLog.v("VoiceDetectionService", "Vosk result: \"help\"")  // debug only
 */
object SHEildLog {

    /** Master logcat tag — use this in `adb logcat -s SHEildAI`. */
    const val TAG = "SHEildAI"

    /** Marks the beginning of the current SOS session for elapsed-time logs. */
    private val sessionStartMs = AtomicLong(0L)

    // ─── Session lifecycle ────────────────────────────────────────────────────

    /** Call when an SOS session begins (TRIGGERED state). */
    fun startSession() {
        sessionStartMs.set(System.currentTimeMillis())
        milestone("Session", "══════════ SOS SESSION STARTED ══════════")
    }

    /** Call when a session ends (IDLE state). */
    fun endSession() {
        milestone("Session", "══════════ SOS SESSION ENDED   ══════════")
        sessionStartMs.set(0L)
    }

    // ─── Log methods ──────────────────────────────────────────────────────────

    fun v(component: String, msg: String) {
        Log.v(TAG, format(component, msg))
    }

    fun d(component: String, msg: String) {
        Log.d(TAG, format(component, msg))
    }

    fun i(component: String, msg: String) {
        Log.i(TAG, format(component, msg))
    }

    fun w(component: String, msg: String) {
        Log.w(TAG, format(component, msg))
    }

    fun e(component: String, msg: String, throwable: Throwable? = null) {
        if (throwable != null) {
            Log.e(TAG, format(component, msg), throwable)
        } else {
            Log.e(TAG, format(component, msg))
        }
    }

    /**
     * Logs a high-visibility milestone event.
     * Format: [SHEildAI] [+XX.XXXs] MILESTONE | <component> | <msg>
     *
     * These are always logged (not DEBUG-gated) and are the primary
     * events visible in `adb logcat -s SHEildAI`.
     */
    fun milestone(component: String, msg: String) {
        Log.i(TAG, "${elapsed()} MILESTONE | $component | $msg")
    }

    /**
     * Logs a state transition in a consistent, grep-able format.
     * Format: [SHEildAI] [+XX.XXXs] TRANSITION | <component> | <from> → <to>
     */
    fun transition(component: String, from: String, to: String) {
        Log.i(TAG, "${elapsed()} TRANSITION | $component | $from → $to")
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    private fun format(component: String, msg: String): String {
        return "${elapsed()} $component | $msg"
    }

    private fun elapsed(): String {
        val start = sessionStartMs.get()
        return if (start == 0L) {
            "[---.---s]"
        } else {
            val ms = System.currentTimeMillis() - start
            val secs = ms / 1000.0
            "[%07.3fs]".format(secs)
        }
    }
}
