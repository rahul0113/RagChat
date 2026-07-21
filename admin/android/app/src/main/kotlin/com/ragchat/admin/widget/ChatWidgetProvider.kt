package com.ragchat.admin.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.ragchat.admin.R

/**
 * 2x1 widget — Quick Chat button.
 * Opens the chat screen directly when tapped.
 */
class ChatWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_chat)

            // Set up click intent
            val clickIntent = WidgetClickReceiver.createIntent(
                context, WidgetClickReceiver.ACTION_OPEN_CHAT, "chat"
            )
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_chat_root, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_chat_button, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onEnabled(context: Context) {
        // Widget first added
    }

    override fun onDisabled(context: Context) {
        // Last instance removed
    }
}
