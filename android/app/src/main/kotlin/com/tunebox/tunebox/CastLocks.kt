package com.tunebox.tunebox

import android.content.Context
import android.net.wifi.WifiManager
import android.os.PowerManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * CPU and Wi-Fi locks held while a Cast receiver reads the track from this
 * phone. Nothing plays locally during a session, so without these Android
 * lets the radio doze with the screen off and the receiver stalls mid-track.
 *
 * Process-wide rather than per activity: the session outlives the UI.
 */
object CastLocks {
    const val CHANNEL = "com.tunebox.tunebox/cast_locks"

    private var cpu: PowerManager.WakeLock? = null
    private var wifi: WifiManager.WifiLock? = null

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "acquire" -> {
                acquire(context.applicationContext)
                result.success(null)
            }
            "release" -> {
                release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun acquire(context: Context) {
        if (cpu == null) {
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            cpu = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "tunebox:cast").apply {
                setReferenceCounted(false)
                acquire()
            }
        }
        if (wifi == null) {
            val manager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
            // HIGH_PERF is deprecated in favour of LOW_LATENCY, but LOW_LATENCY
            // only applies while the app is in the foreground — exactly when
            // the lock is not needed.
            wifi = manager.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "tunebox:cast").apply {
                setReferenceCounted(false)
                acquire()
            }
        }
    }

    private fun release() {
        cpu?.takeIf { it.isHeld }?.release()
        cpu = null
        wifi?.takeIf { it.isHeld }?.release()
        wifi = null
    }
}
