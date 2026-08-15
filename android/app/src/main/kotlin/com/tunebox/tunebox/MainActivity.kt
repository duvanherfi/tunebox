package com.tunebox.tunebox

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Must extend AudioServiceActivity rather than FlutterActivity so the media
// session can rebind to the UI when the app is reopened from the notification.
class MainActivity : AudioServiceActivity() {

    private var accounts: DeviceAccounts? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val accounts = DeviceAccounts(this)
        this.accounts = accounts

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DeviceAccounts.CHANNEL,
        ).setMethodCallHandler { call, result -> accounts.handle(call, result) }
    }

    // The account chooser reports back here; anything it does not claim is
    // passed along so plugins keep working.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (accounts?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
