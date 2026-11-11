// android/app/src/main/kotlin/com/marotoweb/kmemo/KMemoWidgetProvider.kt
package com.marotoweb.kmemo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File

class KMemoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d("KMemoWidget", "onUpdate called with ${appWidgetIds.size} widgets")

        // Prefer the app theme saved in the widget payload (the user can pick
        // light/dark independently of the system); fall back to the system theme.
        val systemIsDark = (context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
        val payloadInfo = readWidgetPayloadInfo(context)
        val isDarkMode = payloadInfo.isDark ?: systemIsDark
        val payloadVersion = payloadInfo.version
        val bgOpacity = payloadInfo.bgOpacity
        val cardOpacity = payloadInfo.cardOpacity
        // Android 12+ can receive the whole collection in the RemoteViews. This
        // avoids the asynchronous RemoteViewsService placeholders whose height
        // changes when an item is loaded (the source of the scroll jump) and
        // replaces the deprecated setRemoteAdapter(Intent) API.
        val useCollection = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val idsToReload = mutableListOf<Int>()
        WidgetDebugLog.log(
            context,
            "onUpdate ids=${appWidgetIds.toList()} payloadVersion=$payloadVersion " +
                "collection=$useCollection"
        )

        for (appWidgetId in appWidgetIds) {
            val configuredKey = "$KEY_CONFIGURED_PREFIX$appWidgetId"
            val versionKey = "$KEY_VERSION_PREFIX$appWidgetId"
            val layoutVersionKey = "$KEY_LAYOUT_VERSION_PREFIX$appWidgetId"
            val isConfigured = prefs.getBoolean(configuredKey, false)
            val appliedVersion = prefs.getLong(versionKey, Long.MIN_VALUE)
            val appliedLayoutVersion = prefs.getLong(layoutVersionKey, -1L)
            val layoutChanged = appliedLayoutVersion != WIDGET_LAYOUT_VERSION

            if (!isConfigured || layoutChanged) {
                // First add, widget re-created, or app update with a new item
                // layout: set up the ListView and click templates.
                WidgetDebugLog.log(
                    context,
                    "widget $appWidgetId full update configured=$isConfigured " +
                        "layoutChanged=$layoutChanged appliedLayout=$appliedLayoutVersion"
                )
                val views = buildWidgetViews(context, appWidgetId, isDarkMode, bgOpacity, cardOpacity)
                appWidgetManager.updateAppWidget(appWidgetId, views)
                prefs.edit()
                    .putBoolean(configuredKey, true)
                    .putLong(versionKey, payloadVersion ?: Long.MIN_VALUE)
                    .putLong(layoutVersionKey, WIDGET_LAYOUT_VERSION)
                    .apply()
                if (!useCollection) idsToReload.add(appWidgetId)
            } else if (payloadVersion == null || payloadVersion != appliedVersion) {
                // The payload changed. With the inline collection the whole
                // RemoteViews must be replaced; with the legacy service only the
                // "+" button is partially updated and the adapter is notified.
                WidgetDebugLog.log(
                    context,
                    "widget $appWidgetId payload reload old=$appliedVersion new=$payloadVersion"
                )
                if (useCollection) {
                    appWidgetManager.updateAppWidget(
                        appWidgetId,
                        buildWidgetViews(context, appWidgetId, isDarkMode, bgOpacity, cardOpacity)
                    )
                } else {
                    val partial = RemoteViews(context.packageName, R.layout.kmemo_widget)
                    applyAddButton(context, partial, isDarkMode)
                    partial.setFloat(R.id.widget_window_bg, "setAlpha", bgOpacity)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        appWidgetManager.partiallyUpdateAppWidget(appWidgetId, partial)
                    } else {
                        appWidgetManager.updateAppWidget(
                            appWidgetId,
                            buildWidgetViews(context, appWidgetId, isDarkMode, bgOpacity, cardOpacity)
                        )
                    }
                    idsToReload.add(appWidgetId)
                }
                prefs.edit()
                    .putLong(versionKey, payloadVersion ?: Long.MIN_VALUE)
                    .apply()
            } else {
                // Identical payload (for example a launcher-initiated onUpdate):
                // do not replace the collection, otherwise the scroll resets.
                Log.d("KMemoWidget", "Widget $appWidgetId payload unchanged; keeping scroll position")
                WidgetDebugLog.log(
                    context,
                    "widget $appWidgetId unchanged (layout=$appliedLayoutVersion payload=$appliedVersion)"
                )
            }
        }

        if (idsToReload.isNotEmpty()) {
            WidgetDebugLog.log(context, "notify adapter ids=$idsToReload")
            appWidgetManager.notifyAppWidgetViewDataChanged(
                idsToReload.toIntArray(),
                R.id.widget_notes_list
            )
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for (appWidgetId in appWidgetIds) {
            editor.remove("$KEY_CONFIGURED_PREFIX$appWidgetId")
            editor.remove("$KEY_VERSION_PREFIX$appWidgetId")
            editor.remove("$KEY_LAYOUT_VERSION_PREFIX$appWidgetId")
        }
        editor.apply()
        super.onDeleted(context, appWidgetIds)
    }

    private fun buildWidgetViews(
        context: Context,
        appWidgetId: Int,
        isDarkMode: Boolean,
        bgOpacity: Float,
        cardOpacity: Float
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.kmemo_widget)
        // Window background opacity (Settings). Only the background layer is
        // affected; the cards keep their own opacity below.
        views.setFloat(R.id.widget_window_bg, "setAlpha", bgOpacity)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val notes = readWidgetNotes(context)
            val builder = RemoteViews.RemoteCollectionItems.Builder()
                .setViewTypeCount(ITEM_LAYOUT_COUNT)
                .setHasStableIds(true)
            for (note in notes) {
                builder.addItem(
                    note.uuid.hashCode().toLong(),
                    buildItemViews(context, note, cardOpacity)
                )
            }
            views.setRemoteAdapter(R.id.widget_notes_list, builder.build())
            WidgetDebugLog.log(context, "collection adapter items=${notes.size}")
        } else {
            // Legacy path for Android 11 and older.
            val serviceIntent = Intent(context, KMemoWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_notes_list, serviceIntent)
        }
        views.setEmptyView(R.id.widget_notes_list, android.R.id.empty)

        // Tapping anywhere opens the app at the specific note via fillInIntent.
        // Do NOT put note_uuid here - the item's fillInIntent adds the real UUID.
        // With FLAG_MUTABLE, fillInIntent can only add extras that are NOT in the template.
        val clickIntent = Intent(context, MainActivity::class.java).apply {
            action = "ACTION_OPEN_NOTE"
        }
        val clickPendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            clickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        views.setPendingIntentTemplate(R.id.widget_notes_list, clickPendingIntent)

        // "+" button to create a new note - colors identical to the FAB in home_screen.dart
        val addIntent = Intent(context, MainActivity::class.java).apply {
            action = "ACTION_CREATE_NOTE"
        }
        val addPendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId + 1000, // Offset to avoid conflict with the template
            addIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_add_button, addPendingIntent)

        applyAddButton(context, views, isDarkMode)
        return views
    }

    private fun buildItemViews(
        context: Context,
        note: WidgetNote,
        cardOpacity: Float
    ): RemoteViews {
        val previewLines = note.preview.count { it == '\n' } + 1
        val previewMaxLines = previewLines.coerceIn(1, PREVIEW_MAX_LINES)
        val views = RemoteViews(context.packageName, itemLayoutFor(previewMaxLines))

        views.setTextViewText(R.id.widget_item_title, note.title)
        views.setTextViewText(R.id.widget_item_preview, note.preview)
        views.setInt(R.id.widget_item_title, "setMaxLines", 1)
        views.setInt(R.id.widget_item_preview, "setMaxLines", previewMaxLines)

        val isDarkBg = isColorDark(note.color)
        val titleColor = if (isDarkBg) 0xFFFFFFFF.toInt() else 0xFF1F1F1F.toInt()
        val previewColor = if (isDarkBg) 0xFFE0E0E0.toInt() else 0xFF444444.toInt()
        views.setTextColor(R.id.widget_item_title, titleColor)
        views.setTextColor(R.id.widget_item_preview, previewColor)
        // The item background is a white rounded shape; tint it with the note
        // color instead of sending a large bitmap per item.
        views.setInt(R.id.widget_item_bg, "setColorFilter", note.color)
        // Card opacity (Settings). Applied to the background layer only, so the
        // title and preview text stay fully opaque.
        views.setFloat(R.id.widget_item_bg, "setAlpha", cardOpacity)

        val fillInIntent = Intent(Intent.ACTION_VIEW).apply {
            data = Uri.parse("kmemo://note/${note.uuid}")
            putExtra("note_uuid", note.uuid)
        }
        views.setOnClickFillInIntent(R.id.widget_item_bg, fillInIntent)
        views.setOnClickFillInIntent(R.id.widget_item_title, fillInIntent)
        views.setOnClickFillInIntent(R.id.widget_item_preview, fillInIntent)
        return views
    }

    private fun applyAddButton(
        context: Context,
        views: RemoteViews,
        isDarkMode: Boolean
    ) {
        // Set the "+" button background drawable by theme (same as the app FAB)
        val bgDrawable = if (isDarkMode) R.drawable.widget_add_button_bg_dark else R.drawable.widget_add_button_bg_light
        views.setInt(R.id.widget_add_button, "setBackgroundResource", bgDrawable)
        // Set the "+" text color by theme
        val textColor = if (isDarkMode) 0xB3FFFFFF.toInt() else 0xDE000000.toInt()
        views.setTextColor(R.id.widget_add_button_text, textColor)
    }

    private fun itemLayoutFor(previewLines: Int): Int = when (previewLines) {
        1 -> R.layout.kmemo_widget_item_1
        2 -> R.layout.kmemo_widget_item_2
        3 -> R.layout.kmemo_widget_item_3
        4 -> R.layout.kmemo_widget_item_4
        5 -> R.layout.kmemo_widget_item_5
        6 -> R.layout.kmemo_widget_item_6
        7 -> R.layout.kmemo_widget_item_7
        else -> R.layout.kmemo_widget_item_8
    }

    private fun isColorDark(color: Int): Boolean {
        val r = (color shr 16) and 0xFF
        val g = (color shr 8) and 0xFF
        val b = color and 0xFF
        val luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
        return luminance < 0.5
    }

    private data class WidgetNote(
        val uuid: String,
        val title: String,
        val preview: String,
        val color: Int
    )

    private fun readWidgetNotes(context: Context): List<WidgetNote> {
        val appFlutterDir = File(context.filesDir.parentFile, "app_flutter")
        val file = File(appFlutterDir, "widget_data.json")
        if (!file.exists()) return emptyList()
        return try {
            val json = JSONObject(file.readText())
            val labels = json.optJSONObject("labels")
            val untitled = labels?.optString("untitled", "Untitled") ?: "Untitled"
            val empty = labels?.optString("empty", "Empty note") ?: "Empty note"
            val ids = json.optJSONArray("ids") ?: return emptyList()
            val titles = json.optJSONArray("titles") ?: return emptyList()
            val previews = json.optJSONArray("previews")
            val colors = json.optJSONArray("colors")
            val count = titles.length()
            val result = ArrayList<WidgetNote>(count)
            for (i in 0 until count) {
                val uuid = ids.optString(i, "")
                val rawTitle = titles.optString(i, "")
                val title = if (rawTitle.trim().isEmpty() || rawTitle == untitled || isUuid(rawTitle)) untitled else rawTitle
                val rawPreview = previews?.optString(i, "") ?: ""
                val preview = if (rawPreview.trim().isEmpty() || isUuid(rawPreview)) empty else rawPreview
                val color = colors?.optInt(i, 0xFFFFFFFF.toInt()) ?: 0xFFFFFFFF.toInt()
                result.add(WidgetNote(uuid, title, preview, color))
            }
            result
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun isUuid(text: String): Boolean {
        return Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$").matches(text)
    }

    private data class WidgetPayloadInfo(
        val isDark: Boolean?,
        val version: Long?,
        val bgOpacity: Float = 1f,
        val cardOpacity: Float = 1f
    )

    /// Reads the theme, payload version and opacities from the widget JSON.
    /// The theme and version are null when the payload is not available yet, so
    /// the caller can fall back to the system theme and force a reload.
    private fun readWidgetPayloadInfo(context: Context): WidgetPayloadInfo {
        val appFlutterDir = File(context.filesDir.parentFile, "app_flutter")
        val file = File(appFlutterDir, "widget_data.json")
        if (!file.exists()) return WidgetPayloadInfo(null, null)
        return try {
            val json = JSONObject(file.readText())
            val settings = json.optJSONObject("settings")
            val isDark = if (settings?.has("dark") == true) {
                settings.optBoolean("dark")
            } else {
                null
            }
            val version = if (json.has("version")) json.optLong("version") else null
            val bgOpacity = settings?.optDouble("widgetBgOpacity", 1.0)
                ?.toFloat()?.coerceIn(0f, 1f) ?: 1f
            val cardOpacity = settings?.optDouble("widgetCardOpacity", 1.0)
                ?.toFloat()?.coerceIn(0f, 1f) ?: 1f
            WidgetPayloadInfo(isDark, version, bgOpacity, cardOpacity)
        } catch (_: Exception) {
            WidgetPayloadInfo(null, null)
        }
    }

    companion object {
        private const val PREFS_NAME = "kmemo_widget"
        private const val KEY_CONFIGURED_PREFIX = "configured_"
        private const val KEY_VERSION_PREFIX = "payload_version_"
        private const val KEY_LAYOUT_VERSION_PREFIX = "layout_version_"

        private const val PREVIEW_MAX_LINES = 8
        private const val ITEM_LAYOUT_COUNT = 8

        // Bump this whenever the widget item layout changes so existing widgets
        // are rebuilt after an app update (the payload version may not change).
        private const val WIDGET_LAYOUT_VERSION = 7L
    }
}
