package com.tunebox.tunebox

import android.app.Notification
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * A foreground service that lives exactly as long as a Cast session.
 *
 * In deep Doze Android cuts the network and ignores wake locks for any app
 * that is not in the foreground, and the phone is this receiver's only
 * server. audio_service would be that foreground service, but it leaves the
 * foreground on pause and cannot come back: the receiver resuming is not a
 * user action, so Android 12+ refuses the restart from the background. This
 * one starts when the session opens — always from the cast sheet, with the
 * app on screen — and stays until it closes.
 *
 * It shows no notification of its own. It takes over audio_service's (same
 * id), so the shade keeps the one media notification it always had.
 */
class CastKeepAlive : Service() {

    companion object {
        // audio_service's notification id and channel.
        private const val NOTIFICATION_ID = 1124
        private const val CHANNEL_ID = "com.tunebox.tunebox.audio"
        private const val PLACEHOLDER = "com.tunebox.tunebox.castPlaceholder"

        fun start(context: Context) {
            try {
                context.startForegroundService(Intent(context, CastKeepAlive::class.java))
            } catch (_: Exception) {
                // A session the SDK reopened on its own while the app was in
                // the background: no exemption applies, and casting still
                // works as long as the phone stays out of deep Doze.
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, CastKeepAlive::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = mediaNotification() ?: placeholder()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        // Detach rather than remove when the notification is audio_service's:
        // it decides when that goes. The placeholder is this service's own and
        // would otherwise outlive the session.
        val ours = mediaNotification()?.extras?.getBoolean(PLACEHOLDER) == true
        stopForeground(if (ours) STOP_FOREGROUND_REMOVE else STOP_FOREGROUND_DETACH)
        super.onDestroy()
    }

    private fun mediaNotification(): Notification? =
        getSystemService(NotificationManager::class.java)
            ?.activeNotifications
            ?.firstOrNull { it.id == NOTIFICATION_ID }
            ?.notification

    // Before anything has played there is no media notification yet; this
    // stands in until audio_service posts its own over the same id.
    private fun placeholder(): Notification =
        Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(applicationInfo.loadLabel(packageManager))
            .setOngoing(true)
            .setExtras(android.os.Bundle().apply { putBoolean(PLACEHOLDER, true) })
            .build()
}
