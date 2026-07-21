package com.ragchat.admin.widget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import com.ragchat.admin.MainActivity

/**
 * Handles click actions from all widgets.
 * Routes intents to MainActivity with deep link extras.
 */
class WidgetClickReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_OPEN_CHAT = "com.ragchat.admin.ACTION_OPEN_CHAT"
        const val ACTION_OPEN_UPLOAD = "com.ragchat.admin.ACTION_OPEN_UPLOAD"
        const val ACTION_OPEN_DASHBOARD = "com.ragchat.admin.ACTION_OPEN_DASHBOARD"
        const val ACTION_REFRESH = "com.ragchat.admin.ACTION_REFRESH"
        const val EXTRA_DESTINATION = "destination"

        fun createIntent(context: Context, action: String, destination: String): Intent {
            return Intent(context, WidgetClickReceiver::class.java).apply {
                this.action = action
                putExtra(EXTRA_DESTINATION, destination)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val destination = intent.getStringExtra(EXTRA_DESTINATION) ?: "dashboard"

        // Launch MainActivity with the destination
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra(EXTRA_DESTINATION, destination)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        context.startActivity(launchIntent)

        // Update widgets after action
        updateAllWidgets(context)
    }

    private fun updateAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val chatIds = manager.getAppWidgetIds(ComponentName(context, ChatWidgetProvider::class.java))
        val uploadIds = manager.getAppWidgetIds(ComponentName(context, UploadWidgetProvider::class.java))
        val statusIds = manager.getAppWidgetIds(ComponentName(context, StatusWidgetProvider::class.java))

        if (chatIds.isNotEmpty()) ChatWidgetProvider().onUpdate(context, manager, chatIds)
        if (uploadIds.isNotEmpty()) UploadWidgetProvider().onUpdate(context, manager, uploadIds)
        if (statusIds.isNotEmpty()) StatusWidgetProvider().onUpdate(context, manager, statusIds)
    }
}
