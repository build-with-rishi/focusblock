package com.rishi.focusblock

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Foreground service that polls CalendarContract every 60 seconds and fires a
 * full-screen-intent notification when an event is 30/10/5 minutes away
 * (within a +/- 1 minute tolerance, matching the macOS implementation).
 */
class MonitorService : Service() {

    companion object {
        const val CHANNEL_MONITOR = "monitor"
        const val CHANNEL_ALERTS = "alerts"
        private const val ONGOING_NOTIFICATION_ID = 1
        private const val POLL_INTERVAL_MS = 60_000L
        private const val LOOK_AHEAD_MS = 35 * 60 * 1000L

        fun start(context: Context) {
            context.startForegroundService(Intent(context, MonitorService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val pollRunnable = object : Runnable {
        override fun run() {
            checkEvents()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannels()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                ONGOING_NOTIFICATION_ID,
                buildOngoingNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(ONGOING_NOTIFICATION_ID, buildOngoingNotification())
        }
        handler.post(pollRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    private fun checkEvents() {
        if (!CalendarRepository.hasPermission(this)) return
        val now = System.currentTimeMillis()
        val instances = CalendarRepository.instancesBetween(this, now, now + LOOK_AHEAD_MS)
        val windows = Prefs.enabledWindows(this)

        for (instance in instances) {
            val minutesUntil = ((instance.beginMs - now) / 60_000L).toInt()
            if (minutesUntil < 0) continue
            for (window in windows) {
                if (minutesUntil in (window - 1)..(window + 1)) {
                    val key = Prefs.triggerKey(instance.eventId, instance.beginMs, window)
                    if (!Prefs.hasFired(this, key)) {
                        Prefs.markFired(this, key, now)
                        // 0 means "no notification" to OverlayActivity, and 1 is
                        // the ongoing service notification — avoid both.
                        val id = key.hashCode().let {
                            if (it == 0 || it == ONGOING_NOTIFICATION_ID) it + 2 else it
                        }
                        fireFullScreenAlert(instance, window, id)
                    }
                }
            }
        }
    }

    private fun fireFullScreenAlert(instance: EventInstance, window: Int, notificationId: Int) {
        val overlayIntent = OverlayActivity.createIntent(
            this, instance.title, instance.beginMs, instance.endMs, window, notificationId
        )
        val fullScreenPending = PendingIntent.getActivity(
            this,
            notificationId,
            overlayIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ALERTS)
            .setSmallIcon(R.drawable.ic_stat_focusblock)
            .setContentTitle(instance.title)
            .setContentText(getString(R.string.alert_notification_text, window))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(fullScreenPending)
            .setFullScreenIntent(fullScreenPending, true)
            .build()

        getSystemService(NotificationManager::class.java).notify(notificationId, notification)
    }

    private fun buildOngoingNotification(): android.app.Notification {
        val contentPending = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_MONITOR)
            .setSmallIcon(R.drawable.ic_stat_focusblock)
            .setContentTitle(getString(R.string.monitor_notification_title))
            .setContentText(getString(R.string.monitor_notification_text))
            .setOngoing(true)
            .setContentIntent(contentPending)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
    }

    private fun createChannels() {
        val manager = getSystemService(NotificationManager::class.java)

        val monitor = NotificationChannel(
            CHANNEL_MONITOR,
            getString(R.string.channel_monitor_name),
            NotificationManager.IMPORTANCE_MIN
        ).apply {
            description = getString(R.string.channel_monitor_description)
            setShowBadge(false)
        }

        // The alert channel is silent: OverlayActivity plays the looping alarm
        // ringtone itself so it can be stopped exactly on dismiss.
        val alerts = NotificationChannel(
            CHANNEL_ALERTS,
            getString(R.string.channel_alerts_name),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = getString(R.string.channel_alerts_description)
            setSound(null, null)
            enableVibration(true)
        }

        manager.createNotificationChannel(monitor)
        manager.createNotificationChannel(alerts)
    }
}
