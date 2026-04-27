package com.nexus.sheildai.sheild_ai.core.services

import android.content.Context
import android.os.PowerManager
import android.provider.Settings
import android.net.Uri
import android.util.Log

/**
 * BatteryOptimizationHelper — Kotlin-side logic for checking and requesting
 * battery optimization exemption.
 *
 * Called from [com.nexus.sheildai.sheild_ai.MainActivity] via the sos_channel
 * MethodChannel handler for "requestBatteryOptimizationExemption".
 *
 * Returns:
 *  true  → app is already exempt (Doze will not kill it)
 *  false → OS dialog was shown to the user (result unknown until next call)
 */
object BatteryOptimizationHelper {

    private const val TAG = "BatteryOptimHelper"

    /**
     * Returns true if the app is already whitelisted from battery optimization.
     */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    /**
     * Launches the OS dialog asking the user to exempt this app from battery
     * optimization. No-op if already exempt.
     *
     * Must be called from a UI context (Activity).
     *
     * @return true if already exempt (no dialog shown), false if dialog was shown.
     */
    fun requestExemption(context: android.app.Activity): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val pkg = context.packageName

        return if (pm.isIgnoringBatteryOptimizations(pkg)) {
            Log.i(TAG, "Already exempt from battery optimization")
            true
        } else {
            Log.i(TAG, "Requesting battery optimization exemption for $pkg")
            try {
                val intent = android.content.Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$pkg")
                )
                context.startActivity(intent)
            } catch (e: Exception) {
                // Fallback: open battery optimization settings page
                Log.w(TAG, "Direct exemption intent failed — opening settings: ${e.message}")
                try {
                    context.startActivity(
                        android.content.Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    )
                } catch (e2: Exception) {
                    Log.e(TAG, "Could not open battery settings: ${e2.message}")
                }
            }
            false
        }
    }
}
