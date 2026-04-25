package com.nexus.sheildai.sheild_ai.sos

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * SmsHelper — Sends emergency SMS messages to a list of contacts.
 *
 * Used by [SOSManager] after the buffer window expires (cancel window passed).
 *
 * Key behaviours:
 *  - Permission guard: aborts cleanly if SEND_SMS is not granted
 *  - Null location: sends a "location unavailable" message rather than crashing
 *  - Long messages: uses [SmsManager.divideMessage] / [SmsManager.sendMultipartTextMessage]
 *  - API compat: uses context.getSystemService() on API 31+, getDefault() below
 *  - Invalid numbers: skipped with a warning, never throw
 */
object SmsHelper {

    private const val TAG = "SmsHelper"

    // ─── Public API ───────────────────────────────────────────────────────────

    /**
     * Returns true if SEND_SMS permission is granted.
     */
    fun hasSmsPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Generic SMS sender — sends [message] to a single [phoneNumber].
     *
     * Handles long messages automatically via [SmsManager.divideMessage] /
     * [SmsManager.sendMultipartTextMessage].
     *
     * Logs:
     *   "SMS sending..."   — before dispatch attempt
     *   "SMS sent"         — on success
     *   "SMS failed"       — on any exception
     *
     * @param context     Application context (needed for API-31+ SmsManager).
     * @param phoneNumber Destination phone number (international or local).
     * @param message     Text content to send (may exceed 160 chars).
     */
    fun sendSMS(context: Context, phoneNumber: String, message: String) {

        // ── Diagnostic header — visible at every call site ────────────────────
        val permGranted = hasSmsPermission(context)
        Log.d(TAG, "┌─── sendSMS() diagnostics ───────────────────────────────")
        Log.d(TAG, "│  Raw number    : $phoneNumber")
        Log.d(TAG, "│  Message length: ${message.length} char(s)")
        Log.d(TAG, "│  SEND_SMS perm : ${if (permGranted) "GRANTED ✅" else "DENIED ❌"}")
        Log.d(TAG, "│  Android API   : ${Build.VERSION.SDK_INT}")
        Log.d(TAG, "└─────────────────────────────────────────────────────────")

        // ── Permission guard ──────────────────────────────────────────────────
        if (!permGranted) {
            Log.w(TAG, "SMS failed — SEND_SMS permission not granted (API ${Build.VERSION.SDK_INT})")
            return
        }

        // ── Number validation ─────────────────────────────────────────────────
        val cleanedNumber = cleanPhoneNumber(phoneNumber)
        if (cleanedNumber == null) {
            Log.w(TAG, "SMS failed — invalid phone number: '$phoneNumber' (cleaned to empty/too short)")
            return
        }
        Log.d(TAG, "Number cleaned: '$phoneNumber' → '$cleanedNumber'")

        // ── SmsManager availability ───────────────────────────────────────────
        val smsManager = getSmsManager(context)
        if (smsManager == null) {
            Log.e(TAG, "SMS failed — SmsManager unavailable (API ${Build.VERSION.SDK_INT})")
            return
        }

        Log.i(TAG, "SMS sending... → $cleanedNumber | length: ${message.length} char(s)")

        try {
            val parts = smsManager.divideMessage(message)
            Log.d(TAG, "Message split into ${parts.size} part(s) of ~160 chars each")

            if (parts.size == 1) {
                smsManager.sendTextMessage(cleanedNumber, null, message, null, null)
            } else {
                smsManager.sendMultipartTextMessage(cleanedNumber, null, parts, null, null)
            }

            Log.i(TAG, "SMS sent ✅ → $cleanedNumber (${parts.size} part(s), ${message.length} chars)")
        } catch (e: Exception) {
            Log.e(TAG, "SMS failed ❌ → $cleanedNumber | ${e.javaClass.simpleName}: ${e.message}")
            Log.e(TAG, "SMS failed ❌ — stack trace:", e)
        }
    }

