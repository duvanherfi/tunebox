package com.tunebox.tunebox

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands a downloaded APK to the system installer.
 *
 * Written here rather than taken from a plugin: the ones that exist
 * (`install_plugin`, `ota_update`, `app_installer`) have been unmaintained for
 * years and none of them checks the signature, which is the only thing that
 * makes downloading a binary from a public URL safe. Whoever takes over the
 * repository, or sits between the phone and GitHub, can serve any file they
 * like — what they cannot do is sign it with a key they do not have.
 *
 * So an APK whose signer is not this app's signer is refused outright. It is
 * not a warning the user can wave through: on this path a mismatch has no
 * innocent explanation.
 */
class Installer(private val activity: Activity) {

    companion object {
        const val CHANNEL = "tunebox/installer"

        private const val APK = "application/vnd.android.package-archive"
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canInstall" -> result.success(canInstall())
            "openInstallSettings" -> {
                openInstallSettings()
                result.success(null)
            }
            "install" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("no_path", "No apk path given", null)
                } else {
                    install(path, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Whether the system would let this app start an install at all.
     *
     * The per-app permission only exists from Android 8; before that the
     * switch is a single global one and there is nothing to ask about, so the
     * answer is yes and the installer says its piece if it is off.
     */
    private fun canInstall(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        activity.startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${activity.packageName}"),
            ),
        )
    }

    private fun install(path: String, result: MethodChannel.Result) {
        val file = File(path)
        if (!file.exists()) {
            return result.error("missing", "No apk at $path", null)
        }

        val archive = activity.packageManager.getPackageArchiveInfo(path, certificateFlags())
        if (archive == null) {
            return result.error("unreadable", "Not an apk", null)
        }
        // An APK for another package would install alongside this app rather
        // than over it, which is exactly how a lookalike gets on the phone.
        if (archive.packageName != activity.packageName) {
            return result.error("wrong_package", "Apk is for ${archive.packageName}", null)
        }
        if (!signedLikeUs(archive)) {
            return result.error("signature", "Apk is signed by another key", null)
        }

        // A file:// uri would have the installer read a path in this app's
        // private cache, which it cannot; the provider hands it a grant
        // instead, and the flag is what makes the grant travel with the intent.
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.updates",
            file,
        )
        activity.startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, APK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
        result.success(true)
    }

    @Suppress("DEPRECATION")
    private fun certificateFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }

    /**
     * Whether the downloaded APK carries the same signing identity as the app
     * asking to install it.
     *
     * From Android 9 the system's own comparison is used, which understands a
     * rotated key: an APK signed by a successor of the installed certificate
     * still counts. Before that there is no such API and no rotation either,
     * so the certificates have to match outright.
     */
    private fun signedLikeUs(archive: PackageInfo): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signers = archive.signingInfo?.apkContentsSigners ?: return false
            if (signers.isEmpty()) return false
            return signers.all {
                activity.packageManager.hasSigningCertificate(
                    activity.packageName,
                    it.toByteArray(),
                    PackageManager.CERT_INPUT_RAW_X509,
                )
            }
        }

        @Suppress("DEPRECATION")
        val ours = activity.packageManager
            .getPackageInfo(activity.packageName, PackageManager.GET_SIGNATURES)
            .signatures
            ?.map { it.toCharsString() }
            ?.toSet()
            .orEmpty()

        @Suppress("DEPRECATION")
        val theirs = archive.signatures?.map { it.toCharsString() }?.toSet().orEmpty()

        return theirs.isNotEmpty() && theirs == ours
    }
}
