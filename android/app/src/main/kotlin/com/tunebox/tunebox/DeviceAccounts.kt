package com.tunebox.tunebox

import android.accounts.Account
import android.accounts.AccountManager
import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.CookieHandler
import java.net.CookieManager
import java.net.CookiePolicy
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

/**
 * Signs in using a Google account already on the phone, so nothing has to be
 * pasted in by hand.
 *
 * The interesting part is the token type. An ordinary OAuth token is no use
 * here: it was tried, and YouTube Music's endpoints refuse it. What this asks
 * for instead is a `weblogin:` token, which is not a credential but a URL that
 * establishes a signed-in web session when opened. Following it collects the
 * cookies the rest of the app already knows how to use.
 *
 * UNVERIFIED. Google has restricted this token type over the years and it may
 * simply return an error; there was no device with a Google account available
 * to test it on. Failures are surfaced rather than swallowed, and pasting the
 * cookie by hand remains as the route known to work.
 */
class DeviceAccounts(private val activity: Activity) {

    companion object {
        const val CHANNEL = "tunebox/accounts"
        private const val GOOGLE = "com.google"
        private const val PICK_ACCOUNT = 4771

        /** Asks for a session scoped to YouTube Music rather than to Google at large. */
        private const val TOKEN_TYPE =
            "weblogin:service=youtube&continue=https://music.youtube.com/"
    }

    private var pending: MethodChannel.Result? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickAccount" -> pickAccount(result)
            "cookiesFor" -> {
                val name = call.argument<String>("account")
                if (name == null) {
                    result.error("no_account", "No account name given", null)
                } else {
                    fetchCookies(name, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Uses the system account chooser rather than listing accounts directly.
     * Reading the account list needs a permission and, since Android 8, only
     * returns accounts the app already owns; the chooser needs neither and is
     * the honest thing to show anyway — the user picks, nothing is enumerated
     * behind their back.
     */
    private fun pickAccount(result: MethodChannel.Result) {
        pending = result
        val intent = AccountManager.newChooseAccountIntent(
            null, null, arrayOf(GOOGLE), null, null, null, null,
        )
        activity.startActivityForResult(intent, PICK_ACCOUNT)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_ACCOUNT) return false
        val result = pending ?: return true
        pending = null

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return true
        }
        result.success(data?.getStringExtra(AccountManager.KEY_ACCOUNT_NAME))
        return true
    }

    private fun fetchCookies(accountName: String, result: MethodChannel.Result) {
        Thread {
            try {
                val manager = AccountManager.get(activity)
                val account = Account(accountName, GOOGLE)

                val bundle = manager
                    .getAuthToken(account, TOKEN_TYPE, null, activity, null, null)
                    .result

                val loginUrl = bundle.getString(AccountManager.KEY_AUTHTOKEN)
                if (loginUrl.isNullOrBlank()) {
                    post { result.error("no_token", "No weblogin token returned", null) }
                    return@Thread
                }

                // Collected here, on this thread. Doing it inside post() would
                // evaluate the network call on the UI thread, which Android
                // kills the process for.
                val cookies = collectCookies(loginUrl)
                post { result.success(cookies) }
            } catch (error: Throwable) {
                post { result.error("account_failed", error.message, null) }
            }
        }.start()
    }

    /**
     * Walks the sign-in URL and keeps whatever cookies it sets along the way.
     *
     * Redirects are followed by hand because the cookies accumulate across
     * them, and the jar has to be read at the end rather than per response.
     */
    private fun collectCookies(startUrl: String): String {
        val jar = CookieManager(null, CookiePolicy.ACCEPT_ALL)
        CookieHandler.setDefault(jar)

        var url: URL? = URL(startUrl)
        var hops = 0

        while (url != null && hops < 10) {
            val connection = url.openConnection() as HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 20000
            connection.readTimeout = 20000
            connection.setRequestProperty(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                    "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
            )

            val code = connection.responseCode
            val next = connection.getHeaderField("Location")
            android.util.Log.i(
                "DeviceAccounts",
                "hop=$hops code=$code host=${url.host} " +
                    "setCookie=${connection.headerFields["Set-Cookie"]?.size ?: 0}",
            )
            try {
                connection.inputStream?.close()
            } catch (_: Throwable) {
                connection.errorStream?.close()
            }
            connection.disconnect()

            url = if (code in 300..399 && !next.isNullOrBlank()) {
                URL(url, next)
            } else {
                null
            }
            hops++
        }

        // Read from the whole store rather than filtering by music.youtube.com.
        // The cookie that matters, SAPISID, is issued on .google.com, so asking
        // only about the music host leaves out precisely the one needed.
        // Later duplicates win: the redirect chain refines values as it goes.
        val collected = LinkedHashMap<String, String>()
        for (cookie in jar.cookieStore.cookies) {
            collected[cookie.name] = cookie.value
        }

        android.util.Log.i(
            "DeviceAccounts",
            "cookies=${collected.size} hasSapisid=${collected.containsKey("SAPISID")}",
        )

        return collected.entries.joinToString("; ") { "${it.key}=${it.value}" }
    }

    private fun post(block: () -> Unit) = activity.runOnUiThread(block)
}
