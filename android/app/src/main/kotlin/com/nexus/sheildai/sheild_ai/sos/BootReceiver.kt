package com.nexus.sheildai.sheild_ai.sos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BootReceiver — Restarts SOS services after device reboot or OTA app update.
 *
 * Triggered by:
 *  - android.intent.action.BOOT_COMPLETED   — device boot
 *  - android.intent.action.QUICKBOOT_POWERON — HTC/custom ROMs
 *  - android.intent.action.MY_PACKAGE_REPLACED — OTA app update
 *
 * User-consent model:
 *  Only restarts VoiceDetectionService if the user had voice detection enabled
 *  ([SOSStateStore.isVoiceEnabled] returns true). The flag is written by
 *  [com.nexus.sheildai.sheild_ai.MainActivity] when the user enables/disables
 *  voice via the Flutter channel.
 *
 * Crash recovery:
 *  Calls [SOSManager.init] so crash-recovery logic runs. If a stale active state
 *  exists in SharedPreferences (process was killed mid-SOS), it is reset to IDLE.
 *
 * Requires: RECEIVE_BOOT_COMPLETED permission in AndroidManifest.xml
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                val trigger = when (intent.action) {
                    Intent.ACTION_MY_PACKAGE_REPLACED -> "OTA update"
                    else -> "device boot"
                }
                Log.i(TAG, "[$trigger] — restoring SOS services")
                SHEildLog.i("BootReceiver", "Received $trigger — restoring services")
                restoreServicesIfNeeded(context)
            }
            else -> Log.w(TAG, "Unexpected intent action: ${intent.action}")
        }
    }

    private fun restoreServicesIfNeeded(context: Context) {
        // 1. Init SOSManager — runs crash-recovery against SharedPreferences.
        //    This clears any stale active state left from a mid-SOS process death.
        SOSManager.init(context)
        Log.i(TAG, "SOSManager.init() complete after boot/update")

        // 2. Restore voice detection if the user had it enabled.
        if (SOSStateStore.isVoiceEnabled(context)) {
            Log.i(TAG, "Voice trigger was enabled — restarting VoiceDetectionService")
            SHEildLog.i("BootReceiver", "Restarting VoiceDetectionService after ${"boot/update"}")
            VoiceDetectionService.startDetection(context)
        } else {
            Log.d(TAG, "Voice trigger not enabled — skipping auto-start")
        }
    }
}
