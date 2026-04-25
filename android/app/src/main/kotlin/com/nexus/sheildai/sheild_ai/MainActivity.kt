package com.nexus.sheildai.sheild_ai

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.nexus.sheildai.sheild_ai.sos.SMSTestConfig
import com.nexus.sheildai.sheild_ai.sos.SmsHelper
import com.nexus.sheildai.sheild_ai.sos.SOSEventChannel
import com.nexus.sheildai.sheild_ai.sos.SOSManager
import com.nexus.sheildai.sheild_ai.sos.SOSStateStore
import com.nexus.sheildai.sheild_ai.sos.SOSTriggerSource
import com.nexus.sheildai.sheild_ai.sos.VoiceDetectionService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * MainActivity — Flutter host activity.
 *
 * Exposes the SOS state machine to Flutter via a [MethodChannel].
 *
 * Channels:
 *   "sos_channel"              — Flutter UI buttons (startSOS / stopSOS / voice)
 *   "com.nexus.sheildai/sos"   — Full debug/test state machine API
 *   "com.nexus.sheildai/sms_test" — Isolated SMS test channel (no SOSManager)
 *
 * SMS test channel methods (Flutter → Android):
 *   "testSMS"  → sends a fixed SMS via [SmsHelper.sendSMS] and returns "sent" / "failed"
 *
 * SOS debug channel methods (Flutter → Android):
 *   "triggerSOS"        { "source": "button" | "voice" | "shake" }
 *   "endSession"        — ends active SOS
 *   "cancelBuffer"      — cancels during the countdown window
 *   "escalateVideo"     — manually advance audio → video (for testing)
 *   "getState"          → returns current state name as String
 *   "dumpState"         — prints state to logcat
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"

        /** Full debug/test channel (all state machine methods). */
        private const val SOS_DEBUG_CHANNEL = "com.nexus.sheildai/sos"

        /** Simple public channel called by Flutter UI buttons. */
        private const val SOS_CHANNEL = "sos_channel"

        /** EventChannel — pushes SOS state changes to Flutter in real time. */
        private const val SOS_EVENT_CHANNEL = SOSEventChannel.CHANNEL_NAME

        /**
         * Request code used when asking the OS to show the SEND_SMS permission dialog.
         * Matched in [onRequestPermissionsResult] to handle the user's response.
         */
        private const val SMS_PERMISSION_REQUEST_CODE = 1001

        /** Request code for RECORD_AUDIO runtime permission (Vosk / voice trigger). */
        private const val MIC_PERMISSION_REQUEST_CODE = 1002

        /**
         * Dedicated channel for isolated SMS smoke-testing.
         * Completely independent of SOSManager — safe to call at any time.
         */
        private const val SMS_TEST_CHANNEL = "com.nexus.sheildai/sms_test"
    }

    /** Coroutine scope for the SMS test channel — uses SupervisorJob so failures stay isolated. */
    private val smsTestScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerSOSChannel(flutterEngine)        // public UI channel
        registerSOSDebugChannel(flutterEngine)   // full state machine channel
        registerSOSEventChannel(flutterEngine)   // real-time event push channel
        registerSmsTestChannel(flutterEngine)    // isolated SMS smoke-test channel
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Inject context into SOSManager for state persistence + crash recovery.
        // Must run before any channel call that could trigger SOSManager.
        SOSManager.init(applicationContext)
        Log.d(TAG, "MainActivity started — SOS state: ${SOSManager.currentState().displayName}")

        // Request runtime permissions.
        // Vosk (voice trigger) needs RECORD_AUDIO — only start it after permission is confirmed.
        requestMicPermission()     // starts Vosk if already granted; shows dialog if not
        requestSmsPermissionIfNeeded()
    }

    /**
     * Starts [VoiceDetectionService] once RECORD_AUDIO permission is confirmed.
     *
     * VoiceDetectionService is the single voice engine:
     *  - Downloads the Vosk model on first launch (~40 MB, once)
     *  - Runs the AudioRecord + keyword recognition loop
     *  - Calls SOSManager.triggerSOS() on "help" detection
     *  - Works in background and survives app close (START_STICKY)
     */
    private fun initVoiceDetection() {
        Log.i(TAG, "[Voice] Mic granted — starting VoiceDetectionService")
        VoiceDetectionService.startDetection(applicationContext)
        SOSStateStore.saveVoiceEnabled(applicationContext, true)
        Log.i(TAG, "[Voice] VoiceDetectionService started")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // RECORD_AUDIO RUNTIME PERMISSION
    // Required for Vosk foreground voice trigger.
    // If already granted on launch → start Vosk immediately.
    // If not granted → show dialog; Vosk starts in onRequestPermissionsResult.
    // ═══════════════════════════════════════════════════════════════════════

    private fun requestMicPermission() {
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) {
            Log.i(TAG, "[Voice] RECORD_AUDIO already granted — starting voice detection")
            initVoiceDetection()
            return
        }

        Log.w(TAG, "[Voice] RECORD_AUDIO not granted — requesting from user")
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            MIC_PERMISSION_REQUEST_CODE
        )
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SEND_SMS RUNTIME PERMISSION
    // Android 1+ declares SEND_SMS as a dangerous permission — the user must
    // explicitly grant it at runtime.  We request it once here and handle the
    // result in onRequestPermissionsResult.  SmsHelper.sendSMS / sendEmergencySms
    // independently re-check the permission before every send, so nothing is
    // ever attempted without a live grant.
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * Checks whether SEND_SMS has been granted.
     * - Already granted → logs and returns immediately (safe no-op).
     * - Not granted     → logs "Permission not granted" and shows system dialog.
     */
    private fun requestSmsPermissionIfNeeded() {
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) {
            Log.i(TAG, "[SMS] SEND_SMS permission already granted — no dialog needed")
            return
        }

        // Permission not yet granted — inform + ask
        Log.w(TAG, "[SMS] Permission not granted — requesting SEND_SMS from user")
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.SEND_SMS),
            SMS_PERMISSION_REQUEST_CODE
        )
    }

    /**
     * Called by Android after the user responds to the permission dialog.
     * Logs the outcome clearly; never crashes regardless of the user's choice.
     * SmsHelper's own permission guard will silently block any send attempt if
     * the user chose to deny.
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            MIC_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.i(TAG, "[Voice] RECORD_AUDIO granted — starting voice detection pipeline")
                    initVoiceDetection()
                } else {
                    Log.w(TAG, "[Voice] RECORD_AUDIO denied — voice trigger disabled")
                }
            }
            SMS_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.i(TAG, "[SMS] SEND_SMS permission granted by user — SMS dispatch enabled")
                } else {
                    Log.w(TAG, "[SMS] Permission not granted — user denied SEND_SMS; SMS dispatch will be blocked")
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SMS TEST CHANNEL  — "com.nexus.sheildai/sms_test"
    // Isolated smoke-test for SmsHelper — zero SOSManager involvement.
    // Flutter calls "testSMS" with optional "phone" and "message" arguments.
    // Defaults to SMSTestConfig values so no arguments are required.
    // ═══════════════════════════════════════════════════════════════════════

    private fun registerSmsTestChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_TEST_CHANNEL
        ).setMethodCallHandler { call, result ->

            Log.d(TAG, "[sms_test_channel] → ${call.method}")

            when (call.method) {

                /**
                 * Sends a single SMS via [SmsHelper.sendSMS] — no SOSManager involved.
                 *
                 * Optional Flutter arguments:
                 *   "phone"   : String — overrides [SMSTestConfig.PHONE_NUMBER]
                 *   "message" : String — overrides [SMSTestConfig.MESSAGE]
                 *
                 * Returns to Flutter:
                 *   "sent"   — SmsManager accepted the request (async delivery)
                 *   "failed" — permission missing, invalid number, or exception
                 */
                "testSMS" -> {
                    val phone   = call.argument<String>("phone")   ?: SMSTestConfig.PHONE_NUMBER
                    val message = call.argument<String>("message") ?: SMSTestConfig.MESSAGE

                    Log.i(TAG, "[sms_test_channel] testSMS — phone: $phone")
                    Log.i(TAG, "[sms_test_channel] testSMS — message: \"$message\"")

                    // Run on IO dispatcher — SmsManager can block briefly
                    smsTestScope.launch(Dispatchers.IO) {
                        try {
                            SmsHelper.sendSMS(
                                context  = applicationContext,
                                phoneNumber = phone,
                                message  = message
                            )
                            Log.i(TAG, "[sms_test_channel] testSMS completed — returning 'sent'")
                            // Reply on Main thread (required by Flutter MethodChannel)
                            launch(Dispatchers.Main) { result.success("sent") }
                        } catch (e: Exception) {
                            Log.e(TAG, "[sms_test_channel] testSMS threw: ${e.message}", e)
                            launch(Dispatchers.Main) { result.success("failed") }
                        }
                    }
                }

                else -> {
                    Log.w(TAG, "[sms_test_channel] Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PUBLIC CHANNEL  — "sos_channel"
    // Called by Flutter UI buttons (startSOS / stopSOS)
    // ═══════════════════════════════════════════════════════════════════════

    private fun registerSOSChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SOS_CHANNEL
        ).setMethodCallHandler { call, result ->

            Log.d(TAG, "[sos_channel] → ${call.method}")

            when (call.method) {

                // Flutter UI "Start SOS" button
                "startSOS" -> {
                    @Suppress("UNCHECKED_CAST")
                    val contactsList = call.argument<List<*>>("contacts")
                        ?.filterIsInstance<String>()
                        ?: emptyList()

                    // Cache contacts natively so voice-triggered SOS sessions
                    // (which bypass this channel) always have the user's registered
                    // contacts available via SOSStateStore.loadTrustedContacts().
                    SOSStateStore.cacheTrustedContacts(applicationContext, contactsList)

                    if (SOSManager.currentState().canTrigger) {
                        SOSManager.triggerSOS(applicationContext, SOSTriggerSource.Button, contactsList)
                        Log.i(TAG, "[sos_channel] startSOS accepted — contacts: ${contactsList.size}, state: ${SOSManager.currentState().name}")
                        result.success(SOSManager.currentState().name)
                    } else {
                        Log.w(TAG, "[sos_channel] startSOS rejected — already active (${SOSManager.currentState().displayName})")
                        result.success(SOSManager.currentState().name)
                    }
                }

                // Flutter UI "I'm Safe" button
                "stopSOS" -> {
                    if (SOSManager.currentState().isActive) {
                        SOSManager.endSession(applicationContext)
                        Log.i(TAG, "[sos_channel] stopSOS accepted — state: ${SOSManager.currentState().name}")
                        result.success(SOSManager.currentState().name)
                    } else {
                        Log.w(TAG, "[sos_channel] stopSOS ignored — no active session")
                        result.success(SOSManager.currentState().name)
                    }
                }

                // Lightweight state query (no logging noise)
                "getState" -> {
                    result.success(SOSManager.currentState().name)
                }

                // Enable always-on voice keyword detection
                "enableVoice" -> {
                    VoiceDetectionService.startDetection(applicationContext)
                    setVoicePreference(true)
                    Log.i(TAG, "[sos_channel] Voice detection enabled")
                    result.success(true)
                }

                // Disable voice keyword detection
                "disableVoice" -> {
                    VoiceDetectionService.stopDetection(applicationContext)
                    setVoicePreference(false)
                    Log.i(TAG, "[sos_channel] Voice detection disabled")
                    result.success(true)
                }

                // Query voice detection running state
                "isVoiceActive" -> {
                    result.success(VoiceDetectionService.isListening)
                }

                else -> {
                    Log.w(TAG, "[sos_channel] Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DEBUG CHANNEL  — "com.nexus.sheildai/sos"
    // Full state machine API (all transitions, test helpers)
    // ═══════════════════════════════════════════════════════════════════════

    private fun registerSOSDebugChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SOS_DEBUG_CHANNEL
        ).setMethodCallHandler { call, result ->

            Log.d(TAG, "[sos_debug_channel] → ${call.method}")

            when (call.method) {

                "triggerSOS" -> {
                    val sourceArg = call.argument<String>("source") ?: "button"
                    val source = resolveSource(sourceArg, call)
                    @Suppress("UNCHECKED_CAST")
                    val contactsList = call.argument<List<*>>("contacts")
                        ?.filterIsInstance<String>()
                        ?: emptyList()
                    SOSManager.triggerSOS(applicationContext, source, contactsList)
                    result.success(SOSManager.currentState().name)
                }

                "endSession" -> {
                    SOSManager.endSession(applicationContext)
                    result.success(SOSManager.currentState().name)
                }

                "cancelBuffer" -> {
                    SOSManager.cancelBuffer(applicationContext)
                    result.success(SOSManager.currentState().name)
                }

                "escalateVideo" -> {
                    SOSManager.escalateToVideoRecording()
                    result.success(SOSManager.currentState().name)
                }

                "getState" -> {
                    result.success(SOSManager.currentState().name)
                }

                "requestBatteryOptimizationExemption" -> {
                    val isExempt = com.nexus.sheildai.sheild_ai.core.services.BatteryOptimizationHelper
                        .requestExemption(this@MainActivity)
                    result.success(isExempt)
                }

                "dumpState" -> {
                    SOSManager.dumpState()
                    result.success("dumped")
                }

                else -> {
                    Log.w(TAG, "[sos_debug_channel] Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // EVENT CHANNEL  — "com.nexus.sheildai/sos_events"
    // Pushes SOSState transitions to Flutter in real time (no polling needed)
    // ═══════════════════════════════════════════════════════════════════════

    private fun registerSOSEventChannel(flutterEngine: FlutterEngine) {
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SOS_EVENT_CHANNEL
        ).setStreamHandler(SOSEventChannel.streamHandler)
        Log.d(TAG, "SOSEventChannel registered on $SOS_EVENT_CHANNEL")
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    /**
     * Persists the voice trigger preference to SharedPreferences.
     * Read by [BootReceiver] on device reboot to decide whether to auto-restart
     * [VoiceDetectionService].
     */
    private fun setVoicePreference(enabled: Boolean) {
        SOSStateStore.saveVoiceEnabled(applicationContext, enabled)
        Log.d(TAG, "Voice preference saved: $enabled")
    }

    private fun resolveSource(
        sourceArg: String,
        call: io.flutter.plugin.common.MethodCall
    ): SOSTriggerSource {
        return when (sourceArg) {
            "button" -> SOSTriggerSource.Button
            "voice"  -> {
                val keyword = call.argument<String>("keyword") ?: "SOS"
                SOSTriggerSource.Voice(keyword)
            }
            "shake"  -> SOSTriggerSource.Shake
            "auto"   -> {
                val reason = call.argument<String>("reason") ?: "system"
                SOSTriggerSource.Auto(reason)
            }
            else -> {
                Log.w(TAG, "Unknown trigger source '$sourceArg' — defaulting to Button")
                SOSTriggerSource.Button
            }
        }
    }
}
