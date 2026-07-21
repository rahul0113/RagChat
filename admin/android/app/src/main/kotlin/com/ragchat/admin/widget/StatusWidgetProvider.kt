package com.ragchat.admin.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.ragchat.admin.R

/**
 * 4x1 widget — App Dashboard with status.
 * Shows app status and provides quick access to dashboard.
 */
class StatusWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_status)

            // Set status text
            views.setTextViewText(R.id.widget_status_title, "RagChat")
            views.setTextViewText(R.id.widget_status_subtitle, "Tap to open dashboard")

            // Dashboard click
            val dashboardIntent = WidgetClickReceiver.createIntent(
                context, WidgetClickReceiver.ACTION_OPEN_DASHBOARD, "dashboard"
            )
            val dashboardPending = PendingIntent.getBroadcast(
                context, 2, dashboardIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_status_root, dashboardPending)

            // Chat button
            val chatIntent = WidgetClickReceiver.createIntent(
                context, WidgetClickReceiver.ACTION_OPEN_CHAT, "chat"
            )
            val chatPending = PendingIntent.getBroadcast(
                context, 3, chatIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_status_chat_btn, chatPending)

            // Upload button
            val uploadIntent = WidgetClickReceiver.createIntent(
                context, WidgetClickReceiver.ACTION_OPEN_UPLOAD, "upload"
            )
            val uploadPending = PendingIntent.getBroadcast(
                context, 4, uploadIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_status_upload_btn, uploadPending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
