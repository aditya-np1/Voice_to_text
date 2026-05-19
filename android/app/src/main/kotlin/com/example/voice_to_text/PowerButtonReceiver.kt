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
        
        val action = intent.action
        if (action == Intent.ACTION_SCREEN_OFF || action == Intent.ACTION_SCREEN_ON) {
            val now = SystemClock.elapsedRealtime()
            
            if (now - lastPressTime < THRESHOLD) {
                pressCount++
            } else {
                pressCount = 1
            }
            lastPressTime = now

            if (pressCount >= 3) {
                pressCount = 0
                val triggerIntent = Intent("com.yourapp.TRIGGER_FIRED")
                triggerIntent.setPackage(context.packageName)
                context.sendBroadcast(triggerIntent)
            }
        }
    }
}
