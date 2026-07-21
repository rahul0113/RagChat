package com.ragchat.admin

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Main activity that handles deep links from widgets and Quick Settings tile.
 * Passes navigation commands to Flutter via MethodChannel.
 */
class MainActivity: FlutterActivity() {

    private val CHANNEL = "com.ragchat.admin/navigation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialDestination" -> {
                        result.success(handleIntent(intent))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle cold start from widget/tile
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Notify Flutter of new destination via method channel
        val destination = handleIntent(intent)
        if (destination != "dashboard") {
            flutterEngine?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("navigateTo", destination)
            }
        }
    }

    /**
     * Extracts the navigation destination from the incoming intent.
     * Returns the destination string to pass to Flutter.
     */
    private fun handleIntent(intent: Intent?): String {
        if (intent == null) return "dashboard"

        // Check for deep link scheme
        if (intent.data?.scheme == "ragchat") {
            return when (intent.data?.host) {
                "chat" -> "chat"
                "upload" -> "upload"
                else -> "dashboard"
            }
        }

        // Check for explicit destination extra
        return intent.getStringExtra("destination") ?: "dashboard"
    }
}
