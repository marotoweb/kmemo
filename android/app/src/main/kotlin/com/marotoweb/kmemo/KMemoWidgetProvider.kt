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

            // Configura o adapter para a ListView com RemoteViewsService
            val serviceIntent = Intent(context, KMemoWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_notes_list, serviceIntent)
            views.setEmptyView(R.id.widget_notes_list, android.R.id.empty)

            // Clica em qualquer parte abre a app com nota específica via fillInIntent
            // NÃO colocar note_uuid aqui - o fillInIntent do serviço adiciona o UUID real
            // Com FLAG_IMMUTABLE, o fillInIntent só pode adicionar extras que NÃO estão no template
            Log.d("WIDGET_DEBUG", "Widget provider: creating template for appWidgetId=$appWidgetId")
            val clickIntent = Intent(context, MainActivity::class.java).apply {
                action = "ACTION_OPEN_NOTE"
            }
            val clickPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_notes_list, clickPendingIntent)
            Log.d("WIDGET_DEBUG", "Widget provider: template set for appWidgetId=$appWidgetId")

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
