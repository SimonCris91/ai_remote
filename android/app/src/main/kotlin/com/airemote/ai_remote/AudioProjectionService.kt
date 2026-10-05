package com.airemote.ai_remote

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Binder
import android.os.IBinder

/**
 * Keeps Android's MediaProjection permission valid while AI Remote analyzes
 * audio from another app with the phone screen locked.
 */
class AudioProjectionService : Service() {
    private val channelId = "com.airemote.audio_capture"
    private val notificationId = 4101
    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun service(): AudioProjectionService = this@AudioProjectionService
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("AI Remote")
            .setContentText("Analisi accordi in corso")
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(notificationId, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_NOT_STICKY

    override fun onBind(intent: Intent?): IBinder = binder

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                channelId,
                "Analisi audio AI Remote",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }
}
