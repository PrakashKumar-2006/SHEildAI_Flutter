package com.nexus.sheildai.sheild_ai.sos

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * LocationProvider — Suspendable wrapper around [FusedLocationProviderClient].
 *
 * Used by [SOSManager] to attach GPS coordinates to emergency SMS messages.
 *
 * Strategy (fastest → most reliable):
 *   1. [getCurrentLocation] with HIGH_ACCURACY (up to [LOCATION_TIMEOUT_MS])
 *   2. [getLastKnownLocation] as fallback if #1 times out or returns null
 *   3. Return null if both fail — callers must handle the no-location case
 *
 * Thread-safe: all functions are `suspend` and run on the calling coroutine.
 * Permission check is performed before any network/GPS call.
 */
object LocationProvider {

    private const val TAG = "LocationProvider"

    /** Max time to wait for a fresh GPS fix before falling back to lastLocation. */
    private const val LOCATION_TIMEOUT_MS = 8_000L

    // ─── Public API ───────────────────────────────────────────────────────────

    /**
     * Returns the best available [Location], or null if unavailable.
     *
     * @param context Must be application context to avoid leaks.
     */
    suspend fun getBestLocation(context: Context): Location? {
        if (!hasLocationPermission(context)) {
            Log.w(TAG, "Location permission not granted — skipping GPS fetch")
            return null
        }

        val client = LocationServices.getFusedLocationProviderClient(context)

        // 1. Try a fresh high-accuracy fix (bounded by timeout)
        val fresh = withTimeoutOrNull(LOCATION_TIMEOUT_MS) {
            getCurrentLocation(client)
        }

        if (fresh != null) {
            Log.i(TAG, "✅ Fresh GPS fix: lat=${fresh.latitude}, lon=${fresh.longitude}, acc=${fresh.accuracy}m")
            return fresh
        }

        // 2. Fall back to last cached location
        Log.w(TAG, "Fresh GPS timed out / returned null — trying lastLocation cache")
        val last = getLastKnownLocation(client)

        if (last != null) {
            Log.i(TAG, "📍 Last known location: lat=${last.latitude}, lon=${last.longitude}")
        } else {
            Log.w(TAG, "⚠️ No location available — SOS SMS will be sent without coordinates")
        }

        return last
    }

    /**
     * Returns true if at least coarse location permission is granted.
     */
    fun hasLocationPermission(context: Context): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarse = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        return fine || coarse
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    /**
     * Requests a fresh location fix using HIGH_ACCURACY priority.
     * Wraps the Task API into a coroutine-friendly suspend function.
     * [CancellationTokenSource] ensures the underlying Task is cancelled
     * if the coroutine is cancelled (e.g., timeout or scope cancellation).
     */
    @Suppress("MissingPermission")
    private suspend fun getCurrentLocation(
        client: FusedLocationProviderClient
    ): Location? = suspendCancellableCoroutine { cont ->
        val cts = CancellationTokenSource()

        // If the coroutine is cancelled (e.g. by withTimeoutOrNull), cancel the GPS task too
        cont.invokeOnCancellation { cts.cancel() }

        client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cts.token)
            .addOnSuccessListener { location ->
                Log.d(TAG, "getCurrentLocation success: ${location?.let { "lat=${it.latitude}" } ?: "null"}")
                cont.resume(location)
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "getCurrentLocation failed: ${e.message}")
                cont.resume(null)
            }
    }

    /**
     * Fetches the last cached location from the FusedLocationProvider.
     * This is instant but may be stale (or null on first boot / after a reset).
     */
    @Suppress("MissingPermission")
    private suspend fun getLastKnownLocation(
        client: FusedLocationProviderClient
    ): Location? = suspendCancellableCoroutine { cont ->
        client.lastLocation
            .addOnSuccessListener { location ->
                cont.resume(location)
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "getLastLocation failed: ${e.message}")
                cont.resume(null)
            }
    }
}
