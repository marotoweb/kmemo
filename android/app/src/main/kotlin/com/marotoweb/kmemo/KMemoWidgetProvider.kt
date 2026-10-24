// android/app/src/main/kotlin/com/marotoweb/kmemo/KMemoWidgetProvider.kt
package com.marotoweb.kmemo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews

class KMemoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d("KMemoWidget", "onUpdate called with ${appWidgetIds.size} widgets")

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.kmemo_widget)

            // Configure the adapter for the ListView with RemoteViewsService
            val serviceIntent = Intent(context, KMemoWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_notes_list, serviceIntent)
            views.setEmptyView(R.id.widget_notes_list, android.R.id.empty)

            // Tapping anywhere opens the app at the specific note via fillInIntent
            // Do NOT put note_uuid here - the service's fillInIntent adds the real UUID
            // With FLAG_MUTABLE, fillInIntent can only add extras that are NOT in the template
            Log.d("WIDGET_DEBUG", "Widget provider: creating template for appWidgetId=$appWidgetId")
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
            Log.d("WIDGET_DEBUG", "Widget provider: template set for appWidgetId=$appWidgetId")

            // Detect the system theme (light/dark)
            val isDarkMode = (context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES

            // "+" button to create a new note - colors identical to the FAB in home_screen.dart
            val addIntent = Intent(context, MainActivity::class.java).apply {
                action = "ACTION_CREATE_NOTE"
            }
            val addPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 1000, // Offset para não conflitar com o template
                addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_add_button, addPendingIntent)

            // Set the "+" button background drawable by theme (same as the app FAB)
            val bgDrawable = if (isDarkMode) R.drawable.widget_add_button_bg_dark else R.drawable.widget_add_button_bg_light
            views.setInt(R.id.widget_add_button, "setBackgroundResource", bgDrawable)
            // Set the "+" text color by theme
            val textColor = if (isDarkMode) 0xB3FFFFFF.toInt() else 0xDE000000.toInt()
            views.setTextColor(R.id.widget_add_button_text, textColor)
            Log.d("WIDGET_DEBUG", "Widget provider: add button set for appWidgetId=$appWidgetId (dark=$isDarkMode)")

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("KMemoWidget", "onReceive called: action=${intent.action}")
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            Log.d("KMemoWidget", "Received APPWIDGET_UPDATE, notifying view data changed")
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, KMemoWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            appWidgetManager.notifyAppWidgetViewDataChanged(
                widgetIds,
                R.id.widget_notes_list
            )
        }
    }
}
