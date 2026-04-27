package com.nexus.sheildai.sheild_ai.sos

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * SOSStateStore — Single-responsibility SharedPreferences helper.
 *
 * Acts as the single source of truth for:
 *  - SOS state persistence across process deaths (crash recovery)
 *  - Session timestamp (detects stale mid-session kills)
 *  - Voice trigger user preference (read by [BootReceiver] on reboot)
 *
 * All classes that previously wrote directly to SharedPreferences
 * ([BootReceiver], [MainActivity]) must delegate through this object.
 */
object SOSStateStore {

    private const val TAG = "SOSStateStore"

    /** SharedPreferences file name — single file for the whole SOS subsystem. */
    const val PREFS_NAME = "sheildai_prefs"

    // ── Keys ─────────────────────────────────────────────────────────────────

    private const val KEY_SOS_STATE        = "sos_state"
    private const val KEY_SESSION_START_MS = "sos_session_start_ms"
    private const val KEY_TRIGGER_SOURCE   = "sos_trigger_source"

    /** Boolean: true when the user has enabled always-on voice detection. */
    const val KEY_VOICE_ENABLED = "voice_trigger_enabled"

    /** Flutter SharedPreferences file name and key prefix. */
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_TRUSTED_CONTACTS = "flutter.trusted_contacts"

    /**
     * Native-side cache of trusted contacts.
     * Written every time Flutter calls startSOS with a non-empty contact list.
     * Read by [loadTrustedContacts] as a fallback when Flutter prefs are unavailable
     * (e.g. first voice-triggered SOS before the user has opened the SOS screen).
     * Stored as a pipe-delimited string: "+919876543210|+911234567890"
     */
    private const val KEY_CONTACTS_CACHE = "trusted_contacts_native_cache"

    // ── SOS State ─────────────────────────────────────────────────────────────

    /**
     * Persists the current SOS state.
     *
     * Called by [SOSManager] on every state transition so a crash mid-session
     * can be detected on the next cold start.
     *
     * @param state          Current SOS state.
     * @param sessionStartMs Epoch-ms when the session started (0 = no session).
     * @param triggerSource  Human-readable trigger source label, or null.
     */
    fun saveState(
        context: Context,
        state: SOSState,
        sessionStartMs: Long = 0L,
        triggerSource: String? = null,
    ) {
        prefs(context).edit()
            .putString(KEY_SOS_STATE, state.name)
            .putLong(KEY_SESSION_START_MS, sessionStartMs)
            .putString(KEY_TRIGGER_SOURCE, triggerSource)
            .apply()
        Log.v(TAG, "State persisted → ${state.name}")
    }

