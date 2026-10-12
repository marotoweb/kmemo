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

            // Fundo dinâmico com cantos arredondados + cor da nota
            val cardBitmap = createCardBitmap(context, note.colorInt, note.preview)
            views.setImageViewBitmap(R.id.widget_item_bg, cardBitmap)

            // Força a altura do ImageView de fundo para corresponder ao bitmap
            val bitmapHeight = cardBitmap.height
            views.setInt(R.id.widget_item_bg, "setMinimumHeight", bitmapHeight)

            // Força o FrameLayout raiz a ter pelo menos a altura do bitmap
            views.setInt(R.id.widget_item_root, "setMinimumHeight", bitmapHeight)

            // PendingIntent individual para abrir esta nota específica via App Link
            val fillInIntent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("kmemo://note/${note.uuid}")
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
        // O Dart grava em getApplicationDocumentsDirectory() que no Android é
        // <filesDir>/../app_flutter/ (ex: /data/user/0/pkg/app_flutter/)
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

    private fun isUuid(text: String): Boolean {
        return Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$").matches(text)
    }

    private fun cleanTitle(title: String): String {
        val trimmed = title.trim()
        return if (trimmed.isEmpty() || trimmed == "Sem título" || isUuid(trimmed)) "Sem título" else trimmed
    }

    private fun cleanPreview(preview: String): String {
        val trimmed = preview.trim()
        return if (trimmed.isEmpty() || isUuid(trimmed)) "Nota vazia" else trimmed
    }

    /// Cria um Bitmap com GradientDrawable (cantos arredondados + cor da nota)
    /// A altura é ajustada com base na quantidade de texto para cobrir título + preview
    /// Estrutura: Título(1 linha) + Conteúdo(máx 8 linhas) + "..."(1 linha) se truncado
    /// Todos os valores em dp são convertidos para pixels usando a densidade da tela.
    private fun createCardBitmap(context: Context, colorInt: Int, previewText: String): Bitmap {
        val density = context.resources.displayMetrics.density
        // Largura do bitmap = largura do ecrã − padding do FrameLayout (12dp cada lado = 24dp total)
        val screenWidth = context.resources.displayMetrics.widthPixels
        val width = screenWidth - (24 * density).toInt()

        // Conta quebras de linha reais no texto para estimar linhas visuais (mínimo 2, máximo 9)
        val previewLines = if (previewText.isEmpty() || previewText == "Nota vazia") {
            2
        } else {
            val actualLines = previewText.count { it == '\n' } + 1
            actualLines.coerceAtLeast(2).coerceAtMost(9)
        }

        // Título: 1 linha (~24dp) + preview: N linhas (~22dp cada) + padding (~24dp)
        // Linha height aumentada para 22dp para garantir cobertura completa do texto renderizado
        // Padding de 24dp para margem inferior suficiente
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
