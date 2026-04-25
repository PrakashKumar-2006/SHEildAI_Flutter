package com.nexus.sheildai.sheild_ai.sos

import android.app.ActivityManager
import android.content.Context
import android.os.PowerManager
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * SOSManager — Centralized SOS state machine (singleton).
 *
 * This is the single authority for all SOS lifecycle transitions.
 * Trigger sources (button, voice, shake, auto) all call [triggerSOS] directly.
 * SOSManager orchestrates [AudioRecordingService], [VideoRecordingService],
 * [SmsHelper], [SOSEventChannel], and [SosService] internally.
 *
 * [SosService] is activated as a session keepalive foreground service at trigger
 * time and deactivated when the session ends. Its sole job is keeping the process
 * alive in the OS foreground tier (dataSync type, API-34 background-safe) so this
 * object's [scope] and [smsJob] coroutines cannot be killed by Android's LMK.
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │  Thread safety: state transitions use AtomicReference.         │
 * │  Timers: run on a SupervisorJob coroutine scope (non-blocking). │
 * │  Guards: duplicate triggers are rejected and logged as warnings.│
 * └─────────────────────────────────────────────────────────────────┘
 *
 * Public API (called from platform channel):
 *   SOSManager.triggerSOS(context, source)
 *   SOSManager.endSession(context)
 *   SOSManager.cancelBuffer(context)
 *   SOSManager.currentState()
 */
object SOSManager {

    // ─── Constants ───────────────────────────────────────────────────────────

    private const val TAG = "SOSManager"

    /** Delay between TRIGGERED → BUFFER (validation phase). */
    private const val TRIGGER_TO_BUFFER_DELAY_MS = 1_000L

    /** Cooldown period after a session ends before IDLE is restored. */
    private const val COOLDOWN_DURATION_MS = 3_000L


    // ─── State ───────────────────────────────────────────────────────────────

    /**
     * Current SOS state, held atomically so reads from any thread are consistent.
     * Transitions are always performed on the coroutine dispatcher.
     */
    private val _state = AtomicReference(SOSState.IDLE)

    /** The trigger that initiated the current/last session (null when IDLE). */
    private var _triggerSource: SOSTriggerSource? = null

    /** Timestamp (ms) when the current session was initiated. */
    private var _sessionStartMs: Long = 0L

    /**
     * Emergency contacts captured at trigger time.
     * Populated from the Flutter platform channel (primary) or SOSStateStore
     * (Flutter prefs → native cache fallback). Empty if the user has not set up contacts.
     */
    private var _pendingContacts: List<String> = emptyList()

    // ─── Coroutine plumbing ──────────────────────────────────────────────────

    /**
     * Supervisor scope — child job failures don't cancel siblings.
     * Using [Dispatchers.Default] for CPU-bound state transitions;
     * IO-heavy work (recording, upload) will use [Dispatchers.IO] in Phase 2.
     */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    /** Handle to the active buffer-window timer (so it can be cancelled on manual cancel). */
    private var bufferJob: Job? = null

    /** Handle to the active cooldown timer. */
    private var cooldownJob: Job? = null

    /** Handle to the location+SMS dispatch job (cancelled on early endSession). */
    private var smsJob: Job? = null

    /**
     * One-shot SMS guard — ensures emergency SMS is dispatched at most ONCE per SOS session.
     *
     * Set to `true` atomically by [dispatchEmergencySms] via [AtomicBoolean.compareAndSet].
     * Only the first caller whose CAS succeeds (false → true) proceeds to send.
     * Any subsequent call (race condition, duplicate trigger, or future code path) is
     * logged and discarded without touching SmsManager.
     *
     * Reset to `false` at the end of [startCooldown] so the next SOS session starts clean.
     */
    private val _smsSentForSession = AtomicBoolean(false)

    /**
     * Capture context stored at trigger time.
     * Needed so [endSession] / [cancelBuffer] can stop services without a fresh context.
     * Cleared on COOLDOWN → IDLE.
     */
    private var _sessionContext: Context? = null

    /**
     * Application context injected via [init]. Used for SharedPreferences persistence
     * without requiring a context parameter on every state transition.
     */
    @Volatile private var _appContext: Context? = null