    /**
     * Loads the last persisted [SOSState].
     * Falls back to [SOSState.IDLE] on any parsing error or missing key.
     */
    fun loadState(context: Context): SOSState {
        val name = prefs(context).getString(KEY_SOS_STATE, SOSState.IDLE.name)
            ?: return SOSState.IDLE
        return try {
            SOSState.valueOf(name)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "Unknown persisted state '$name' — defaulting to IDLE")
            SOSState.IDLE
        }
    }

    /** Returns the epoch-ms timestamp when the last session started, or 0. */
    fun loadSessionStartMs(context: Context): Long =
        prefs(context).getLong(KEY_SESSION_START_MS, 0L)

    /**
     * Clears all session-specific keys (called when state returns to IDLE).
     * Retains [KEY_VOICE_ENABLED] so voice detection survives session resets.
     */
    fun clearSession(context: Context) {
        prefs(context).edit()
            .remove(KEY_SOS_STATE)
            .remove(KEY_SESSION_START_MS)
            .remove(KEY_TRIGGER_SOURCE)
            .apply()
        Log.d(TAG, "Session state cleared")
    }

    // ── Voice trigger preference ──────────────────────────────────────────────

    /** Persists whether the user wants always-on voice keyword detection. */
    fun saveVoiceEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_VOICE_ENABLED, enabled).apply()
        Log.d(TAG, "Voice enabled preference saved: $enabled")
    }

    /** Returns true if the user has enabled voice keyword detection. */
    fun isVoiceEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_VOICE_ENABLED, false)

    // ── Trusted Contacts (Synced from Flutter) ───────────────────────────────

    /**
     * Reads the trusted contacts list saved by the Flutter UI.
     *
     * Priority chain:
     *  1. Flutter SharedPreferences ("FlutterSharedPreferences" → "flutter.trusted_contacts")
     *     This is the primary store written by the Contact Setup / Manage Contacts screens.
     *  2. Native contacts cache ("sheildai_prefs" → [KEY_CONTACTS_CACHE])
     *     Written by [cacheTrustedContacts] whenever Flutter calls startSOS with contacts.
     *     Ensures voice-triggered SOS always has the user's last known contacts, even when
     *     the Flutter engine is not active or the flutter prefs key is temporarily unavailable.
     *
     * Returns an empty list (never a default/fallback number list) if no contacts are found.
     * The caller ([SOSManager]) decides how to handle the empty case.
     */
    fun loadTrustedContacts(context: Context): List<String> {
        // ── 1. Try Flutter SharedPreferences first ────────────────────────────
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val rawValue = flutterPrefs.all[KEY_TRUSTED_CONTACTS]

        Log.d(TAG, "Loading trusted contacts. Key: $KEY_TRUSTED_CONTACTS, Type: ${rawValue?.javaClass?.simpleName}, Value: $rawValue")

        val fromFlutter: List<String> = when (rawValue) {
            is Set<*> -> {
                // Standard Flutter behavior: stored as a Set<String>
                rawValue.filterIsInstance<String>()
            }
            is String -> {
                // Flutter's shared_preferences_android stores List<String> as a single
                // String with a known base64 type-tag prefix, followed by a JSON array:
                //   "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu[\"...\"]"
                //   ─────────────────────────────────────────── ──────────
                //   LIST_IDENTIFIER (base64 of "This is the        JSON list
                //   prefix for a list.")
                //
                // Any separator character between the prefix and '[' (e.g. '!') is
                // skipped by dropWhile { it != '[' }.
                //
                // Fallback chain:
                //  1. Flutter list-encoded string  → strip prefix, parse JSON array
                //  2. Raw JSON array starting with '['  → parse JSON array
                //  3. Everything else → treat as a single phone number string

                val FLUTTER_LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

                val jsonSource: String? = when {
                    rawValue.startsWith(FLUTTER_LIST_PREFIX) -> {
                        // Strip the type-tag prefix, then seek the '[' of the JSON array
                        rawValue.removePrefix(FLUTTER_LIST_PREFIX)
                            .dropWhile { it != '[' }
                            .takeIf { it.startsWith("[") }
                    }
                    rawValue.startsWith("[") -> rawValue
                    else -> null
                }

                if (jsonSource != null) {
                    try {
                        jsonSource.removeSurrounding("[", "]")
                            .split(",")
                            .map { it.trim().removeSurrounding("\"").removeSurrounding("'") }
                            .filter { it.isNotBlank() }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse contact list string: $rawValue")
                        emptyList()
                    }
                } else {
                    // Plain single-number string (e.g. "+918131842531")
                    listOf(rawValue)
                }
            }
            else -> {
                if (rawValue != null) {
                    Log.w(TAG, "Unexpected type for $KEY_TRUSTED_CONTACTS: ${rawValue.javaClass.simpleName}")
                }
                emptyList()
            }
        }

        if (fromFlutter.isNotEmpty()) {
            Log.i(TAG, "✅ Contacts loaded from Flutter prefs: ${fromFlutter.size} contacts")
            return fromFlutter
        }

        // ── 2. Fall back to native cache ──────────────────────────────────────
        val cached = loadCachedContacts(context)
        if (cached.isNotEmpty()) {
            Log.w(TAG, "⚠️ Flutter prefs empty — using native contacts cache: ${cached.size} contacts")
            return cached
        }

        Log.e(TAG, "❌ No trusted contacts found in Flutter prefs or native cache")
        return emptyList()
    }

    /**
     * Caches a non-empty contact list to native SharedPreferences.
     *
     * Called by [com.nexus.sheildai.sheild_ai.MainActivity] every time Flutter
     * triggers SOS with a contacts list. This ensures voice-triggered SOS sessions
     * that happen later (without Flutter involvement) always have the user's
     * most recently confirmed contacts available.
     *
     * Contacts are stored as a pipe-delimited string.
     * No-op if [contacts] is empty.
     */
    fun cacheTrustedContacts(context: Context, contacts: List<String>) {
        if (contacts.isEmpty()) return
        val encoded = contacts.joinToString(separator = "|")
        prefs(context).edit().putString(KEY_CONTACTS_CACHE, encoded).apply()
        Log.i(TAG, "📋 Cached ${contacts.size} trusted contacts to native prefs")
    }

    /**
     * Reads contacts previously cached by [cacheTrustedContacts].
     * Returns an empty list if nothing has been cached yet.
     */
    private fun loadCachedContacts(context: Context): List<String> {
        val encoded = prefs(context).getString(KEY_CONTACTS_CACHE, null) ?: return emptyList()
        return encoded.split("|").filter { it.isNotBlank() }
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
