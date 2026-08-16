package com.tunebox.tunebox

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Must extend AudioServiceActivity rather than FlutterActivity so the media
// session can rebind to the UI when the app is reopened from the notification.
class MainActivity : AudioServiceActivity() {

    private var accounts: DeviceAccounts? = null

    private companion object {
        const val WIDGET_CHANNEL = "com.tunebox.tunebox/widget"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val accounts = DeviceAccounts(this)
        this.accounts = accounts

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DeviceAccounts.CHANNEL,
        ).setMethodCallHandler { call, result -> accounts.handle(call, result) }

        // Asking the launcher to place the widget, rather than making someone
        // find it in a picker and drag it. Android 8 and up only; older
        // launchers have no way to be asked.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "pin") return@setMethodCallHandler result.notImplemented()

                val manager = getSystemService(AppWidgetManager::class.java)
                val provider = ComponentName(this, TuneboxWidget::class.java)
                if (manager != null && manager.isRequestPinAppWidgetSupported) {
                    result.success(manager.requestPinAppWidget(provider, null, null))
                } else {
                    result.success(false)
                }
            }
    }

    // The account chooser reports back here; anything it does not claim is
    // passed along so plugins keep working.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (accounts?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
