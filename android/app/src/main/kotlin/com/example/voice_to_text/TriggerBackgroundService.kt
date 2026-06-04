package com.example.voice_to_text

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioFormat
import android.media.MediaRecorder
import android.os.*
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.sqrt

class TriggerBackgroundService : Service() {
    
    // Recording state
    @Volatile private var isRecording = false
    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null

    companion object {
        private var lastVolumePressTime: Long = 0
        private var volumeUpCount = 0
        private const val VOLUME_THRESHOLD = 1500L // 1.5 seconds
    }

    private val volumeReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                val streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                if (streamType == AudioManager.STREAM_MUSIC || streamType == AudioManager.STREAM_RING) {
                    val currentVolume = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_VALUE", -1)
                    val prevVolume = intent.getIntExtra("android.media.EXTRA_PREV_VOLUME_STREAM_VALUE", -1)
                    
                    if (currentVolume != -1 && prevVolume != -1 && currentVolume != prevVolume) {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val maxVol = audioManager.getStreamMaxVolume(streamType)
                        val targetVol = maxVol / 2
                        
                        // Ignore volume changes that reset to targetVol
                        if (currentVolume == targetVol) return
                        
                        val now = SystemClock.elapsedRealtime()
                        val isVolumeUp = currentVolume > prevVolume
                        
                        try {
                            audioManager.setStreamVolume(streamType, targetVol, 0)
                        } catch (e: Exception) {}
                        
                        if (isRecording) {
                            // 1 click of EITHER Volume Up or Volume Down stops it immediately
                            stopActiveRecordingSession()
                        } else {
                            if (isVolumeUp) {
                                if (now - lastVolumePressTime > VOLUME_THRESHOLD) {
                                    volumeUpCount = 0
                                }
                                volumeUpCount++
                                lastVolumePressTime = now
                                
                                if (volumeUpCount >= 3) {
                                    volumeUpCount = 0
                                    triggerAppWakeup()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        
        val channelId = "trigger_service"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(channelId, "Voice Trigger Active", NotificationManager.IMPORTANCE_LOW)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Vichar AI Active")
            .setContentText("Listening for volume triggers")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .build()
            
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                1, 
                notification, 
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or 
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(1, notification)
        }

        setupVolumeReceiver()
    }

    private fun setupVolumeReceiver() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        try {
            val musicMax = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val ringMax = audioManager.getStreamMaxVolume(AudioManager.STREAM_RING)
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, musicMax / 2, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_RING, ringMax / 2, 0)
        } catch (e: Exception) {}

        val filter = android.content.IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        registerReceiver(volumeReceiver, filter)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // returning START_STICKY ensures the system recreates the service if it runs out of memory
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // This method executes when the user clears the app from the recent apps list
        val restartServiceIntent = Intent(applicationContext, this.javaClass).apply {
            setPackage(packageName)
        }
        
        // Use an explicit PendingIntent to reboot the foreground service immediately
        val restartServicePendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.getService(applicationContext, 1, restartServiceIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        } else {
            PendingIntent.getService(applicationContext, 1, restartServiceIntent, PendingIntent.FLAG_UPDATE_CURRENT)
        }
        
        val alarmService = applicationContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Fire off a wakeup alarm exactly 1 second after task removal to force reincarnation
        alarmService.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, SystemClock.elapsedRealtime() + 1000, restartServicePendingIntent)
        
        super.onTaskRemoved(rootIntent)
    }

    private fun triggerAppWakeup() {
        if (isRecording) return 
        vibrate(150) // Short vibration on start
        startRecording()
    }

    private fun stopActiveRecordingSession() {
        if (!isRecording) return
        isRecording = false
        lastVolumePressTime = 0 // prevent immediate re-trigger
    }

