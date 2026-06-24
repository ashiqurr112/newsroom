package com.newsroom.newsroom

import io.flutter.embedding.android.FlutterActivity

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import java.lang.Exception

class MainActivity : FlutterActivity() {
    private val CHANNEL = "newsroom/browser_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launchQuetta") {
                val url = call.argument<String>("url")
                if (url != null) {
                    val success = launchQuettaBrowser(url)
                    result.success(success)
                } else {
                    result.error("BAD_ARGS", "URL was null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun launchQuettaBrowser(url: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.setPackage("net.quetta.browse")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