    /** True after [init] has completed crash-recovery. Prevents double-init. */
    @Volatile private var _initialized = false

    // ═════════════════════════════════════════════════════════════════════════
    // INITIALISATION — crash-recovery
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * One-time initialisation — inject [context] and recover from a possible
     * mid-session process death.
     *
     * Must be called from [com.nexus.sheildai.sheild_ai.MainActivity.onCreate].
     * Subsequent calls are no-ops.
     *
     * Recovery policy (Phase 4):
     *  - TRIGGERED / BUFFER → always hard reset (too ephemeral to resume)
     *  - RECORDING_AUDIO / RECORDING_VIDEO + age < 10 min → restore session;
     *    re-emit state event so Flutter UI can reconcile without a blank/idle screen
     *  - RECORDING_AUDIO / RECORDING_VIDEO + age >= 10 min → hard reset + clear notification
     *  - COOLDOWN → resume remaining timer if not yet expired; otherwise restore IDLE
     *  - STOPPED / IDLE → restore IDLE, clear session
     *
     * Hard reset always calls [SOSPersistentNotification.clear] so the notification
     * is never left dangling after a stale state wipe.
     */
    fun init(context: Context) {
        if (_initialized) return
        _initialized = true
        _appContext = context.applicationContext
        recoverStateFromPrefs(context)
        prewarmContactsCache(context.applicationContext)
        startVoiceWatchdog(context.applicationContext)
    }

    private fun recoverStateFromPrefs(context: Context) {
        val persisted = SOSStateStore.loadState(context)
        val startMs   = SOSStateStore.loadSessionStartMs(context)
        val ageMs     = System.currentTimeMillis() - startMs

        /** Grace window: if a recording session is younger than this, we resume it. */
        val RECORDING_GRACE_MS = 10 * 60 * 1000L // 10 minutes

        when {
            // ── Pre-recording states (TRIGGERED / BUFFER) ─────────────────────
            // These are ephemeral phases that last only 1–6 seconds in normal flow.
            // Finding them persisted after a restart always means the process died
            // mid-transition. Hard reset — there is nothing worth resuming.
            persisted == SOSState.TRIGGERED || persisted == SOSState.BUFFER -> {
                Log.w(TAG, "⚠️ Stale pre-recording state [${persisted.displayName}] " +
                        "(${ageMs}ms ago) — hard resetting to IDLE")
                hardReset(context)
            }

            // ── Recording states (RECORDING_AUDIO / RECORDING_VIDEO) ──────────
            // The session was alive and recording when the process died.
            // With Phase 2 (SosService keepalive), this path is rare but still
            // possible (OEM force-kill, power cycle mid-session, etc.).
            //
            // Grace window: if the session started < 10 minutes ago, restore it
            // so the Flutter UI can show the active SOS screen and let the user
            // press "I'm Safe" cleanly.
            //
            // Beyond 10 minutes: definitely stale (user force-killed or rebooted).
            // Hard reset and clear the orphaned notification.
            persisted == SOSState.RECORDING_AUDIO || persisted == SOSState.RECORDING_VIDEO -> {
                if (ageMs <= RECORDING_GRACE_MS) {
                    Log.i(TAG, "♻️ Recovering mid-session state [${persisted.displayName}] " +
                            "(${ageMs / 1000}s ago) — restoring for UI reconciliation")
                    _state.set(persisted)
                    _sessionStartMs = startMs
                    _pendingContacts = SOSStateStore.loadTrustedContacts(context)

                    // Re-emit the state to Flutter so the SOS screen reflects reality
                    // (the app may have been relaunched after the process death).
                    emitEventForState(persisted)

                    Log.i(TAG, "✅ Session state restored — Flutter UI can reconcile")
                } else {
                    Log.w(TAG, "⚠️ Stale recording state [${persisted.displayName}] " +
                            "(${ageMs / 1000}s ago, > ${RECORDING_GRACE_MS / 60000}min grace) — hard resetting")
                    hardReset(context)
                }
            }

            // ── COOLDOWN — may still be partially active ───────────────────────
            persisted == SOSState.COOLDOWN -> {
                val remaining = COOLDOWN_DURATION_MS - ageMs
                if (remaining <= 0) {
                    Log.i(TAG, "Persisted COOLDOWN already expired — restoring IDLE")
                    _state.set(SOSState.IDLE)
                    SOSStateStore.clearSession(context)
                } else {
                    Log.i(TAG, "Resuming COOLDOWN — ${remaining}ms remaining")
                    _state.set(SOSState.COOLDOWN)
                    scope.launch {
                        delay(remaining)
                        transitionTo(SOSState.IDLE)
                        SOSStateStore.clearSession(context)
                        Log.i(TAG, "✅ Recovered cooldown complete — system ready")
                    }
                }
            }

            // ── STOPPED — cooldown never ran ───────────────────────────────────
            persisted == SOSState.STOPPED -> {
                Log.i(TAG, "Persisted STOPPED state — restoring IDLE")
                _state.set(SOSState.IDLE)
                SOSStateStore.clearSession(context)
            }

            // ── IDLE or anything else — nothing to recover ─────────────────────
            else -> {
                Log.d(TAG, "Persisted state [${persisted.displayName}] — no recovery needed")
            }
        }
    }

