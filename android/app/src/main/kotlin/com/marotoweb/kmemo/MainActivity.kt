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

    private var pendingNoteUuid: String? = null
    private var pendingCreateNote: Boolean = false
    private lateinit var sharedChannel: MethodChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sharedChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
        sharedChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingNoteUuid" -> {
                    val uuid = pendingNoteUuid
                    if (uuid != null && uuid.isNotEmpty()) {
                        pendingNoteUuid = null // Clear after reading
                        Log.d("WIDGET_DEBUG", "getPendingNoteUuid: returning $uuid")
                        result.success(uuid)
                    } else {
                        // Fallback: try reading from SharedPreferences
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val savedUuid = prefs.getString("flutter.clicked_note_uuid", null)
                        if (savedUuid != null && savedUuid.isNotEmpty()) {
                            prefs.edit().putString("flutter.clicked_note_uuid", "").apply()
                            Log.d("WIDGET_DEBUG", "getPendingNoteUuid: returning from prefs $savedUuid")
                            result.success(savedUuid)
                        } else {
                            Log.d("WIDGET_DEBUG", "getPendingNoteUuid: no pending UUID")
                            result.success(null)
                        }
                    }
                }
                "getCreateNoteFlag" -> {
                    val flag = pendingCreateNote
                    if (flag) {
                        pendingCreateNote = false
                        Log.d("WIDGET_DEBUG", "getCreateNoteFlag: returning true")
                        result.success(true)
                    } else {
                        // Fallback: try reading from SharedPreferences
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val savedFlag = prefs.getBoolean("flutter.create_new_note", false)
                        if (savedFlag) {
                            prefs.edit().putBoolean("flutter.create_new_note", false).apply()
                            Log.d("WIDGET_DEBUG", "getCreateNoteFlag: returning from prefs true")
                            result.success(true)
                        } else {
                            Log.d("WIDGET_DEBUG", "getCreateNoteFlag: no pending create note flag")
                            result.success(false)
                        }
                    }
                }
                "onSharedTextReceived" -> {
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
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
            
            if (action == "ACTION_CREATE_NOTE") {
                Log.d("WIDGET_DEBUG", "Create note action detected")
                pendingCreateNote = true
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                prefs.edit().putBoolean("flutter.create_new_note", true).apply()
                try {
                    if (::sharedChannel.isInitialized) {
                        sharedChannel.invokeMethod("createNewNote", null)
                    }
                } catch (e: Exception) {
                    Log.d("WIDGET_DEBUG", "Failed to invoke createNewNote: ${e.message}")
                }
                return
            }
            
            // Extract the UUID from the extra or the data URI
            var resolvedUuid: String? = uuid
            if (resolvedUuid.isNullOrEmpty() && data != null && data.scheme == "kmemo" && data.host == "note") {
                val pathSegments = data.pathSegments
                Log.d("WIDGET_DEBUG", "pathSegments: $pathSegments")
                if (pathSegments.size >= 2 && pathSegments[0] == "") {
                    resolvedUuid = pathSegments[1]
                    Log.d("WIDGET_DEBUG", "Extracted UUID from path[1]: $resolvedUuid")
                } else if (pathSegments.size >= 1) {
                    resolvedUuid = pathSegments[0]
                    Log.d("WIDGET_DEBUG", "Extracted UUID from path[0]: $resolvedUuid")
                }
            }
            
            if (!resolvedUuid.isNullOrEmpty()) {
                Log.d("WIDGET_DEBUG", "Saving UUID to instance variable: $resolvedUuid")
                pendingNoteUuid = resolvedUuid
                // Also save to SharedPreferences for persistence
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                prefs.edit().putString("flutter.clicked_note_uuid", resolvedUuid).apply()
                Log.d("WIDGET_DEBUG", "UUID saved successfully: $resolvedUuid")
                // Notify Flutter directly via MethodChannel (if the engine is available)
                try {
                    if (::sharedChannel.isInitialized) {
                        sharedChannel.invokeMethod("openNote", resolvedUuid)
                    } else {
                        Log.d("WIDGET_DEBUG", "sharedChannel not initialized yet - UUID saved to prefs for later retrieval")
                    }
                } catch (e: Exception) {
                    Log.d("WIDGET_DEBUG", "Failed to invoke openNote: ${e.message}")
                }
            } else {
                Log.d("WIDGET_DEBUG", "No UUID found in intent")
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
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                prefs.edit().putString("flutter.$SHARED_TEXT_KEY", content).apply()
                Log.d("SHARE_DEBUG", "Shared text saved to SharedPreferences: $content")
                // Notify Flutter that new shared text is available
                sharedChannel.invokeMethod("onSharedTextReceived", null)
            }
        }
    }
}
