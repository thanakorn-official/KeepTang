package com.example.expense_tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var thaiOcrChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        thaiOcrChannel = ThaiSlipTextRecognizer.register(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        thaiOcrChannel?.setMethodCallHandler(null)
        thaiOcrChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
