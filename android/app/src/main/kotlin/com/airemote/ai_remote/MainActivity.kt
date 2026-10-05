package com.airemote.ai_remote

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Build.VERSION_CODES
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : AudioServiceActivity() {
    private val methodChannelName = "com.airemote/audio_playback"
    private val eventChannelName = "com.airemote/audio_playback/events"
    private val screenAwakeChannelName = "com.airemote/screen_awake"
    private val watchDisplayChannelName = "com.airemote/watch_display"
    private val watchDisplayNotificationId = 7101
    private val mediaProjectionRequestCode = 4091
    private val audioPermissionRequestCode = 4092
    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingStartResult: MethodChannel.Result? = null
    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private val captureRunning = AtomicBoolean(false)
    private var projectionServiceStarted = false
    private var projectionServiceBound = false
    private var projectionServiceConnection: ServiceConnection? = null
    private var pendingWatchDisplay: Triple<String, String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        ).also { channel ->
            channel.setMethodCallHandler(::handleMethodCall)
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenAwakeChannelName,
        ).setMethodCallHandler { call, result ->
            if (call.method != "setEnabled") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val enabled = call.arguments as? Boolean ?: false
            if (enabled) {
                window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            result.success(null)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            watchDisplayChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val args = call.arguments as? Map<*, *>
                    publishWatchDisplay(
                        args?.get("title") as? String ?: "AI Remote",
                        args?.get("subtitle") as? String ?: "",
                        args?.get("content") as? String ?: "",
                    )
                    result.success(null)
                }
                "clear" -> {
                    pendingWatchDisplay = null
                    getSystemService(NotificationManager::class.java)
                        .cancel(watchDisplayNotificationId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun publishWatchDisplay(title: String, subtitle: String, content: String) {
        pendingWatchDisplay = Triple(title, subtitle, content)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4093)
            return
        }
        val channelId = "ai_remote_live_display"
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "AI Remote live display",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        val notification = Notification.Builder(this, channelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(content)
            .setSubText(subtitle)
            .setOngoing(true)
            // Zepp often forwards only real notification updates. Do not
            // mark chord/pitch changes as silent one-time updates.
            .setOnlyAlertOnce(false)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(false)
            .setPriority(Notification.PRIORITY_DEFAULT)
            .setCategory(Notification.CATEGORY_STATUS)
            .build()
        manager.notify(watchDisplayNotificationId, notification)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4093 &&
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        ) {
            pendingWatchDisplay?.let { (title, subtitle, content) ->
                publishWatchDisplay(title, subtitle, content)
            }
            return
        }
        if (requestCode != audioPermissionRequestCode) return
        val result = pendingStartResult ?: return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            startActivityForResult(
                manager.createScreenCaptureIntent(),
                mediaProjectionRequestCode,
            )
        } else {
            pendingStartResult = null
            result.error("PERMISSION_DENIED", "Permesso microfono negato.", null)
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> startCapture(result)
            "stop" -> {
                stopCapture()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startCapture(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("UNSUPPORTED", "Serve Android 10 o superiore.", null)
            return
        }
        if (captureRunning.get()) {
            result.success(null)
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingStartResult = result
            requestPermissions(
                arrayOf(Manifest.permission.RECORD_AUDIO),
                audioPermissionRequestCode,
            )
            return
        }
        pendingStartResult = result
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(
            manager.createScreenCaptureIntent(),
            mediaProjectionRequestCode,
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != mediaProjectionRequestCode) return
        val result = pendingStartResult
        pendingStartResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result?.error("CONSENT_DENIED", "Cattura audio non autorizzata.", null)
            return
        }
        startProjectionService(resultCode, data, result)
    }

    private fun startAudioReader(projection: MediaProjection) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val sampleRate = 24_000
        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
            .build()
        val captureConfig = AudioPlaybackCaptureConfiguration.Builder(projection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()
        val minimumBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufferSize = (minimumBuffer.coerceAtLeast(sampleRate / 2) * 2)
        audioRecord = AudioRecord.Builder()
            .setAudioFormat(format)
            .setBufferSizeInBytes(bufferSize)
            .setAudioPlaybackCaptureConfig(captureConfig)
            .build()
        val record = audioRecord ?: error("AudioRecord non disponibile")
        captureRunning.set(true)
        record.startRecording()
        captureThread = Thread {
            val buffer = ByteArray(4096)
            while (captureRunning.get() && !Thread.currentThread().isInterrupted) {
                val count = record.read(buffer, 0, buffer.size)
                if (count > 0) {
                    val chunk = buffer.copyOf(count)
                    mainHandler.post { eventSink?.success(chunk) }
                } else if (count < 0) {
                    mainHandler.post {
                        eventSink?.error(
                            "AUDIO_READ_FAILED",
                            "Lettura dell’audio di sistema fallita.",
                            count,
                        )
                    }
                    break
                }
            }
        }.also { it.name = "ai-remote-audio-capture" }
        captureThread?.start()
    }

    private fun stopCapture() {
        captureRunning.set(false)
        captureThread?.interrupt()
        captureThread = null
        audioRecord?.let { record ->
            try {
                if (record.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    record.stop()
                }
            } catch (_: IllegalStateException) {
                // The capture may already have been revoked by Android.
            }
            record.release()
        }
        audioRecord = null
        mediaProjection?.stop()
        mediaProjection = null
        if (projectionServiceBound) {
            projectionServiceConnection?.let { connection ->
                unbindService(connection)
            }
            projectionServiceBound = false
            projectionServiceConnection = null
        }
        if (projectionServiceStarted) {
            stopService(Intent(this, AudioProjectionService::class.java))
            projectionServiceStarted = false
        }
    }

    private fun startProjectionService(
        resultCode: Int,
        data: Intent,
        result: MethodChannel.Result?,
    ) {
        val intent = Intent(this, AudioProjectionService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                @Suppress("DEPRECATION")
                startService(intent)
            }
            projectionServiceStarted = true
            val connection = object : ServiceConnection {
                override fun onServiceConnected(
                    name: ComponentName?,
                    service: android.os.IBinder?,
                ) {
                    projectionServiceBound = true
                    try {
                        @Suppress("DEPRECATION")
                        val manager = getSystemService(
                            Context.MEDIA_PROJECTION_SERVICE,
                        ) as MediaProjectionManager
                        mediaProjection = manager.getMediaProjection(resultCode, data)
                        startAudioReader(mediaProjection!!)
                        result?.success(null)
                    } catch (error: Exception) {
                        stopCapture()
                        result?.error("CAPTURE_FAILED", error.message, null)
                    }
                }

                override fun onServiceDisconnected(name: ComponentName?) {
                    projectionServiceBound = false
                }
            }
            projectionServiceConnection = connection
            bindService(intent, connection, Context.BIND_AUTO_CREATE)
        } catch (error: Exception) {
            stopCapture()
            result?.error("CAPTURE_FAILED", error.message, null)
        }
    }

    override fun onDestroy() {
        stopCapture()
        methodChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
