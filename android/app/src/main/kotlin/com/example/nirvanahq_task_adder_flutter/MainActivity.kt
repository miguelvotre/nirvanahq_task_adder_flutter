package com.example.nirvanahq_task_adder_flutter

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.nirvanahq_task_adder_flutter/share"
    private var sharedText: String? = null
    private var pageTitle: String? = null
    private var pageUrl: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    // Get the shared URL
                    pageUrl = intent.getStringExtra(Intent.EXTRA_TEXT)
                    
                    // Get the title if available
                    pageTitle = intent.getStringExtra(Intent.EXTRA_SUBJECT)
                    
                    // If we have both title and URL, prepare them in JSON format for Flutter
                    if (pageTitle != null && pageUrl != null) {
                        val jsonObject = JSONObject()
                        jsonObject.put("title", pageTitle)
                        jsonObject.put("url", pageUrl)
                        sharedText = jsonObject.toString()
                    } else if (pageUrl != null) {
                        // If we only have the URL, we'll just use that
                        val jsonObject = JSONObject()
                        jsonObject.put("title", "")
                        jsonObject.put("url", pageUrl)
                        sharedText = jsonObject.toString()
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSharedText") {
                result.success(sharedText)
                sharedText = null
            } else {
                result.notImplemented()
            }
        }
    }
}
