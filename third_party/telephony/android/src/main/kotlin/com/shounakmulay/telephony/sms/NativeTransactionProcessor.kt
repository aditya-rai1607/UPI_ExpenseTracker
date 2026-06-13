package com.shounakmulay.telephony.sms

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.app.PendingIntent
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.*

object NativeTransactionProcessor {
    private const val PREFS_NAME = "upi_tracker_native_prefs"
    private const val KEY_PENDING = "pending_transactions"
    private const val KEY_SEEN = "seen_fingerprints"
    private const val CHANNEL_ID = "bank_txn"

    fun processAndQueue(context: Context, body: String?, sender: String?, timestamp: String?) {
        Log.d("NativeTransactionProcessor", "processAndQueue called | sender=$sender | body=${body?.take(60)}")
        val text = body ?: return
        val from = sender ?: ""
        val ts = timestamp?.toLongOrNull() ?: System.currentTimeMillis()

        if (!isBankSms(text, from)) {
            Log.d("NativeTransactionProcessor", "Not a bank SMS — ignored")
            return
        }

        val amount = extractAmount(text)
        if (amount <= 0.0) return

        val type = inferType(text)
        val merchant = extractMerchant(text)
        val bankRemark = if (text.length > 300) text.substring(0, 300) else text

        val txnId = UUID.randomUUID().toString()

        val txnJson = JSONObject()
        txnJson.put("id", txnId)
        txnJson.put("amount", amount)
        txnJson.put("merchant", merchant)
        txnJson.put("bankRemark", bankRemark)
        txnJson.put("category", JSONObject.NULL)
        txnJson.put("date", Date(ts).time)
        txnJson.put("type", type)
        txnJson.put("note", JSONObject.NULL)
        txnJson.put("createdAt", Date().time)

        val fingerprint = generateFingerprint(type, amount, bankRemark, merchant)

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val seen = loadSeenSet(prefs)
        if (seen.contains(fingerprint)) return

        // append to pending array — use commit() (synchronous) so the write survives
        // before Android reclaims the BroadcastReceiver process.
        val pending = JSONArray(prefs.getString(KEY_PENDING, "[]"))
        pending.put(txnJson)
        prefs.edit().putString(KEY_PENDING, pending.toString()).commit()

        // add to seen and trim
        seen.add(fingerprint)
        if (seen.size > 500) {
            val arr = ArrayList(seen)
            arr.removeAt(0)
            seen.clear()
            seen.addAll(arr)
        }
        prefs.edit().putString(KEY_SEEN, JSONArray(ArrayList(seen)).toString()).commit()

        Log.d("NativeTransactionProcessor", "Queued txn | type=$type | amount=$amount | merchant=$merchant | fingerprint=$fingerprint")

        // show notification
        showNotification(context, amount, merchant, type, txnId, txnJson.toString())
    }

    private fun loadSeenSet(prefs: SharedPreferences): LinkedHashSet<String> {
        val raw = prefs.getString(KEY_SEEN, "[]") ?: "[]"
        val arr = JSONArray(raw)
        val set = LinkedHashSet<String>()
        for (i in 0 until arr.length()) set.add(arr.optString(i))
        return set
    }

    private fun showNotification(context: Context, amount: Double, merchant: String, type: String, txnId: String, payload: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Bank Transactions"
            val descriptionText = "Alerts for bank transactions detected from incoming SMS"
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(CHANNEL_ID, name, importance)
            channel.description = descriptionText
            val nm = context.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }

        val title = "₹${String.format("%.2f", amount)} ${if (type == "credit") "Credited" else "Debited"}"
        val body = if (merchant.isNotEmpty()) "$merchant — tap to view" else "Transaction detected"

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            launchIntent.putExtra("native_txn_payload", payload)
        }

        val pendingIntent = PendingIntent.getActivity(context, txnId.hashCode(), launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(txnId.hashCode() and 0x7FFFFFFF, notification)
    }

    // --- Simple parser implementations ---
    private fun isBankSms(body: String, sender: String): Boolean {
        val lower = body.lowercase()
        val bankKeywords = listOf("debited", "credited", "inr", "rs", "upi", "credited to", "debited from")
        if (sender.isNotEmpty() && sender.length <= 7) return true
        return bankKeywords.any { lower.contains(it) } && extractAmount(body) > 0.0
    }

    private fun extractAmount(body: String): Double {
        // regex: (?:Rs\\.?|INR|₹)\\s*([\\d,]+\\.?\\d*)
        val re = Regex("(?:Rs\\.?|INR|₹)\\s*([\\d,]+\\.?\\d*)", RegexOption.IGNORE_CASE)
        val m = re.find(body)
        val s = m?.groups?.get(1)?.value ?: return 0.0
        return try { s.replace(",", "").toDouble() } catch (e: Exception) { 0.0 }
    }

    private fun inferType(body: String): String {
        val lower = body.lowercase()
        val debitKey = listOf("debited", "withdrawn", "deducted", "spent")
        val creditKey = listOf("credited", "received", "deposited", "refund")
        return when {
            debitKey.any { lower.contains(it) } -> "debit"
            creditKey.any { lower.contains(it) } -> "credit"
            else -> "debit"
        }
    }

    private fun extractMerchant(body: String): String {
        val upiRe = Regex("[A-Za-z0-9._-]+@[A-Za-z0-9._-]+")
        val m = upiRe.find(body)
        if (m != null) return m.value
        // look for 'at <merchant>' or 'to <merchant>' simple case
        val re = Regex("(?:at|to|for)\\s+([A-Za-z0-9 &.-]{3,40})", RegexOption.IGNORE_CASE)
        val mm = re.find(body)
        if (mm != null) return mm.groups[1]?.value?.trim() ?: ""
        return ""
    }

    private fun normalizeIdentity(s: String): String {
        return s.trim().lowercase().replace(Regex("\\s+"), " ")
    }

    private fun generateFingerprint(type: String, amount: Double, bankRemark: String, merchant: String): String {
        val identity = if (bankRemark.isNotEmpty()) normalizeIdentity(bankRemark) else normalizeIdentity(merchant)
        return "$type|${String.format("%.2f", amount)}|$identity"
    }
}
