// android/app/src/main/kotlin/com/marotoweb/kmemo/KMemoWidgetService.kt
package com.marotoweb.kmemo

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.GradientDrawable
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class KMemoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return KMemoWidgetFactory(this.applicationContext)
    }
}

class KMemoWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var notes = emptyList<NoteData>()
    private var untitledLabel = "Sem título"
    private var emptyLabel = "Nota vazia"
    private var autoWrap = true
    private var strikethroughChecked = true
    private var cardOpacity = 1f

    private data class NoteData(
        val uuid: String,
        val title: String,
        val preview: String,
        val colorInt: Int
    )

    override fun onCreate() {}

    override fun onDataSetChanged() {
        Log.d("KMemoWidget", "onDataSetChanged called")
        notes = loadWidgetData(context)
        Log.d("KMemoWidget", "Loaded ${notes.size} notes")
        WidgetDebugLog.log(context, "onDataSetChanged notes=${notes.size}")
    }

    override fun onDestroy() {}

    override fun getCount(): Int = notes.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= notes.size) {
            return RemoteViews(context.packageName, R.layout.kmemo_widget_item_1)
        }

        val note = notes[position]

        // Each card keeps its own height, fixed in XML for that number of
        // preview lines. Different layouts are also different view types, so
        // the ListView never recycles a view between heights (that caused the
        // jump when items were inserted above the viewport).
        val previewLines = note.preview.count { it == '\n' } + 1
        val previewMaxLines = previewLines.coerceAtLeast(1).coerceAtMost(PREVIEW_MAX_LINES)
        val layoutId = itemLayoutFor(previewMaxLines)
        val views = RemoteViews(context.packageName, layoutId)

        try {
            views.setTextViewText(R.id.widget_item_title, note.title)
            views.setTextViewText(R.id.widget_item_preview, note.preview)

            views.setInt(R.id.widget_item_title, "setMaxLines", TITLE_MAX_LINES)
            views.setInt(R.id.widget_item_preview, "setMaxLines", previewMaxLines)

            // Set the text color according to the background luminance
            val isDarkBg = isColorDark(note.colorInt)
            val titleColor = if (isDarkBg) 0xFFFFFFFF.toInt() else 0xFF1F1F1F.toInt()
            val previewColor = if (isDarkBg) 0xFFE0E0E0.toInt() else 0xFF444444.toInt()
            views.setTextColor(R.id.widget_item_title, titleColor)
            views.setTextColor(R.id.widget_item_preview, previewColor)

            val cardHeightDp = TITLE_MAX_LINES * TITLE_LINE_HEIGHT_DP +
                previewMaxLines * PREVIEW_LINE_HEIGHT_DP + CARD_PADDING_DP

            // Dynamic background with rounded corners + note color.
            // The bitmap uses the same height as the item layout.
            val cardBitmap = createCardBitmap(context, note.colorInt, cardHeightDp)
            views.setImageViewBitmap(R.id.widget_item_bg, cardBitmap)
            // Card opacity (Settings), background layer only.
            views.setFloat(R.id.widget_item_bg, "setAlpha", cardOpacity)

            // Individual PendingIntent to open this specific note via App Link
            val fillInIntent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("kmemo://note/${note.uuid}")
                putExtra("note_uuid", note.uuid)
            }
            Log.d("WIDGET_DEBUG", "Widget item ${position}: fillInIntent data=kmemo://note/${note.uuid}")
            views.setOnClickFillInIntent(R.id.widget_item_bg, fillInIntent)
            views.setOnClickFillInIntent(R.id.widget_item_title, fillInIntent)
            views.setOnClickFillInIntent(R.id.widget_item_preview, fillInIntent)

        } catch (e: Exception) {
            Log.e("KMemoWidget", "Erro ao criar view da posição $position", e)
            WidgetDebugLog.log(
                context,
                "getViewAt($position) error: ${e.javaClass.simpleName}: ${e.message}"
            )
        }

        return views
    }

    /// A compact placeholder instead of the system's "Loading..." view. The
    /// system derives the loading view height from the first item, which made
    /// long notes reserve a huge placeholder.
    override fun getLoadingView(): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.kmemo_widget_item_1)
        views.setTextViewText(R.id.widget_item_title, "")
        views.setTextViewText(R.id.widget_item_preview, "")
        return views
    }

    // One view type per item height (kmemo_widget_item_1..8). The
    // RemoteViewsAdapter maps each item layout ID to its own view type; without
    // this, items with a different layout ID are rejected and show the loading
    // view, and the ListView recycles views between heights (scroll jump).
    override fun getViewTypeCount(): Int = 8

    // Stable IDs let the widget keep its scroll position anchored to the same
    // note when the data is reloaded, instead of using the list position.
    override fun getItemId(position: Int): Long {
        val uuid = notes.getOrNull(position)?.uuid ?: return position.toLong()
        return uuid.hashCode().toLong()
    }

    override fun hasStableIds(): Boolean = true

    private fun loadWidgetData(context: Context): List<NoteData> {
        // Dart writes to getApplicationDocumentsDirectory(), which on Android is
        // <filesDir>/../app_flutter/ (e.g. /data/user/0/pkg/app_flutter/)
        val appFlutterDir = File(context.filesDir.parentFile, "app_flutter")
        val file = File(appFlutterDir, "widget_data.json")

        if (!file.exists()) {
            Log.w("KMemoWidget", "Widget data file not found: ${file.absolutePath}")
            return emptyList()
        }

        Log.d("KMemoWidget", "Reading widget data from: ${file.absolutePath}")

        return try {
            val json = file.readText()
            val data = JSONObject(json)

            data.optJSONObject("labels")?.let {
                untitledLabel = it.optString("untitled", untitledLabel)
                emptyLabel = it.optString("empty", emptyLabel)
            }

            data.optJSONObject("settings")?.let {
                autoWrap = it.optBoolean("autoWrap", autoWrap)
                strikethroughChecked = it.optBoolean("strikethroughChecked", strikethroughChecked)
                cardOpacity = it.optDouble("widgetCardOpacity", cardOpacity.toDouble())
                    .toFloat().coerceIn(0f, 1f)
            }

            val ids = data.getJSONArray("ids")
            val titles = data.getJSONArray("titles")
            val previews = data.optJSONArray("previews")
            val colors = data.optJSONArray("colors")

            val result = mutableListOf<NoteData>()
            val count = titles.length()
            for (i in 0 until count) {
                val uuid = ids.optString(i, "")
                val rawTitle = titles.optString(i, "")
                val rawPreview = previews?.optString(i, "") ?: ""
                val colorInt = colors?.optInt(i, 0xFFFFFFFF.toInt()) ?: 0xFFFFFFFF.toInt()

                val title = cleanTitle(rawTitle)
                val preview = cleanPreview(rawPreview)

                result.add(NoteData(uuid, title, preview, colorInt))
            }
            result
        } catch (e: Exception) {
            Log.e("KMemoWidget", "Erro ao ler ficheiro de dados do widget", e)
            emptyList()
        }
    }

    private fun isColorDark(color: Int): Boolean {
        val r = (color shr 16) and 0xFF
        val g = (color shr 8) and 0xFF
        val b = color and 0xFF
        // Relative luminance (ITU-R BT.709)
        val luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
        return luminance < 0.5
    }

    private fun isUuid(text: String): Boolean {
        return Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$").matches(text)
    }

    private fun cleanTitle(title: String): String {
        val trimmed = title.trim()
        return if (trimmed.isEmpty() || trimmed == untitledLabel || isUuid(trimmed)) untitledLabel else trimmed
    }

    private fun cleanPreview(preview: String): String {
        val trimmed = preview.trim()
        return if (trimmed.isEmpty() || isUuid(trimmed)) emptyLabel else trimmed
    }

    /// Maps the number of preview lines to a wrapper layout with a fixed height.
    /// The layout ID is also the view type used by RemoteViewsAdapter, so these
    /// layouts give the ListView one view type per height.
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

    /// Creates a Bitmap with a GradientDrawable (rounded corners + note color).
    /// The height matches the item's own layout height, so short notes keep
    /// short cards while every note has a deterministic, stable height.
    private fun createCardBitmap(context: Context, colorInt: Int, heightDp: Int): Bitmap {
        val density = context.resources.displayMetrics.density
        // Bitmap width = screen width − FrameLayout padding (12dp per side = 24dp total)
        val screenWidth = context.resources.displayMetrics.widthPixels
        val width = screenWidth - (24 * density).toInt()
        val height = (heightDp * density).toInt()

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val drawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = (24 * density).toFloat() // ~24dp, igual ao widget_background.xml
            setColor(colorInt)
        }
        drawable.setBounds(0, 0, width, height)
        drawable.draw(canvas)
        return bitmap
    }

    companion object {
        private const val TITLE_MAX_LINES = 1
        private const val PREVIEW_MAX_LINES = 8
        private const val TITLE_LINE_HEIGHT_DP = 22
        private const val PREVIEW_LINE_HEIGHT_DP = 18
        private const val CARD_PADDING_DP = 24
    }
}
