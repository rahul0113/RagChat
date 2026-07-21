package com.ragchat.admin.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.ragchat.admin.R

/**
 * 2x1 widget — Quick Upload button.
 * Opens the document upload screen when tapped.
 */
class UploadWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_upload)

            val clickIntent = WidgetClickReceiver.createIntent(
                context, WidgetClickReceiver.ACTION_OPEN_UPLOAD, "upload"
            )
            val pendingIntent = PendingIntent.getBroadcast(
                context, 1, clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_upload_root, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_upload_button, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
