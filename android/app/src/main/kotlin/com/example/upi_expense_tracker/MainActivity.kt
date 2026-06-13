package com.example.upi_expense_tracker

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "sms_native_bridge"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			if (call.method == "getPendingTransactions") {
				val prefs = getSharedPreferences("upi_tracker_native_prefs", Context.MODE_PRIVATE)
				val pending = prefs.getString("pending_transactions", "[]") ?: "[]"
				prefs.edit().putString("pending_transactions", "[]").apply()
				result.success(pending)
			} else {
				result.notImplemented()
			}
		}
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
	}
}
