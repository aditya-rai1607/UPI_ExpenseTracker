package com.example.upi_expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Fallback native SMS receiver that captures incoming bank SMS into a
 * SharedPreferences queue while the Flutter/Dart background isolate is
 * unavailable (e.g. first install, force-stop, or before background
 * isolate registers its callback handles).
 *
 * The queue is drained via NativeSmsBridge.getPendingSmsMessages() once
 * the app opens and the Dart layer calls drainNativeQueue().
 *
 * This works alongside the telephony plugin's IncomingSmsReceiver.
 * The isDuplicate() check on the Dart side prevents double-storage.
 */
class NativeSmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "NativeSmsReceiver"
        private const val PREFS_NAME = "upi_tracker_native_prefs"
        private const val PENDING_SMS_KEY = "pending_sms"

        // Basic filter: only queue SMS that look like bank/financial messages.
        // Full parsing is done on the Dart side when the queue is drained.
        private val BANK_KEYWORDS = listOf(
            "debited", "credited", "deducted", "withdrawn", "spent",
            "received", "refund", "deposited", "upi", "neft", "imps",
            "rtgs", "inr", "rs.", "₹"
        )
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (context == null) return

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                ?: return

            // Concatenate multi-part message fragments into a single body.
            val body = messages.joinToString("") { it.messageBody ?: "" }
            val sender = messages.firstOrNull()?.originatingAddress ?: ""

            if (body.isBlank()) return

            // Only queue SMS that contain bank/payment keywords.
            val lowerBody = body.lowercase()
            val isLikelyBank = BANK_KEYWORDS.any { lowerBody.contains(it) }
            if (!isLikelyBank) return

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existing = prefs.getString(PENDING_SMS_KEY, "[]") ?: "[]"
            val list = JSONArray(existing)

            val entry = JSONObject().apply {
                put("body", body)
                put("sender", sender)
                put("timestamp", System.currentTimeMillis())
            }
            list.put(entry)

            prefs.edit().putString(PENDING_SMS_KEY, list.toString()).apply()
            Log.d(TAG, "Queued bank SMS from $sender (queue size: ${list.length()})")
        } catch (e: Exception) {
            Log.e(TAG, "Error queueing SMS in native fallback receiver", e)
        }
    }
}
