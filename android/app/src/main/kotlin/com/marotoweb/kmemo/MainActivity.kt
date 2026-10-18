// android/app/src/main/kotlin/com/marotoweb/kmemo/MainActivity.kt
package com.marotoweb.kmemo

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "com.marotoweb.kmemo/widget"
        const val SHARED_TEXT_KEY = "kmemo.shared_text"
    }

    private lateinit var sharedChannel: MethodChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sharedChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
        Log.d("WIDGET_DEBUG", "=== MainActivity.onCreate ===")
        Log.d("WIDGET_DEBUG", "Intent action: ${intent.action}")
        Log.d("WIDGET_DEBUG", "Intent data: ${intent.data}")
        Log.d("WIDGET_DEBUG", "Intent note_uuid: ${intent.getStringExtra("note_uuid")}")
        handleWidgetIntent(intent)
        handleSharedTextIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d("WIDGET_DEBUG", "=== MainActivity.onNewIntent ===")
        Log.d("WIDGET_DEBUG", "Intent action: ${intent.action}")
        Log.d("WIDGET_DEBUG", "Intent data: ${intent.data}")
        Log.d("WIDGET_DEBUG", "Intent note_uuid: ${intent.getStringExtra("note_uuid")}")
        handleWidgetIntent(intent)
        handleSharedTextIntent(intent)
    }

    private fun handleWidgetIntent(intent: Intent?) {
        intent?.let {
            val uuid = it.getStringExtra("note_uuid")
            val data = it.data
            val action = it.action
            Log.d("WIDGET_DEBUG", "handleWidgetIntent: action=$action, data=$data, uuid=$uuid")
            if (uuid.isNullOrEmpty()) {
                Log.d("WIDGET_DEBUG", "No note_uuid in extra - trying data URI")
                if (data != null && data.scheme == "kmemo" && data.host == "note") {
                    val pathSegments = data.pathSegments
                    Log.d("WIDGET_DEBUG", "pathSegments: $pathSegments")
                    if (pathSegments.size >= 2 && pathSegments[0] == "") {
                        Log.d("WIDGET_DEBUG", "Extracted UUID from path[1]: ${pathSegments[1]}")
                    } else if (pathSegments.size >= 1) {
                        Log.d("WIDGET_DEBUG", "Extracted UUID from path[0]: ${pathSegments[0]}")
                    }
                }
            }
            if (!uuid.isNullOrEmpty()) {
                Log.d("WIDGET_DEBUG", "Saving UUID to SharedPreferences: $uuid")
                val prefs = getSharedPreferences("flutter_shared_preferences", MODE_PRIVATE)
                prefs.edit().putString("flutter.clicked_note_uuid", uuid).apply()
                Log.d("WIDGET_DEBUG", "UUID saved successfully: $uuid")
            }
        }
    }

    private fun handleSharedTextIntent(intent: Intent?) {
        intent?.let {
            val action = it.action
            val type = it.type
            Log.d("SHARE_DEBUG", "handleSharedTextIntent: action=$action, type=$type")
            if (Intent.ACTION_SEND == action && type != null && type == "text/plain") {
                val sharedText = it.getStringExtra(Intent.EXTRA_TEXT)
                val sharedSubject = it.getStringExtra(Intent.EXTRA_SUBJECT)
                Log.d("SHARE_DEBUG", "Shared text: $sharedText, subject: $sharedSubject")
                if (sharedText.isNullOrEmpty() && sharedSubject.isNullOrEmpty()) return
                val content = if (sharedText.isNullOrEmpty()) sharedSubject else sharedText
                val prefs = getSharedPreferences("flutter_shared_preferences", MODE_PRIVATE)
                prefs.edit().putString(SHARED_TEXT_KEY, content).apply()
                Log.d("SHARE_DEBUG", "Shared text saved to SharedPreferences: $content")
                // Notificar o Flutter que há novo texto partilhado
                sharedChannel.invokeMethod("onSharedTextReceived", null)
            }
        }
    }
}
