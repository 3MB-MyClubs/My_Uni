package com.threemb.clupup

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Hands signed pass bytes to a pass app without exposing the private cache. */
class PkpassTicketHandler(private val activity: Activity) {
    companion object {
        private const val MIME_TYPE = "application/vnd.apple.pkpass"
        private const val SAVE_REQUEST = 7422
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingFile: File? = null

    fun addPass(bytes: ByteArray?, result: MethodChannel.Result) {
        if (bytes == null || bytes.isEmpty()) {
            result.error("invalid_pass", "Empty wallet pass", null)
            return
        }
        if (pendingResult != null) {
            result.error("wallet_busy", "Pass export is already open", null)
            return
        }
        var passFile: File? = null
        try {
            val directory = File(activity.cacheDir, "wallet_passes").apply { mkdirs() }
            // Leave recent files readable while a pass app imports them.
            val cutoff = System.currentTimeMillis() - 24 * 60 * 60 * 1000L
            directory.listFiles()?.filter { it.lastModified() < cutoff }?.forEach { it.delete() }
            val file = File.createTempFile("clubup-ticket-", ".pkpass", directory)
            passFile = file
            file.writeBytes(bytes)
            val uri = FileProvider.getUriForFile(
                activity, "${activity.packageName}.wallet_passes", file,
            )
            val open = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, MIME_TYPE)
                clipData = ClipData.newRawUri("Wallet pass", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            if (open.resolveActivity(activity.packageManager) != null) {
                try {
                    // Always offer compatible apps, even if a default is set.
                    activity.startActivity(
                        Intent.createChooser(open, activity.getString(R.string.wallet_open_with)),
                    )
                    result.success(null)
                    return
                } catch (_: ActivityNotFoundException) {
                    // A handler may disappear between resolution and launch.
                }
            }

            // No pass app is installed: save a real .pkpass for later import.
            pendingFile = file
            pendingResult = result
            activity.startActivityForResult(
                Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = MIME_TYPE
                    putExtra(Intent.EXTRA_TITLE, "clubup-event-ticket.pkpass")
                },
                SAVE_REQUEST,
            )
        } catch (_: Exception) {
            pendingFile = null
            pendingResult = null
            passFile?.delete()
            result.error("pass_export_failed", "Could not open or save the wallet pass", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SAVE_REQUEST) return false
        val result = pendingResult ?: return true
        val file = pendingFile
        pendingResult = null
        pendingFile = null
        try {
            if (resultCode == Activity.RESULT_CANCELED) {
                result.success(null)
                return true
            }
            val uri = data?.data
            check(resultCode == Activity.RESULT_OK && uri != null && file != null)
            val output = activity.contentResolver.openOutputStream(uri)
                ?: error("Could not open destination")
            output.use { stream -> file.inputStream().use { it.copyTo(stream) } }
            result.success(null)
        } catch (_: Exception) {
            result.error("pass_export_failed", "Could not save the wallet pass", null)
        } finally {
            file?.delete()
        }
        return true
    }

    fun dispose() {
        pendingResult?.success(null)
        pendingResult = null
        pendingFile?.delete()
        pendingFile = null
    }
}
