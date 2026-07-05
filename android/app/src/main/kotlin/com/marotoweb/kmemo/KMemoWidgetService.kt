package com.marotoweb.kmemo

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import com.marotoweb.kmemo.R

class KMemoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return KMemoWidgetFactory(this.applicationContext)
    }
}

class KMemoWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var titlesList = JSONArray()
    private var previewsList = JSONArray()
    private var colorsList = JSONArray()
    private var bgImagesList = JSONArray()

    // Palete completa com os 16 índices de cores correspondentes à aplicação
    private val colorsPalette = arrayOf(
        "#FFF8E7", // 0 - Laranja / Creme
        "#FFFDE7", // 1 - Amarelo
        "#E3F2FD", // 2 - Azul
        "#F3E5F5", // 3 - Rosa / Roxo
        "#E8F5E9", // 4 - Verde
        "#FFE0B2", // 5
        "#F5F5F5", // 6
        "#E0F2F1", // 7
        "#EBF1FA", // 8
        "#FCE4EC", // 9
        "#FFF3E0", // 10
        "#F1F8E9", // 11
        "#E0F7FA", // 12
        "#EEEEEE", // 13
        "#F9FBE7", // 14
        "#FFFFFF"  // 15 - Branco / Padrão
    )

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        val titlesJson = prefs.getString("flutter.notes_titles", null) ?: prefs.getString("notes_titles", "[]")
        val previewsJson = prefs.getString("flutter.notes_previews", null) ?: prefs.getString("notes_previews", "[]")
        val colorsJson = prefs.getString("flutter.notes_colors", null) ?: prefs.getString("notes_colors", "[]")
        val bgImagesJson = prefs.getString("flutter.notes_bg_images", null) ?: prefs.getString("notes_bg_images", "[]")

        try {
            titlesList = JSONArray(titlesJson)
            previewsList = JSONArray(previewsJson)
            colorsList = JSONArray(colorsJson)
            bgImagesList = JSONArray(bgImagesJson)
        } catch (e: Exception) {
            titlesList = JSONArray()
            previewsList = JSONArray()
            colorsList = JSONArray()
            bgImagesList = JSONArray()
            e.printStackTrace()
        }
    }

    override fun onDestroy() {}

    override fun getCount(): Int = titlesList.length()

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= getCount()) {
            return RemoteViews(context.packageName, R.layout.kmemo_widget_item)
        }

        val views = RemoteViews(context.packageName, R.layout.kmemo_widget_item)
    
        try {
            val title = titlesList.optString(position, "Sem título")
            val preview = previewsList.optString(position, "")
            val colorIdx = colorsList.optInt(position, 15) // Fallback para o índice 15 se falhar

            views.setTextViewText(R.id.widget_item_title, title)
            views.setTextViewText(R.id.widget_item_preview, preview)

            // Valida se o índice está dentro do intervalo das 16 cores
            val colorHex = if (colorIdx in colorsPalette.indices) colorsPalette[colorIdx] else "#FFFFFF"
            
            // Aplica dinamicamente a cor de fundo ao contentor
            views.setInt(R.id.widget_item_container, "setBackgroundColor", Color.parseColor(colorHex))
            
            // Garante contraste com texto escuro
            views.setTextColor(R.id.widget_item_title, Color.parseColor("#1A1A1A"))
            views.setTextColor(R.id.widget_item_preview, Color.parseColor("#4A4A4A"))

        } catch (e: Exception) {
            e.printStackTrace()
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}