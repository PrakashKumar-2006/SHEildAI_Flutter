package com.nexus.sheildai.sheild_ai.sos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * SOSStopReceiver — handles the "I'm Safe — Stop SOS" action from the
 * persistent lock-screen notification ([SOSPersistentNotification]).
 *
 * The notification fires a broadcast with action [ACTION_STOP_SOS].
 * This receiver intercepts it and delegates to [SOSManager.endSession],
 * which is the single authority for ending an SOS session.
 *
 * Registered in AndroidManifest.xml with android:exported="false" so
 * only this app can fire the intent.
 */
class SOSStopReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_STOP_SOS = "com.nexus.sheildai.sos.ACTION_STOP_SOS"
        private const val TAG = "SOSStopReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_STOP_SOS) {
            Log.w(TAG, "Unexpected action: ${intent.action} — ignoring")
            return
        }

        Log.i(TAG, "📨 Received ACTION_STOP_SOS broadcast — ending session via SOSManager")

        val appContext = context.applicationContext

        // SOSManager.endSession() is thread-safe (AtomicReference state).
        // BroadcastReceiver.onReceive() runs on the main thread, which is fine.
        if (SOSManager.isSessionActive()) {
            SOSManager.endSession(appContext)
            Log.i(TAG, "✅ SOSManager.endSession() called from notification action")
        } else {
            Log.w(TAG, "⚠️ Received stop broadcast but no active SOS session — ignored")
        }
    }
}
