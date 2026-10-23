package com.example.ankang_assistant

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.Calendar

internal object ReminderNotificationLaunch {
    const val ACTION_OPEN_REMINDER =
        "com.example.ankang_assistant.action.OPEN_REMINDER"

    fun payload(intent: Intent?): Map<String, Any?>? {
        if (intent?.action != ACTION_OPEN_REMINDER) return null
        val ownerUserId = intent.getLongExtra("ownerUserId", 0)
        val reminderId = intent.getLongExtra("reminderId", 0)
        if (ownerUserId <= 0 || reminderId == 0L) return null
        return mapOf(
            "ownerUserId" to ownerUserId,
            "reminderId" to reminderId,
            "route" to "/reminder"
        )
    }
}

internal object ReminderAlarmForegroundBridge {
    private var channel: MethodChannel? = null

    @Synchronized
    fun attach(nextChannel: MethodChannel) {
        channel = nextChannel
    }

    @Synchronized
    fun detach(currentChannel: MethodChannel) {
        if (channel === currentChannel) channel = null
    }

    @Synchronized
    fun emit(values: JSONObject) {
        val target = channel ?: return
        target.invokeMethod(
            "reminderTriggered",
            mapOf(
                "ownerUserId" to values.optLong("ownerUserId"),
                "reminderId" to values.optLong("reminderId"),
                "title" to values.optString("title", "健康提醒"),
                "triggeredAtMillis" to System.currentTimeMillis()
            )
        )
    }
}

internal object ReminderAlarmScheduler {
    private const val PREFERENCES = "reminder_alarm_store"
    private const val SCHEDULES_KEY = "schedules"
    private const val CHANNEL_ID = "health_reminders_prominent_v2"

    fun readiness(context: Context): Map<String, Any?> {
        val notificationPermission = if (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            "granted"
        } else {
            "not_granted"
        }
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val exactAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        return mapOf(
            "supported" to true,
            "notificationPermission" to notificationPermission,
            "exactAlarmAllowed" to exactAllowed
        )
    }

    @Synchronized
    fun schedule(
        context: Context,
        ownerUserId: Long,
        reminderId: Long,
        title: String,
        triggerAtMillis: Long,
        repeatType: String
    ) {
        if (ownerUserId <= 0 || reminderId == 0L || triggerAtMillis <= 0) return
        val values = JSONObject().apply {
            put("ownerUserId", ownerUserId)
            put("reminderId", reminderId)
            put("title", title.take(128))
            put("triggerAtMillis", triggerAtMillis)
            put("repeatType", repeatType)
        }
        val schedules = readSchedules(context)
        schedules.put(key(ownerUserId, reminderId), values)
        saveSchedules(context, schedules)
        scheduleAlarm(context, values)
    }

    @Synchronized
    fun cancel(context: Context, ownerUserId: Long, reminderId: Long) {
        cancelPendingIntent(context, ownerUserId, reminderId)
        val schedules = readSchedules(context)
        schedules.remove(key(ownerUserId, reminderId))
        saveSchedules(context, schedules)
        notificationManager(context).cancel(notificationId(ownerUserId, reminderId))
    }

    @Synchronized
    fun cancelAll(context: Context, ownerUserId: Long) {
        val schedules = readSchedules(context)
        val keys = schedules.keys().asSequence().toList()
        keys.forEach { scheduleKey ->
            val values = schedules.optJSONObject(scheduleKey) ?: return@forEach
            if (values.optLong("ownerUserId") != ownerUserId) return@forEach
            val reminderId = values.optLong("reminderId")
            cancelPendingIntent(context, ownerUserId, reminderId)
            notificationManager(context).cancel(notificationId(ownerUserId, reminderId))
            schedules.remove(scheduleKey)
        }
        saveSchedules(context, schedules)
    }

    @Synchronized
    fun onAlarm(context: Context, ownerUserId: Long, reminderId: Long) {
        val schedules = readSchedules(context)
        val values = schedules.optJSONObject(key(ownerUserId, reminderId)) ?: return
        showNotification(context, values)
        ReminderAlarmForegroundBridge.emit(values)
        val repeatType = values.optString("repeatType", "once")
        if (repeatType == "once") {
            schedules.remove(key(ownerUserId, reminderId))
        } else {
            val current = values.optLong("triggerAtMillis", System.currentTimeMillis())
            val next = advance(current, if (repeatType == "weekly") 7 else 1)
            values.put("triggerAtMillis", next)
            schedules.put(key(ownerUserId, reminderId), values)
            scheduleAlarm(context, values)
        }
        saveSchedules(context, schedules)
    }

