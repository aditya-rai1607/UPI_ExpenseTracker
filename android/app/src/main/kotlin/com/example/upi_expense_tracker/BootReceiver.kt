package com.example.upi_expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.shounakmulay.telephony.sms.IncomingSmsHandler

/**
 * Boot receiver that re-registers SMS listener callbacks after device reboot.
 * 
 * When the device boots, the telephony plugin's stored callback handles need to be
 * re-wired with the IncomingSmsHandler to ensure the background SMS listener continues
 * to work even if the app was closed before the reboot.
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Device booted, re-registering SMS listener callbacks")
            try {
                // Get SharedPreferences where telephony plugin stores callback handles
                val prefs = context?.getSharedPreferences(
                    "com.shounakmulay.android_telephony_plugin",
                    Context.MODE_PRIVATE
                )

                if (prefs != null) {
                    val setupHandle = prefs.getLong("background_setup_handle", -1L)
                    val messageHandle = prefs.getLong("background_message_handle", -1L)

                    if (setupHandle != -1L || messageHandle != -1L) {
                        Log.d(TAG, "Found stored callback handles: setupHandle=$setupHandle, messageHandle=$messageHandle")
                        
                        // Re-register the callbacks with IncomingSmsHandler
                        if (setupHandle != -1L) {
                            IncomingSmsHandler.setBackgroundSetupHandle(context, setupHandle)
                        }
                        if (messageHandle != -1L) {
                            IncomingSmsHandler.setBackgroundMessageHandle(context, messageHandle)
                        }
                        
                        Log.d(TAG, "SMS listener callbacks re-registered after boot")
                    } else {
                        Log.d(TAG, "No stored callback handles found in SharedPreferences")
                    }
                } else {
                    Log.w(TAG, "Could not access SharedPreferences for telephony plugin")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error re-registering SMS listener after boot", e)
            }
        }
    }
}