    /**
     * Location-aware SMS sender — fetches the best available GPS fix,
     * formats the standard emergency message, then sends via [sendSMS].
     *
     * Message format (location available):
     *   "Emergency! I need help. My location: https://maps.google.com/?q=lat,long"
     *
     * Message format (location unavailable):
     *   "Emergency! I need help. My location: unavailable. Please call me immediately."
     *
     * This is a suspend function — call it from a coroutine or [CoroutineScope].
     * It runs the GPS fetch on [Dispatchers.IO] internally.
     *
     * @param context     Application context.
     * @param phoneNumber Destination phone number.
     */
    suspend fun sendSMSWithLocation(context: Context, phoneNumber: String) {
        Log.d(TAG, "sendSMSWithLocation() called — fetching GPS for $phoneNumber")

        // ── Fetch best available location (suspend, 8s timeout internally) ────
        val location: Location? = try {
            withContext(Dispatchers.IO) {
                LocationProvider.getBestLocation(context)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Location fetch threw unexpectedly: ${e.message}", e)
            null
        }

        // ── Build message based on location availability ───────────────────────
        val message = buildLocationMessage(location)
        Log.d(TAG, "Location message built — location=${if (location != null) "available" else "null"}")

        // ── Delegate to guarded sendSMS (permission + number check inside) ────
        sendSMS(context, phoneNumber, message)
    }

    /**
     * Sends the location-attached emergency message to every number in [contacts].
     *
     * Strategy:
     *  1. Permission guard — aborts the whole batch if SEND_SMS is not granted.
     *  2. Empty-list guard — logs and returns immediately if [contacts] is empty.
     *  3. GPS fetch ONCE — location is shared across all contacts (efficient).
     *  4. Per-contact loop — each number has its own try-catch so one failure
     *     never prevents the rest from being sent.
     *  5. Summary log — reports total sent / failed / skipped at the end.
     *
     * Message format (location available):
     *   "Emergency! I need help. My location: https://maps.google.com/?q=lat,long"
     *
     * Message format (location unavailable):
     *   "Emergency! I need help. My location: unavailable. Please call me immediately."
     *
     * This is a suspend function — call it from a coroutine or [CoroutineScope].
     *
     * @param context  Application context.
     * @param contacts List of trusted phone numbers (international or local format).
     */
    suspend fun sendSMSToContacts(context: Context, contacts: List<String>) {

        // ── Diagnostic header ─────────────────────────────────────────────────
        val permGranted = hasSmsPermission(context)
        Log.i(TAG, "═══════════════════════════════════════════════════")
        Log.i(TAG, "  sendSMSToContacts() — batch dispatch")
        Log.i(TAG, "  Contacts queued : ${contacts.size}")
        Log.i(TAG, "  SEND_SMS perm   : ${if (permGranted) "GRANTED ✅" else "DENIED ❌"}")
        Log.i(TAG, "  Android API     : ${Build.VERSION.SDK_INT}")
        Log.i(TAG, "═══════════════════════════════════════════════════")

        // ── Permission guard ──────────────────────────────────────────────────
        if (!permGranted) {
            Log.w(TAG, "SMS failed — SEND_SMS permission DENIED (API ${Build.VERSION.SDK_INT}) — aborting entire batch")
            return
        }

        // ── Empty contacts guard ──────────────────────────────────────────────
        if (contacts.isEmpty()) {
            Log.w(TAG, "SMS failed — contacts list is empty, nothing to send")
            return
        }

        // ── SmsManager availability (fail-fast before GPS fetch) ─────────────
        val smsManager = getSmsManager(context)
        if (smsManager == null) {
            Log.e(TAG, "SMS failed — SmsManager unavailable (API ${Build.VERSION.SDK_INT}) — aborting batch")
            return
        }
        Log.d(TAG, "SmsManager acquired ✅ (API ${Build.VERSION.SDK_INT})")

        // ── Fetch GPS location ONCE — shared across all contacts ─────────────
        Log.d(TAG, "Fetching GPS location for batch SMS...")
        val location: Location? = try {
            withContext(Dispatchers.IO) {
                LocationProvider.getBestLocation(context)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Location fetch failed — ${e.javaClass.simpleName}: ${e.message}", e)
            null
        }
        Log.i(TAG, "GPS result: ${if (location != null) "lat=${location.latitude}, lon=${location.longitude} ✅" else "unavailable ⚠️ — fallback message will be used"}")

        // ── Build message ONCE — reused for every contact ────────────────────
        val message = buildLocationMessage(location)
        Log.d(TAG, "Message built — length: ${message.length} char(s), preview: \"${message.take(60)}...\"")

        // ── Per-contact dispatch loop ─────────────────────────────────────────
        var sentCount = 0
        var failCount = 0
        var skipCount = 0

        contacts.forEachIndexed { index, rawNumber ->
            val label = "[${index + 1}/${contacts.size}]"

            // ── Number validation ─────────────────────────────────────────────
            val number = cleanPhoneNumber(rawNumber)
            if (number == null) {
                skipCount++
                Log.w(TAG, "$label SKIPPED — invalid number: '$rawNumber' (too short or non-numeric)")
                return@forEachIndexed
            }
            Log.d(TAG, "$label Number: '$rawNumber' → cleaned: '$number'")

            // ── Per-contact send with isolated try-catch ──────────────────────
            try {
                Log.i(TAG, "$label SMS sending... → $number | message: ${message.length} chars")

                val parts = smsManager.divideMessage(message)
                Log.d(TAG, "$label Message split into ${parts.size} part(s)")

                if (parts.size == 1) {
                    smsManager.sendTextMessage(number, null, message, null, null)
                } else {
                    smsManager.sendMultipartTextMessage(number, null, parts, null, null)
                }

                sentCount++
                Log.i(TAG, "$label SMS sent ✅ → $number (${parts.size} part(s), ${message.length} chars)")

            } catch (e: Exception) {
                failCount++
                Log.e(TAG, "$label SMS failed ❌ → $number | ${e.javaClass.simpleName}: ${e.message}")
                Log.e(TAG, "$label SMS failed ❌ — stack trace:", e)
            }
        }

        // ── Final summary ─────────────────────────────────────────────────────
        Log.i(TAG, "═══════════════════════════════════════════════════")
        Log.i(TAG, "  Batch SMS complete")
        Log.i(TAG, "  ✅ Sent    : $sentCount / ${contacts.size}")
        Log.i(TAG, "  ❌ Failed  : $failCount")
        Log.i(TAG, "  ⚠️ Skipped : $skipCount (invalid numbers)")
        Log.i(TAG, "  Result    : ${if (failCount == 0 && skipCount == 0) "ALL SENT ✅" else "PARTIAL ⚠️"}")
        Log.i(TAG, "═══════════════════════════════════════════════════")
    }

    /**
     * Formats the standard emergency message body with an optional Google Maps link.
     *
     * With location:
     *   "Emergency! I need help. My location: https://maps.google.com/?q=lat,long"
     *
     * Without location:
     *   "Emergency! I need help. My location: unavailable. Please call me immediately."
     *
     * Pure function — no side-effects, safe to unit-test.
     *
     * @param location The GPS fix to embed, or null if unavailable.
     */
    fun buildLocationMessage(location: Location?): String {
        return if (location != null) {
            val lat = String.format(Locale.US, "%.6f", location.latitude)
            val lon = String.format(Locale.US, "%.6f", location.longitude)
            Log.d(TAG, "buildLocationMessage — coords: lat=$lat, lon=$lon")
            "Emergency! I need help. My location: https://maps.google.com/?q=$lat,$lon"
        } else {
            Log.w(TAG, "buildLocationMessage — location null, using fallback message")
            "Emergency! I need help. My location: unavailable. Please call me immediately."
        }
    }

    /**
     * Sends an emergency SMS to every number in [contacts].
     *
     * Permission check is performed here — missing permission logs a warning and returns.
     * Empty [contacts] list logs a warning and returns.
     * Failures on individual numbers are caught per-number and logged.
     *
     * @param context  Application context.
     * @param contacts List of phone number strings (international or local formats accepted).
     * @param location GPS fix to embed in the message, or null for "location unavailable".
     * @param userName Display name of the user in distress (shown in message body).
     */
    fun sendEmergencySms(
        context: Context,
        contacts: List<String>,
        location: Location?,
        userName: String = "Someone"
    ) {
        // ── Diagnostic header ─────────────────────────────────────────────────
        val permGranted = hasSmsPermission(context)
        Log.i(TAG, "═══════════════════════════════════════════════════")
        Log.i(TAG, "  sendEmergencySms() — SOS bulk dispatch")
        Log.i(TAG, "  Contacts  : ${contacts.size}")
        Log.i(TAG, "  Location  : ${if (location != null) "lat=${location.latitude}, lon=${location.longitude} ✅" else "unavailable ⚠️"}")
        Log.i(TAG, "  User      : $userName")
        Log.i(TAG, "  SEND_SMS  : ${if (permGranted) "GRANTED ✅" else "DENIED ❌"}")
        Log.i(TAG, "  Android API: ${Build.VERSION.SDK_INT}")
        Log.i(TAG, "═══════════════════════════════════════════════════")

        // ── Permission guard ──────────────────────────────────────────────────
        if (!permGranted) {
            Log.w(TAG, "SMS failed — SEND_SMS permission DENIED (API ${Build.VERSION.SDK_INT}) — aborting dispatch")
            return
        }

        // ── Empty contacts guard ──────────────────────────────────────────────
        if (contacts.isEmpty()) {
            Log.w(TAG, "SMS failed — contacts list is empty, nothing to send")
            return
        }

        val message = buildEmergencyMessage(location, userName)
        Log.d(TAG, "Emergency message built — length: ${message.length} char(s)")

        val smsManager = getSmsManager(context)
        if (smsManager == null) {
            Log.e(TAG, "SMS failed — SmsManager unavailable (API ${Build.VERSION.SDK_INT})")
            return
        }

        var sentCount = 0
        var failCount = 0
        var skipCount = 0

        for ((index, rawNumber) in contacts.withIndex()) {
            val label = "[${index + 1}/${contacts.size}]"
            val number = cleanPhoneNumber(rawNumber)

            if (number == null) {
                skipCount++
                Log.w(TAG, "$label SKIPPED — invalid number: '$rawNumber'")
                continue
            }
            Log.d(TAG, "$label Number: '$rawNumber' → '$number' | message: ${message.length} chars")

            try {
                Log.i(TAG, "$label SMS sending... → $number")
                val parts = smsManager.divideMessage(message)
                Log.d(TAG, "$label Message split into ${parts.size} part(s)")
                if (parts.size == 1) {
                    smsManager.sendTextMessage(number, null, message, null, null)
                } else {
                    smsManager.sendMultipartTextMessage(number, null, parts, null, null)
                }
                sentCount++
                Log.i(TAG, "$label SMS sent ✅ → $number (${parts.size} part(s), ${message.length} chars)")
            } catch (e: Exception) {
                failCount++
                Log.e(TAG, "$label SMS failed ❌ → $number | ${e.javaClass.simpleName}: ${e.message}")
                Log.e(TAG, "$label SMS failed ❌ — stack trace:", e)
            }
        }

        Log.i(TAG, "SOS SMS dispatch complete — ✅ sent: $sentCount | ❌ failed: $failCount | ⚠️ skipped: $skipCount")
    }

    /**
     * Builds a formatted emergency SMS body.
     *
     * With location:
     *   🆘 SOS ALERT
     *   [userName] needs help!
     *   📍 https://maps.google.com/?q=lat,lon
     *   ⏰ 00:00, 01 Jan
     *   Sent via SHEild AI
     *
     * Without location:
     *   (same but "📍 Location unavailable")
     */
    fun buildEmergencyMessage(location: Location?, userName: String = "Someone"): String {
        val timeStr = SimpleDateFormat("HH:mm, dd MMM yyyy", Locale.getDefault()).format(Date())

        val locationLine = if (location != null) {
            val lat = String.format(Locale.US, "%.6f", location.latitude)
            val lon = String.format(Locale.US, "%.6f", location.longitude)
            "📍 https://maps.google.com/?q=$lat,$lon"
        } else {
            "📍 Location unavailable"
        }

        return buildString {
            appendLine("🆘 SOS ALERT")
            appendLine("$userName needs help!")
            appendLine(locationLine)
            appendLine("⏰ $timeStr")
            append("Sent via SHEild AI")
        }
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    /**
     * Returns a platform-appropriate [SmsManager].
     *
     * Android 12 (API 31+): [Context.getSystemService] — uses the user's default SIM.
     * Below API 31: [SmsManager.getDefault] (deprecated but still functional).
     */
    private fun getSmsManager(context: Context): SmsManager? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                Log.d(TAG, "getSmsManager — API ${Build.VERSION.SDK_INT} >= 31, using context.getSystemService()")
                context.getSystemService(SmsManager::class.java)
            } else {
                Log.d(TAG, "getSmsManager — API ${Build.VERSION.SDK_INT} < 31, using SmsManager.getDefault()")
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
        } catch (e: Exception) {
            Log.e(TAG, "getSmsManager failed — ${e.javaClass.simpleName}: ${e.message} (API ${Build.VERSION.SDK_INT})", e)
            null
        }
    }

    /**
     * Strips non-numeric characters (except leading +) and validates length.
     * Returns null if the cleaned number is shorter than 7 digits (not a valid number).
     *
     * Safety net: rejects strings that contain the Flutter SharedPreferences
     * List<String> encoding prefix ("VGhpcyBpcyB0aGU…"). This prefix contains
     * base64 digits that would otherwise survive the regex and produce junk like
     * "043+918131842531". The primary fix is in SOSStateStore.loadTrustedContacts(),
     * but this guard makes the failure loud (logged) rather than silent (wrong send).
     */
    private fun cleanPhoneNumber(raw: String): String? {
        // Defence-in-depth: detect Flutter's List<String> encoding blob leaking through
        if (raw.contains("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu")) {
            Log.e(TAG, "cleanPhoneNumber — REJECTED: input contains Flutter list-encoding prefix. " +
                    "SOSStateStore.loadTrustedContacts() failed to decode the contact list correctly. " +
                    "Raw value: '${raw.take(80)}…'")
            return null
        }
        val cleaned = raw.trim().replace(Regex("[^+\\d]"), "")
        return if (cleaned.length >= 3) cleaned else null
    }
}
