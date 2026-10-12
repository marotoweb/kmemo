// android/app/src/main/kotlin/com/marotoweb/kmemo/MainActivity.kt
package com.marotoweb.kmemo

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("WIDGET_DEBUG", "=== MainActivity.onCreate ===")
        Log.d("WIDGET_DEBUG", "Intent action: ${intent.action}")
        Log.d("WIDGET_DEBUG", "Intent data: ${intent.data}")
        Log.d("WIDGET_DEBUG", "Intent note_uuid: ${intent.getStringExtra("note_uuid")}")
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d("WIDGET_DEBUG", "=== MainActivity.onNewIntent ===")
        Log.d("WIDGET_DEBUG", "Intent action: ${intent.action}")
        Log.d("WIDGET_DEBUG", "Intent data: ${intent.data}")
        Log.d("WIDGET_DEBUG", "Intent note_uuid: ${intent.getStringExtra("note_uuid")}")
        handleWidgetIntent(intent)
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
}
