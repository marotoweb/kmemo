package com.marotoweb.kmemo

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import android.content.SharedPreferences

class KMemoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return KMemoWidgetFactory(this.applicationContext)
    }
}

class KMemoWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var titlesList = ArrayList<String>()
    private var previewsList = ArrayList<String>()

    private fun loadDataFromFlutter() {
        titlesList.clear()
        previewsList.clear()

        val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        val titlesJson = prefs.getString("notes_titles", "[]")
        val previewsJson = prefs.getString("notes_previews", "[]")

        try {
            val titlesArray = JSONArray(titlesJson)
            val previewsArray = JSONArray(previewsJson)

            for (i in 0 until titlesArray.length()) {
                titlesList.add(titlesArray.optString(i, "Sem título"))
                previewsList.add(previewsArray.optString(i, ""))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onCreate() {
        loadDataFromFlutter()
    }

    override fun onDataSetChanged() {
        loadDataFromFlutter()
    }

    override fun onDestroy() {
        titlesList.clear()
        previewsList.clear()
    }

    override fun getCount(): Int = titlesList.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, android.R.layout.simple_list_item_2)
        
        if (position < titlesList.size) {
            views.setTextViewText(android.R.id.text1, titlesList[position])
            views.setTextViewText(android.R.id.text2, previewsList[position])
        }
        
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}