    @Synchronized
    fun restoreAll(context: Context) {
        val schedules = readSchedules(context)
        val now = System.currentTimeMillis()
        val keys = schedules.keys().asSequence().toList()
        keys.forEach { scheduleKey ->
            val values = schedules.optJSONObject(scheduleKey) ?: return@forEach
            var trigger = values.optLong("triggerAtMillis")
            val repeatType = values.optString("repeatType", "once")
            if (trigger <= now && repeatType == "once") {
                schedules.remove(scheduleKey)
                return@forEach
            }
            while (trigger <= now) {
                trigger = advance(trigger, if (repeatType == "weekly") 7 else 1)
            }
            values.put("triggerAtMillis", trigger)
            scheduleAlarm(context, values)
        }
        saveSchedules(context, schedules)
    }

    fun openExactAlarmSettings(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return try {
            context.startActivity(
                Intent(
                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                    Uri.parse("package:${context.packageName}")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun scheduleAlarm(context: Context, values: JSONObject) {
        val ownerUserId = values.optLong("ownerUserId")
        val reminderId = values.optLong("reminderId")
        val triggerAtMillis = values.optLong("triggerAtMillis")
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = alarmPendingIntent(context, ownerUserId, reminderId)
        val exactAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && exactAllowed ->
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT ->
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            else -> alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        }
    }

    private fun showNotification(context: Context, values: JSONObject) {
        ensureChannel(context)
        val ownerUserId = values.optLong("ownerUserId")
        val reminderId = values.optLong("reminderId")
        val title = values.optString("title", "健康提醒")
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        launchIntent.apply {
            action = ReminderNotificationLaunch.ACTION_OPEN_REMINDER
            putExtra("ownerUserId", ownerUserId)
            putExtra("reminderId", reminderId)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            notificationId(ownerUserId, reminderId),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val publicVersion = notificationBuilder(context)
            .setContentTitle("健康提醒")
            .setContentText("您有一项健康提醒")
            .build()
        val notification = notificationBuilder(context)
            .setContentTitle(title)
            .setContentText("提醒时间已到，请打开应用查看并确认完成。")
            .setStyle(
                Notification.BigTextStyle()
                    .bigText("提醒时间已到，请打开应用查看并确认完成。")
            )
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .build()
        if (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            notificationManager(context).notify(
                notificationId(ownerUserId, reminderId),
                notification
            )
        }
    }

    private fun notificationBuilder(context: Context): Notification.Builder {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(Notification.PRIORITY_MAX)
            .setDefaults(Notification.DEFAULT_ALL)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = notificationManager(context)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .build()
        val channel = NotificationChannel(
            CHANNEL_ID,
            "健康提醒",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "按设定时间发出健康事项提醒"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 420, 180, 420)
            enableLights(true)
            lightColor = Color.rgb(41, 133, 102)
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                attributes
            )
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        manager.createNotificationChannel(channel)
    }

    private fun alarmPendingIntent(
        context: Context,
        ownerUserId: Long,
        reminderId: Long
    ): PendingIntent {
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            data = Uri.parse("ankang://reminder/$ownerUserId/$reminderId")
            putExtra("ownerUserId", ownerUserId)
            putExtra("reminderId", reminderId)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode(ownerUserId, reminderId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun cancelPendingIntent(
        context: Context,
        ownerUserId: Long,
        reminderId: Long
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(alarmPendingIntent(context, ownerUserId, reminderId))
    }

    private fun readSchedules(context: Context): JSONObject {
        val raw = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(SCHEDULES_KEY, null)
        return try {
            if (raw.isNullOrBlank()) JSONObject() else JSONObject(raw)
        } catch (_: RuntimeException) {
            JSONObject()
        }
    }

    private fun saveSchedules(context: Context, schedules: JSONObject) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(SCHEDULES_KEY, schedules.toString())
            .apply()
    }

    private fun advance(timestamp: Long, days: Int): Long =
        Calendar.getInstance().apply {
            timeInMillis = timestamp
            add(Calendar.DAY_OF_YEAR, days)
        }.timeInMillis

    private fun key(ownerUserId: Long, reminderId: Long) =
        "$ownerUserId|$reminderId"

    private fun requestCode(ownerUserId: Long, reminderId: Long) =
        key(ownerUserId, reminderId).hashCode()

    private fun notificationId(ownerUserId: Long, reminderId: Long) =
        requestCode(ownerUserId, reminderId) and Int.MAX_VALUE

    private fun notificationManager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val ownerUserId = intent.getLongExtra("ownerUserId", 0)
        val reminderId = intent.getLongExtra("reminderId", 0)
        ReminderAlarmScheduler.onAlarm(context, ownerUserId, reminderId)
    }
}

class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf(
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED
            )
        ) {
            ReminderAlarmScheduler.restoreAll(context)
        }
    }
}