    /**
     * Hard-resets SOSManager to IDLE and clears all persisted session data.
     *
     * Also cancels the persistent lock-screen notification so the UI never shows
     * "SOS Active" when the state is truly IDLE (notification/state desync prevention).
     */
    private fun hardReset(context: Context) {
        _state.set(SOSState.IDLE)
        SOSStateStore.clearSession(context)
        SOSPersistentNotification.clear(context)
        Log.i(TAG, "🔄 Hard reset complete — state: IDLE, notification cleared")
    }

    /**
     * Reads the trusted contacts from Flutter SharedPreferences and writes them
     * to the native contacts cache ([SOSStateStore.cacheTrustedContacts]).
     *
     * Called once at [init] time on every app launch.
     *
     * WHY this is needed for voice-triggered SOS:
     * ──────────────────────────────────────────
     * When Flutter calls "startSOS" via the button, [MainActivity.registerSOSChannel]
     * calls [SOSStateStore.cacheTrustedContacts] — so the native cache is always up-to-date
     * after a button trigger.
     *
     * But voice-triggered SOS bypasses the button entirely. [VoiceDetectionService] calls
     * [triggerSOS] with no contacts, and the fallback chain inside [triggerSOS] reads
     * [SOSStateStore.loadTrustedContacts] — which first tries Flutter prefs, then the
     * native cache.
     *
     * Problem: if the user has never pressed the button, the native cache is empty AND
     * the Flutter prefs may not be readable if the Flutter engine isn't warm (the
     * FlutterSharedPreferences file exists on disk, but is only guaranteed readable when
     * Flutter has initialised at least once). Pre-warming here on every app start ensures
     * the native cache is always in sync with whatever contacts the user has saved.
     */
    private fun prewarmContactsCache(context: Context) {
        val contacts = SOSStateStore.loadTrustedContacts(context)
        if (contacts.isNotEmpty()) {
            SOSStateStore.cacheTrustedContacts(context, contacts)
            Log.i(TAG, "📋 Pre-warmed native contacts cache: ${contacts.size} contact(s) mirrored from Flutter prefs")
        } else {
            Log.w(TAG, "⚠️ Pre-warm: no contacts found in Flutter prefs or native cache — voice SOS will skip SMS until contacts are configured")
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PUBLIC API
    // ════════════════════════════════════════════════════════════════════════=

    /**
     * Initiates an SOS session.
     *
     * Guard: if state is not [SOSState.IDLE], the call is rejected with a warning log.
     *
     * @param context  Android context (used for foreground detection + GPS + SMS).
     * @param source   How the SOS was triggered (button, voice, shake, auto).
     * @param contacts Phone numbers to SMS. Falls back to SOSStateStore (Flutter prefs →
     *                 native cache) if empty. SMS is skipped if no contacts are found.
     */
    fun triggerSOS(
        context: Context,
        source: SOSTriggerSource,
        contacts: List<String> = emptyList()
    ) {
        val current = _state.get()

        // ── State guard ──────────────────────────────────────────────────────
        if (!current.canTrigger) {
            Log.w(
                TAG,
                "triggerSOS() rejected — current state is [${current.displayName}]. " +
                        "Source: ${source.displayName}"
            )
            return
        }

        // ── Capture session metadata ─────────────────────────────────────────
        _triggerSource = source
        _sessionStartMs = System.currentTimeMillis()
        
        // Priority:
        // 1. Explicitly passed contacts (from Flutter MethodChannel — most trusted source)
        // 2. Flutter SharedPreferences → native cache fallback (via SOSStateStore)
        //
        // ⚠️ There is NO hardcoded fallback to emergency service numbers (100, 1091, etc.).
        // SMS will only be sent to contacts the user has explicitly registered.
        // If no contacts are found, we log an error and the SMS dispatch will be skipped.
        val savedContacts = SOSStateStore.loadTrustedContacts(context)
        _pendingContacts = contacts.ifEmpty { savedContacts }

        if (_pendingContacts.isEmpty()) {
            Log.e(TAG, "⚠️ No trusted contacts configured — SMS will not be sent. " +
                    "User must add emergency contacts in the app.")
        }
        
        _sessionContext = context.applicationContext // store for later cleanup

        val isForegrounded = isAppInForeground(context)

        Log.i(TAG, "══════════════════════════════════════════")
        Log.i(TAG, "  🆘 SOS TRIGGERED")
        Log.i(TAG, "  Source   : ${source.displayName}")
        Log.i(TAG, "  App      : ${if (isForegrounded) "Foreground" else "Background"}")
        Log.i(TAG, "  Buffer   : ${source.bufferWindowMs}ms cancel window")
        Log.i(TAG, "  Contacts : ${_pendingContacts.size} loaded")
        Log.i(TAG, "  SMS perm : ${SmsHelper.hasSmsPermission(context)}")
        Log.i(TAG, "  GPS perm : ${LocationProvider.hasLocationPermission(context)}")
        Log.i(TAG, "══════════════════════════════════════════")

        // ── Transition: IDLE → TRIGGERED ─────────────────────────────────────
        transitionTo(SOSState.TRIGGERED)

        // ── Start OS-level session keepalive (Phase 2) ────────────────────────
        // SosService uses foregroundServiceType="dataSync" which Android 14 allows
        // starting from background while VoiceDetectionService is already running.
        // This anchors the process in the LMK foreground tier so the SMS coroutine
        // below cannot be killed before it finishes dispatching.
        SosService.startSos(context.applicationContext)

        scope.launch {
            // ── Source-aware validation delay (Phase 3) ───────────────────────
            // For Voice: Vosk's AudioRecord release begins at trigger time.
            // The 1s in bufferWindowMs already covers the mic handoff hardware
            // constraint. Skipping the validation delay here means SMS dispatches
            // in ~1s from "help" instead of ~6s (1s validation + 5s buffer).
            //
            // For all other sources: the 1s gives the UI time to render the
            // cancel countdown before we transition to BUFFER.
            val validationDelay = if (source is SOSTriggerSource.Voice) 0L else TRIGGER_TO_BUFFER_DELAY_MS
            if (validationDelay > 0L) delay(validationDelay)

            // If session was cancelled during the validation delay, abort
            if (_state.get() != SOSState.TRIGGERED) {
                Log.d(TAG, "State changed during validation delay — aborting buffer entry")
                return@launch
            }

            // ── Transition: TRIGGERED → BUFFER ───────────────────────────────
            transitionTo(SOSState.BUFFER)
            Log.i(TAG, "⏳ Buffer window open for ${source.bufferWindowMs}ms (${source.displayName})")

            // Start the cancel-window timer
            bufferJob = scope.launch {
                delay(source.bufferWindowMs)

                if (_state.get() != SOSState.BUFFER) {
                    Log.d(TAG, "State changed during buffer — aborting escalation")
                    return@launch
                }

                // ── Transition: BUFFER → RECORDING_AUDIO ─────────────────────
                transitionTo(SOSState.RECORDING_AUDIO)

                val isBg = !isAppInForeground(context)
                Log.i(TAG, "🎙️ Audio recording starting (${if (isBg) "background" else "foreground"} mode)")

                // Start the foreground microphone recording service.
                // The service handles its own 5-minute limit and wake lock.
                AudioRecordingService.startRecording(context)

                // If app is in the foreground, escalate to video after mic handoff.
                // The 1-second delay lets AudioRecordingService fully release the mic
                // before CameraX opens the same hardware resource.
                if (isAppInForeground(context)) {
                    Log.i(TAG, "📱 Foreground detected — scheduling video escalation in 1s")
                    scope.launch {
                        delay(1_000L)
                        if (_state.get() == SOSState.RECORDING_AUDIO) {
                            performVideoEscalation(context)
                        }
                    }
                }

                // ── Dispatch location + SMS concurrently (non-blocking) ────
                // Pass _appContext (application context stored at init time) to ensure
                // the SMS job always uses a non-Activity context, regardless of what
                // context was passed to triggerSOS() (e.g., from VoiceDetectionService
                // or from MainActivity — both are already applicationContext, but we
                // enforce it here defensively so future callers can't break this).
                val smsContext = _appContext ?: context.applicationContext
                smsJob = scope.launch(Dispatchers.IO) {
                    dispatchEmergencySms(smsContext)
                }
            }
        }
    }

    /**
     * Cancels the active buffer window without escalating to recording.
     * Only valid when state is [SOSState.BUFFER].
     *
     * This is called when the user taps "Cancel" during the countdown.
     */
    fun cancelBuffer(context: Context) {
        val current = _state.get()

        if (current != SOSState.BUFFER) {
            Log.w(TAG, "cancelBuffer() ignored — not in BUFFER state (current: ${current.displayName})")
            return
        }

        bufferJob?.cancel()
        bufferJob = null

        // Stop recording services and the session keepalive anchor
        AudioRecordingService.stopRecording(context)
        VideoRecordingService.stopRecording(context)
        SosService.stopSos(context.applicationContext)

        Log.i(TAG, "❌ SOS cancelled by user during buffer window")
        transitionTo(SOSState.STOPPED)
        startCooldown()
    }

    /**
     * Ends an active SOS session from any active state.
     *
     * Valid from: [SOSState.TRIGGERED], [SOSState.BUFFER],
     *             [SOSState.RECORDING_AUDIO], [SOSState.RECORDING_VIDEO].
     *
     * @param context Android context (passed to future service teardown calls).
     */
    fun endSession(context: Context) {
        val current = _state.get()

        if (!current.isActive) {
            Log.w(TAG, "endSession() ignored — no active session (current: ${current.displayName})")
            return
        }

        // Cancel any pending timers
        bufferJob?.cancel()
        bufferJob = null
        smsJob?.cancel()
        smsJob = null

        // Stop both recording services (only active one will respond)
        AudioRecordingService.stopRecording(context)
        VideoRecordingService.stopRecording(context)

        // Stop the OS-level session keepalive anchor (Phase 2)
        SosService.stopSos(context.applicationContext)

        val durationMs = System.currentTimeMillis() - _sessionStartMs

        Log.i(TAG, "══════════════════════════════════════════")
        Log.i(TAG, "  ✅ SOS SESSION ENDED")
        Log.i(TAG, "  Duration : ${durationMs}ms")
        Log.i(TAG, "  Source   : ${_triggerSource?.displayName ?: "unknown"}")
        Log.i(TAG, "══════════════════════════════════════════")

        transitionTo(SOSState.STOPPED)
        startCooldown()
    }

    /**
     * Advances state RECORDING_AUDIO → RECORDING_VIDEO.
     *
     * Called automatically after 1s when app is in foreground,
     * or manually via the platform channel ("escalateVideo").
     *
     * Uses [_sessionContext] so no context parameter is needed from callers.
     */
    fun escalateToVideoRecording() {
        val ctx = _sessionContext ?: run {
            Log.e(TAG, "escalateToVideoRecording: no session context — was triggerSOS called?")
            return
        }
        performVideoEscalation(ctx)
    }

    /**
     * Internal escalation: stops audio, waits 1s, starts VideoRecordingService.
     * Only executes if currently in [SOSState.RECORDING_AUDIO].
     */
    private fun performVideoEscalation(context: Context) {
        if (_state.get() != SOSState.RECORDING_AUDIO) {
            Log.w(TAG, "performVideoEscalation: not in RECORDING_AUDIO — ignored")
            return
        }

        Log.i(TAG, "📹 Escalating to video recording")

        // Stop audio service to release the microphone
        AudioRecordingService.stopRecording(context)

        transitionTo(SOSState.RECORDING_VIDEO)

        // Start video service after mic handoff buffer
        scope.launch {
            delay(1_000L)
            Log.i(TAG, "🎥 Starting VideoRecordingService")
            VideoRecordingService.startRecording(context)
        }
    }

    /**
     * Returns the current [SOSState]. Safe to call from any thread.
     */
    fun currentState(): SOSState = _state.get()

    /**
     * Returns true if the app is currently in an active SOS session.
     */
    fun isSessionActive(): Boolean = _state.get().isActive

    // ═════════════════════════════════════════════════════════════════════════
    // INTERNAL — State transitions
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Atomically sets the new state and emits a structured log line.
     *
     * Format: [SOSManager] STATE CHANGE: OldState → NewState
     */
    private fun transitionTo(newState: SOSState) {
        val old = _state.getAndSet(newState)
        // Structured log — visible via: adb logcat -s SHEildAI
        SHEildLog.transition("SosManager", old.displayName, newState.displayName)
        Log.i(TAG, "STATE CHANGE: [${old.displayName}] → [${newState.displayName}]")

        // Persist every transition so crash-recovery can detect stale sessions.
        _appContext?.let { ctx ->
            SOSStateStore.saveState(ctx, newState, _sessionStartMs, _triggerSource?.displayName)
        }

        // Update lock-screen persistent notification.
        _appContext?.let { ctx ->
            SOSPersistentNotification.update(ctx, newState, _sessionStartMs)
        }

        // SHEildLog session lifecycle markers
        when (newState) {
            SOSState.TRIGGERED -> SHEildLog.startSession()
            SOSState.IDLE      -> SHEildLog.endSession()
            else               -> Unit
        }

        // Push real-time event to Flutter UI via EventChannel.
        emitEventForState(newState)
    }

    /**
     * Builds and dispatches an [SOSEventChannel] event for each state transition.
     * Payloads include metadata the Flutter countdown timers depend on.
     */
    private fun emitEventForState(state: SOSState) {
        when (state) {
            SOSState.TRIGGERED -> SOSEventChannel.send(
                SOSEventChannel.EVENT_SOS_STARTED,
                mapOf("source" to (_triggerSource?.displayName ?: "unknown"))
            )
            SOSState.BUFFER -> SOSEventChannel.send(
                SOSEventChannel.EVENT_BUFFER_STARTED,
                mapOf("bufferMs" to (_triggerSource?.bufferWindowMs ?: 3_000L))
            )
            SOSState.RECORDING_AUDIO -> SOSEventChannel.send(
                SOSEventChannel.EVENT_RECORDING_STARTED
            )
            SOSState.RECORDING_VIDEO -> SOSEventChannel.send(
                SOSEventChannel.EVENT_VIDEO_STARTED
            )
            SOSState.STOPPED -> {
                val durationMs = if (_sessionStartMs > 0L)
                    System.currentTimeMillis() - _sessionStartMs else 0L
                SOSEventChannel.send(
                    SOSEventChannel.EVENT_SESSION_ENDED,
                    mapOf("durationMs" to durationMs)
                )
            }
            SOSState.COOLDOWN -> SOSEventChannel.send(
                SOSEventChannel.EVENT_COOLDOWN_STARTED,
                mapOf("cooldownMs" to COOLDOWN_DURATION_MS)
            )
            SOSState.IDLE -> SOSEventChannel.send(
                SOSEventChannel.EVENT_IDLE
            )
        }
    }

    /**
     * Starts the cooldown timer (coroutine-based, non-blocking).
     * After [COOLDOWN_DURATION_MS], state returns to [SOSState.IDLE].
     */
    private fun startCooldown() {
        cooldownJob?.cancel()

        cooldownJob = scope.launch {
            transitionTo(SOSState.COOLDOWN)
            Log.i(TAG, "⏱️ Cooldown started — ${COOLDOWN_DURATION_MS / 1000}s until IDLE is restored")

            delay(COOLDOWN_DURATION_MS)

            // ── Reset one-shot SMS guard so the next SOS session can send SMS ─
            val wasSmsSent = _smsSentForSession.getAndSet(false)
            Log.d(TAG, "Cooldown complete — SMS guard reset (was: $wasSmsSent)")

            transitionTo(SOSState.IDLE)
            _triggerSource = null
            _sessionStartMs = 0L
            _pendingContacts = emptyList()
            _sessionContext = null

            // Clear persisted session so cold-start recovery sees a clean IDLE.
            _appContext?.let { SOSStateStore.clearSession(it) }

            Log.i(TAG, "✅ Cooldown complete — system ready for next SOS")
            cooldownJob = null
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // INTERNAL — Location + SMS dispatch
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Fetches the best available GPS location, then dispatches emergency SMS
     * to all [_pendingContacts].
     *
     * ONE-SHOT GUARANTEE
     * ------------------
     * Uses [_smsSentForSession].compareAndSet(false, true) so SMS is sent at most
     * once per SOS session, even if this function is called from multiple coroutines
     * simultaneously or future code inadvertently calls it twice.
     *
     * Only the first caller whose CAS succeeds proceeds. Any subsequent call is
     * logged as a duplicate and returns immediately — no SMS is sent.
     *
     * Runs on [Dispatchers.IO]. Never throws — all errors are caught and logged.
     *
     * Called only after the buffer cancel-window has expired, ensuring the user
     * had a chance to cancel before any message is sent.
     */
    private suspend fun dispatchEmergencySms(context: Context) {

        // ── Always use applicationContext — no Activity dependency ────────────
        // SmsManager, FusedLocationProviderClient, and ContextCompat.checkSelfPermission
        // all work correctly with applicationContext. This line is a defensive no-op
        // when context is already applicationContext, and a safety net otherwise.
        val appCtx = context.applicationContext

        // ── One-shot guard ─────────────────────────────────────────────────────
        // compareAndSet(expected=false, update=true) returns true ONLY for the
        // very first caller. All subsequent callers get false and are rejected.
        val isFirstDispatch = _smsSentForSession.compareAndSet(false, true)

        if (!isFirstDispatch) {
            Log.w(TAG, "🚫 dispatchEmergencySms — SMS already sent for this session, skipping duplicate dispatch")
            return
        }

        // ── Log execution environment (background / screen-off visibility) ────
        val isScreenOn = (appCtx.getSystemService(Context.POWER_SERVICE) as? PowerManager)
            ?.isInteractive ?: true
        val isForeground = isAppInForeground(appCtx)
        Log.i(TAG, "══════════════════════════════════════════")
        Log.i(TAG, "  📱 SOS SMS DISPATCH STARTED")
        Log.i(TAG, "  Contacts  : ${_pendingContacts.size}")
        Log.i(TAG, "  Session   : ${System.currentTimeMillis() - _sessionStartMs}ms since trigger")
        Log.i(TAG, "  App state : ${if (isForeground) "Foreground" else "Background ✅ (screen-off safe)"}")
        Log.i(TAG, "  Screen    : ${if (isScreenOn) "On" else "Off ✅ (wake lock will keep CPU alive)"}")
        Log.i(TAG, "  Context   : ${appCtx.javaClass.simpleName} (Activity-free ✅)")
        Log.i(TAG, "══════════════════════════════════════════")

        // ── Acquire PARTIAL_WAKE_LOCK for the SMS + GPS window ────────────────
        // PARTIAL_WAKE_LOCK keeps the CPU running even when the screen turns off.
        // Without it, Android's Doze / OEM battery killers can suspend the process
        // mid-send, silently dropping the SmsManager request.
        // The lock is released in the finally block regardless of success or failure.
        val wakeLock = (appCtx.getSystemService(Context.POWER_SERVICE) as? PowerManager)
            ?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "SHEildAI::SmsBgDispatch"
            )
        wakeLock?.acquire(30_000L) // 30 s max — GPS (8 s) + SMS send headroom
        Log.d(TAG, "WakeLock acquired: ${wakeLock?.isHeld} — CPU kept alive for SMS dispatch")

        try {
            Log.i(TAG, "📍 Fetching GPS location for SOS SMS...")
            Log.i(TAG, "📨 Dispatching SMS to ${_pendingContacts.size} contact(s)...")

            // sendSMSToContacts is a suspend fun — runs GPS + SMS on IO internally.
            // It logs each individual send attempt and a final sent/failed summary.
            // appCtx is passed explicitly — no Activity reference anywhere in the chain.
            SmsHelper.sendSMSToContacts(
                context  = appCtx,
                contacts = _pendingContacts
            )
            Log.i(TAG, "✅ SOS SMS dispatch complete for this session")

        } catch (e: Exception) {
            // Reset the guard so a retry is possible if dispatch threw before any SMS sent.
            _smsSentForSession.set(false)
            Log.e(TAG, "❌ SMS dispatch threw unexpectedly — guard reset for retry: ${e.message}", e)

        } finally {
            // Always release the wake lock — even if SMS threw or was cancelled.
            if (wakeLock?.isHeld == true) {
                wakeLock.release()
                Log.d(TAG, "WakeLock released — SMS dispatch window closed")
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // INTERNAL — Foreground/Background detection
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Detects whether the app process is currently in the foreground.
     *
     * Uses [ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND].
     * This matters for:
     *  - Choosing notification strategy (heads-up vs full-screen intent)
     *  - Deciding whether to show cancel UI or run silently
     *
     * @return true if the app is visible to the user, false if backgrounded.
     */
    private fun isAppInForeground(context: Context): Boolean {
        return try {
            val activityManager =
                context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

            val processes = activityManager.runningAppProcesses ?: return false

            val packageName = context.packageName
            processes.any { process ->
                process.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                        process.processName == packageName
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to determine foreground state: ${e.message}")
            false // Assume background for safety — show notification
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // INTERNAL — Voice detection watchdog
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Runs every 30s. If [VoiceDetectionService] has silently died (OEM kill)
     * and the user had voice enabled, restarts it automatically.
     *
     * Does nothing during active SOS sessions to avoid mic conflicts.
     */
    private fun startVoiceWatchdog(context: Context) {
        scope.launch {
            while (isActive) {
                delay(30_000L)
                if (_state.get() != SOSState.IDLE) continue
                if (!SOSStateStore.isVoiceEnabled(context)) continue

                if (!VoiceDetectionService.isListening) {
                    SHEildLog.w("Watchdog", "VoiceDetectionService not listening — restarting")
                    Log.w(TAG, "⚠️ Watchdog: VoiceDetectionService dead — restarting")
                    VoiceDetectionService.startDetection(context)
                } else {
                    SHEildLog.v("Watchdog", "VoiceDetectionService OK")
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // DEBUG — Convenience helpers (remove or gate behind BuildConfig in prod)
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * Dumps current state to logcat. Call from MainActivity for manual testing.
     *
     * adb logcat -s SHEildAI
     */
    fun dumpState() {
        SHEildLog.i("SosManager", "╔══════════════════════════════╗")
        SHEildLog.i("SosManager", "║  SOSManager State Dump       ║")
        SHEildLog.i("SosManager", "╠══════════════════════════════╣")
        SHEildLog.i("SosManager", "║  State   : ${_state.get().displayName}")
        SHEildLog.i("SosManager", "║  Active  : ${isSessionActive()}")
        SHEildLog.i("SosManager", "║  Source  : ${_triggerSource?.displayName ?: "none"}")
        SHEildLog.i("SosManager", "║  Started : ${if (_sessionStartMs > 0) "${System.currentTimeMillis() - _sessionStartMs}ms ago" else "n/a"}")
        SHEildLog.i("SosManager", "╚══════════════════════════════╝")
    }
}
