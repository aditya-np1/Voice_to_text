package com.example.voice_to_text

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock

class PowerButtonReceiver : BroadcastReceiver() {
    companion object {
        private var pressCount = 0
        private var lastPressTime: Long = 0
        private const val THRESHOLD = 1000L // 1 second
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        
        val intentAction = intent.action
        if (intentAction == Intent.ACTION_SCREEN_OFF || intentAction == Intent.ACTION_SCREEN_ON) {
            val now = SystemClock.elapsedRealtime()
            
            if (now - lastPressTime < THRESHOLD) {
                pressCount++
            } else {
                pressCount = 1
            }
            lastPressTime = now

            if (pressCount >= 3) {
                pressCount = 0
                // Send intent to TriggerBackgroundService to handle wake-up safely
                val serviceIntent = Intent(context, TriggerBackgroundService::class.java).apply {
                    action = "com.example.voice_to_text.TRIGGER_WAKEUP"
                }
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}