    private fun vibrate(duration: Long) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = android.media.AudioAttributes.Builder()
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                .build()
            vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE), audioAttributes)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(duration)
        }
    }

    private fun startRecording() {
        val sampleRate = 16000
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        
        val mediaDir = File(getDir("flutter", Context.MODE_PRIVATE), "Media")
        if (!mediaDir.exists()) mediaDir.mkdirs()
        
        val timestamp = System.currentTimeMillis()
        val pcmFile = File(mediaDir, "recording_$timestamp.pcm")
        val wavFile = File(mediaDir, "recording_$timestamp.wav")

        try {
            @Suppress("MissingPermission")
            val record = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate, channelConfig, audioFormat, minBufferSize * 2
            )
            audioRecord = record
            if (record.state == AudioRecord.STATE_UNINITIALIZED) {
                isRecording = false
                return
            }
            record.startRecording()
            isRecording = true
        } catch (e: Exception) {
            e.printStackTrace()
            isRecording = false
            return
        }

        recordingThread = Thread {
            val data = ByteArray(minBufferSize)
            var fos: FileOutputStream? = null
            try {
                fos = FileOutputStream(pcmFile)
                var silenceStartTime = -1L
                val silenceThresholdRMS = 250.0 
                val silenceDurationMax = 2000L // 2 seconds

                while (isRecording) {
                    val read = audioRecord?.read(data, 0, data.size) ?: 0
                    if (read > 0) {
                        fos.write(data, 0, read)
                        
                        var sum = 0.0
                        for (i in 0 until read step 2) {
                            if (i + 1 < read) {
                                val sample = (data[i].toInt() and 0xFF) or (data[i + 1].toInt() shl 8)
                                val shortSample = sample.toShort()
                                sum += shortSample * shortSample
                            }
                        }
                        val rms = sqrt(sum / (read / 2))
                        
                        if (rms < silenceThresholdRMS) {
                            if (silenceStartTime == -1L) {
                                silenceStartTime = System.currentTimeMillis()
                            } else if (System.currentTimeMillis() - silenceStartTime > silenceDurationMax) {
                                isRecording = false // Stop on silence
                            }
                        } else {
                            silenceStartTime = -1L
                        }
                    } else if (read < 0) {
                        isRecording = false
                        break
                    } else {
                        Thread.sleep(10)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                fos?.close()
                executeTeardownAndSave(pcmFile, wavFile, sampleRate)
            }
        }
        recordingThread?.start()
    }

    private fun executeTeardownAndSave(pcmFile: File, wavFile: File, sampleRate: Int) {
        try {
            audioRecord?.stop()
        } catch (e: Exception) {}
        audioRecord?.release()
        audioRecord = null
        isRecording = false
        
        vibrate(300) // Distinct confirmation vibration on stop
        
        pcmToWav(pcmFile, wavFile, sampleRate)
        pcmFile.delete() 
        
        sendToApi(wavFile)
    }

    private fun sendToApi(wavFile: File) {
        Thread {
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val proxyUrl = prefs.getString("flutter.api_url", "http://10.0.2.2:8000/api/transcribe")!!
                
                val boundary = "===${System.currentTimeMillis()}==="
                val url = URL(proxyUrl)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                
                val outputStream = connection.outputStream
                
                outputStream.write("--$boundary\r\n".toByteArray())
                outputStream.write("Content-Disposition: form-data; name=\"model\"\r\n\r\n".toByteArray())
                outputStream.write("saaras:v3\r\n".toByteArray())
                
                outputStream.write("--$boundary\r\n".toByteArray())
                outputStream.write("Content-Disposition: form-data; name=\"mode\"\r\n\r\n".toByteArray())
                outputStream.write("translate\r\n".toByteArray())
                
                outputStream.write("--$boundary\r\n".toByteArray())
                outputStream.write("Content-Disposition: form-data; name=\"file\"; filename=\"${wavFile.name}\"\r\n".toByteArray())
                outputStream.write("Content-Type: audio/wav\r\n\r\n".toByteArray())
                
                wavFile.inputStream().use { it.copyTo(outputStream) }
                outputStream.write("\r\n".toByteArray())
                outputStream.write("--$boundary--\r\n".toByteArray())
                
                outputStream.flush()
                outputStream.close()
                
                if (connection.responseCode == 200) {
                    val response = connection.inputStream.bufferedReader().readText()
                    val transcriptStart = response.indexOf("\"transcript\"") + 12
                    val colonIdx = response.indexOf(":", transcriptStart)
                    if (colonIdx > 0) {
                        val quoteStart = response.indexOf("\"", colonIdx) + 1
                        val quoteEnd = response.indexOf("\"", quoteStart)
                        
                        if (quoteStart > 0 && quoteEnd > quoteStart) {
                            val transcript = response.substring(quoteStart, quoteEnd)
                            saveTranscript(transcript, wavFile.absolutePath)
                        }
                    }
                }
                connection.disconnect()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }
    
    private fun saveTranscript(text: String, audioPath: String) {
        try {
            val mediaDir = File(getDir("flutter", Context.MODE_PRIVATE), "Media")
            if (!mediaDir.exists()) mediaDir.mkdirs()
            val jsonlFile = File(mediaDir, "transcriptions.jsonl")
            
            val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
            val cleanText = text.replace("\\", "\\\\").replace("\"", "\\\"")
            val cleanAudio = audioPath.replace("\\", "\\\\").replace("\"", "\\\"")
            
            val jsonLine = "{\"timestamp\": \"$timestamp\", \"text\": \"$cleanText\", \"audio_file\": \"$cleanAudio\"}\n"
            jsonlFile.appendText(jsonLine)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun pcmToWav(pcmFile: File, wavFile: File, sampleRate: Int) {
        try {
            val pcmData = pcmFile.readBytes()
            val wavOut = FileOutputStream(wavFile)
            
            val totalAudioLen = pcmData.size.toLong()
            val totalDataLen = totalAudioLen + 36
            val channels = 1
            val byteRate = 16 * sampleRate * channels / 8
            
            val header = ByteArray(44)
            header[0] = 'R'.code.toByte()
            header[1] = 'I'.code.toByte()
            header[2] = 'F'.code.toByte()
            header[3] = 'F'.code.toByte()
            header[4] = (totalDataLen and 0xff).toByte()
            header[5] = ((totalDataLen shr 8) and 0xff).toByte()
            header[6] = ((totalDataLen shr 16) and 0xff).toByte()
            header[7] = ((totalDataLen shr 24) and 0xff).toByte()
            header[8] = 'W'.code.toByte()
            header[9] = 'A'.code.toByte()
            header[10] = 'V'.code.toByte()
            header[11] = 'E'.code.toByte()
            header[12] = 'f'.code.toByte()
            header[13] = 'm'.code.toByte()
            header[14] = 't'.code.toByte()
            header[15] = ' '.code.toByte()
            header[16] = 16
            header[17] = 0
            header[18] = 0
            header[19] = 0
            header[20] = 1
            header[21] = 0
            header[22] = channels.toByte()
            header[23] = 0
            header[24] = (sampleRate and 0xff).toByte()
            header[25] = ((sampleRate shr 8) and 0xff).toByte()
            header[26] = ((sampleRate shr 16) and 0xff).toByte()
            header[27] = ((sampleRate shr 24) and 0xff).toByte()
            header[28] = (byteRate and 0xff).toByte()
            header[29] = ((byteRate shr 8) and 0xff).toByte()
            header[30] = ((byteRate shr 16) and 0xff).toByte()
            header[31] = ((byteRate shr 24) and 0xff).toByte()
            header[32] = (2 * 16 / 8).toByte()
            header[33] = 0
            header[34] = 16
            header[35] = 0
            header[36] = 'd'.code.toByte()
            header[37] = 'a'.code.toByte()
            header[38] = 't'.code.toByte()
            header[39] = 'a'.code.toByte()
            header[40] = (totalAudioLen and 0xff).toByte()
            header[41] = ((totalAudioLen shr 8) and 0xff).toByte()
            header[42] = ((totalAudioLen shr 16) and 0xff).toByte()
            header[43] = ((totalAudioLen shr 24) and 0xff).toByte()
            
            wavOut.write(header, 0, 44)
            wavOut.write(pcmData)
            wavOut.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(volumeReceiver)
        } catch (e: Exception) {}
        isRecording = false
        audioRecord?.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}