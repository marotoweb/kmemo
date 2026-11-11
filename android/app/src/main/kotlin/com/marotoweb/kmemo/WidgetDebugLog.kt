// android/app/src/main/kotlin/com/marotoweb/kmemo/WidgetDebugLog.kt
package com.marotoweb.kmemo

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Debug-only log shared with the Flutter side.
 *
 * It writes to the same app_flutter directory used by widget_data.json, so the
 * Settings screen can read it and copy it to the clipboard when ADB is not
 * available. Disabled in release builds.
 */
object WidgetDebugLog {
    private const val FILE_NAME = "widget_debug.log"
    private const val MAX_BYTES = 512 * 1024

    @Synchronized
    fun log(context: Context, message: String) {
        val isDebuggable =
            (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) return
        try {
            val dir = File(context.filesDir.parentFile, "app_flutter")
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, FILE_NAME)
            if (file.exists() && file.length() > MAX_BYTES) {
                file.delete()
            }
            val timestamp = SimpleDateFormat(
                "yyyy-MM-dd HH:mm:ss.SSS",
                Locale.US
            ).format(Date())
            file.appendText("$timestamp [android] $message\n")
        } catch (_: Exception) {
            // Logging must never break the widget.
        }
    }
}
