// android/app/src/main/kotlin/com/marotoweb/kmemo/KMemoWidgetService.kt
package com.marotoweb.kmemo

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.GradientDrawable
import android.os.Environment
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
    }

    override fun onDestroy() {}

    override fun getCount(): Int = notes.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.kmemo_widget_item)

        if (position >= notes.size) return views

        val note = notes[position]

        try {
            views.setTextViewText(R.id.widget_item_title, note.title)
            views.setTextViewText(R.id.widget_item_preview, note.preview)

            // Respect editor options: line wrapping
            val titleMaxLines = if (autoWrap) 2 else 1
            val previewMaxLines = if (autoWrap) 8 else 1
            views.setInt(R.id.widget_item_title, "setMaxLines", titleMaxLines)
            views.setInt(R.id.widget_item_preview, "setMaxLines", previewMaxLines)

            // Set the text color according to the background luminance
            val isDarkBg = isColorDark(note.colorInt)
            val titleColor = if (isDarkBg) 0xFFFFFFFF.toInt() else 0xFF1F1F1F.toInt()
            val previewColor = if (isDarkBg) 0xFFE0E0E0.toInt() else 0xFF444444.toInt()
            views.setTextColor(R.id.widget_item_title, titleColor)
            views.setTextColor(R.id.widget_item_preview, previewColor)

            // Dynamic background with rounded corners + note color
            val cardBitmap = createCardBitmap(context, note.colorInt, note.preview)
            views.setImageViewBitmap(R.id.widget_item_bg, cardBitmap)

            // Force the background ImageView height to match the bitmap
            val bitmapHeight = cardBitmap.height
            views.setInt(R.id.widget_item_bg, "setMinimumHeight", bitmapHeight)

            // Force the root FrameLayout to be at least as tall as the bitmap
            views.setInt(R.id.widget_item_root, "setMinimumHeight", bitmapHeight)

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
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

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

    /// Creates a Bitmap with a GradientDrawable (rounded corners + note color)
    /// The height is adjusted to the amount of text so it covers title + preview
    /// Layout: title (1 line) + content (max 8 lines) + "..." (1 line) when truncated
    /// All dp values are converted to pixels using the screen density.
    private fun createCardBitmap(context: Context, colorInt: Int, previewText: String): Bitmap {
        val density = context.resources.displayMetrics.density
        // Bitmap width = screen width − FrameLayout padding (12dp per side = 24dp total)
        val screenWidth = context.resources.displayMetrics.widthPixels
        val width = screenWidth - (24 * density).toInt()

        // Count real line breaks in the text to estimate visual lines (minimum 2, maximum 9)
        val previewLines = if (previewText.isEmpty() || previewText == emptyLabel) {
            2
        } else {
            val actualLines = previewText.count { it == '\n' } + 1
            actualLines.coerceAtLeast(2).coerceAtMost(9)
        }

        // Title: 1 line (~24dp) + preview: N lines (~22dp each) + padding (~24dp)
        // Line height increased to 22dp to fully cover the rendered text
        // 24dp padding for a sufficient bottom margin
        val titleHeight = (24 * density).toInt()
        val lineHeight = (22 * density).toInt()
        val padding = (24 * density).toInt()
        val height = titleHeight + (previewLines * lineHeight) + padding

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
}
