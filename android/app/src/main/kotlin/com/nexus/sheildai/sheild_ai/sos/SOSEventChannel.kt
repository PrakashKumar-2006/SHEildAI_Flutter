package com.nexus.sheildai.sheild_ai.sos

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * SOSEventChannel — singleton event sink that pushes SOS state changes
 * from the Kotlin state machine to the Flutter UI in real time.
 *
 * Channel name : "com.nexus.sheildai/sos_events"
 *
 * ┌───────────────────────────────────────────────────────────────┐
 * │  Event format (Map<String, Any>):                             │
 * │    "event"     → String  (event name, see constants below)    │
 * │    "payload"   → Map<String, Any> (optional metadata)         │
 * └───────────────────────────────────────────────────────────────┘
 *
 * Events emitted per state transition:
 *   TRIGGERED       → SOS_STARTED      { source: String }
 *   BUFFER          → BUFFER_STARTED   { bufferMs: Int }
 *   RECORDING_AUDIO → RECORDING_STARTED {}
 *   RECORDING_VIDEO → VIDEO_STARTED    {}
 *   STOPPED         → SESSION_ENDED    { durationMs: Long }
 *   COOLDOWN        → COOLDOWN_STARTED { cooldownMs: Long }
 *   IDLE            → IDLE             {}
 *
 * Thread safety:
 *  - [_sink] is @Volatile — safe for cross-thread reads.
 *  - send() always posts to the main thread (Flutter requirement).
 *  - [_pendingEvents] is guarded by [_lock] for thread-safe access.
 *
 * Buffering behaviour:
 *  When Flutter has no active listener (_sink == null), events are stored
 *  in [_pendingEvents] (capped at [MAX_PENDING]). When Flutter reconnects
 *  via [onListen], the queue is replayed immediately so the UI catches up
 *  to the current state — critical for voice-triggered SOS sessions that
 *  begin while the app is backgrounded or the SOSScreen is not open.
 */
object SOSEventChannel {

    const val CHANNEL_NAME = "com.nexus.sheildai/sos_events"

    // ─── Event name constants ────────────────────────────────────────────────

    const val EVENT_SOS_STARTED       = "SOS_STARTED"
    const val EVENT_BUFFER_STARTED    = "BUFFER_STARTED"
    const val EVENT_RECORDING_STARTED = "RECORDING_STARTED"
    const val EVENT_VIDEO_STARTED     = "VIDEO_STARTED"
    const val EVENT_SESSION_ENDED     = "SESSION_ENDED"
    const val EVENT_COOLDOWN_STARTED  = "COOLDOWN_STARTED"
    const val EVENT_IDLE              = "IDLE"

    private const val TAG         = "SOSEventChannel"
    private const val MAX_PENDING = 10   // max buffered events while Flutter is disconnected

    // ─── EventSink management ────────────────────────────────────────────────

    @Volatile
    private var _sink: EventChannel.EventSink? = null

    /** Guards [_pendingEvents] — accessed from both the main and background threads. */
    private val _lock = Any()

    /**
     * Events fired while [_sink] was null are queued here.
     * Replayed in-order when Flutter reconnects via [onListen].
     */
    private val _pendingEvents = ArrayDeque<Map<String, Any>>(MAX_PENDING)

    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * StreamHandler to wire into [io.flutter.plugin.common.EventChannel].
     *
     * Registered by [com.nexus.sheildai.sheild_ai.MainActivity].
     */
    val streamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
            _sink = sink
            Log.d(TAG, "Flutter subscribed to SOS event stream")

            // Drain and replay any events that were buffered while Flutter
            // was not listening (e.g. voice-triggered SOS from background).
            val pending: List<Map<String, Any>>
            synchronized(_lock) {
                pending = _pendingEvents.toList()
                _pendingEvents.clear()
            }

            if (pending.isNotEmpty()) {
                Log.i(TAG, "🔁 Replaying ${pending.size} buffered SOS event(s) to Flutter")
                mainHandler.post {
                    pending.forEach { data ->
                        try {
                            sink.success(data)
                            Log.d(TAG, "🔁 Replayed: ${data["event"]}")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to replay buffered event: ${e.message}")
                        }
                    }
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            _sink = null
            Log.d(TAG, "Flutter unsubscribed from SOS event stream")
        }
    }

    // ─── Public API ──────────────────────────────────────────────────────────

    /**
     * Emits a named event with an optional payload map.
     *
     * Safe to call from any thread.
     *
     * - If Flutter is listening ([_sink] != null): event is posted to the main
     *   thread and delivered immediately.
     * - If Flutter is NOT listening ([_sink] == null): event is buffered in
     *   [_pendingEvents] (up to [MAX_PENDING]). It will be replayed when Flutter
     *   next subscribes via [onListen]. This ensures voice-triggered SOS state
     *   transitions (TRIGGERED → BUFFER → RECORDING_AUDIO) reach the UI even
     *   when the SOSScreen is not currently open.
     *
     * @param event   One of the [EVENT_*] constants.
     * @param payload Key-value pairs to include alongside the event name.
     */
    fun send(event: String, payload: Map<String, Any> = emptyMap()) {
        val data: Map<String, Any> = buildMap {
            put("event", event)
            if (payload.isNotEmpty()) put("payload", payload)
        }

        val currentSink = _sink
        if (currentSink == null) {
            // Flutter is not listening — buffer the event for later replay.
            synchronized(_lock) {
                if (_pendingEvents.size >= MAX_PENDING) {
                    // Drop the oldest event to make room (circular buffer behaviour).
                    val dropped = _pendingEvents.removeFirst()
                    Log.w(TAG, "⚠️ Pending buffer full — dropped oldest event: ${dropped["event"]}")
                }
                _pendingEvents.addLast(data)
            }
            Log.w(TAG, "📦 send($event) buffered — no active sink (queue: ${_pendingEvents.size}/$MAX_PENDING)")
            return
        }

        // Flutter is listening — deliver immediately on the main thread.
        mainHandler.post {
            try {
                currentSink.success(data)
                Log.d(TAG, "→ Flutter: $event ${if (payload.isEmpty()) "" else payload}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to emit event '$event': ${e.message}")
            }
        }
    }
}
