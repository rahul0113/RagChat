package com.ragchat.admin.tile

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.ragchat.admin.MainActivity

/**
 * Quick Settings tile for RagChat.
 * Appears in the notification shade alongside Wi-Fi, Bluetooth, etc.
 * Tapping opens the chat screen directly.
 */
class RagChatTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        tile.label = "RagChat"
        tile.contentDescription = "Open RagChat"
        tile.state = Tile.STATE_ACTIVE
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()

        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("destination", "chat")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        startActivityAndCollapse(pendingIntent)
    }

    override fun onStopListening() {
        super.onStopListening()
    }
}
