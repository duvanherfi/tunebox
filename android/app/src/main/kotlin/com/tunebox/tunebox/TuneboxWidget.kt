package com.tunebox.tunebox

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.KeyEvent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home screen widget: what is playing, and the three controls worth
 * reaching for without unlocking into an app.
 *
 * Its buttons do not go through Flutter. They send the same media button
 * broadcasts a headset sends, straight to the service that already owns
 * playback — so the widget works whether or not the UI is running, which is the
 * whole reason someone puts a widget on a home screen.
 */
class TuneboxWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.tunebox_widget).apply {
                val title = widgetData.getString("title", null)
                setTextViewText(R.id.widget_title, title ?: context.getString(R.string.widget_idle))
                setTextViewText(R.id.widget_artist, widgetData.getString("artist", "") ?: "")

                setImageViewResource(
                    R.id.widget_play,
                    if (widgetData.getBoolean("playing", false)) {
                        R.drawable.ic_widget_pause
                    } else {
                        R.drawable.ic_widget_play
                    },
                )

                // Written by the app as a plain file so the widget can read it
                // without a content provider; absent until something plays.
                val art = widgetData.getString("art", null)
                val bitmap = art?.let { BitmapFactory.decodeFile(it) }
                if (bitmap != null) {
                    setImageViewBitmap(R.id.widget_art, bitmap)
                } else {
                    setImageViewResource(R.id.widget_art, R.drawable.ic_notification)
                }

                setOnClickPendingIntent(R.id.widget_previous, mediaButton(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                setOnClickPendingIntent(R.id.widget_play, mediaButton(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                setOnClickPendingIntent(R.id.widget_next, mediaButton(context, KeyEvent.KEYCODE_MEDIA_NEXT))

                // Tapping the rest of the widget opens the app.
                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launch ->
                    setOnClickPendingIntent(
                        R.id.widget_root,
                        PendingIntent.getActivity(
                            context,
                            0,
                            launch,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                        ),
                    )
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /**
     * A media button broadcast, addressed to audio_service's receiver.
     *
     * Each key code needs its own request code: PendingIntents that differ only
     * in their extras are considered the same by the system, and all three
     * buttons would end up sending whichever was created last.
     */
    private fun mediaButton(context: Context, keyCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = ComponentName(
                context.packageName,
                "com.ryanheise.audioservice.MediaButtonReceiver",
            )
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        return PendingIntent.getBroadcast(
            context,
            keyCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
