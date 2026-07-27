package com.firstnode.firstnode.reminder

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.firstnode.firstnode.MainActivity

/**
 * The reminder notification itself: a high-priority, tappable nudge.
 *
 * Unlike the alarm notification (built by the `alarm` package) this one is
 * deliberately *not* `ongoing` and has no full-screen intent — it's a
 * lightweight follow-up, so it can be swiped away. Swiping it away is not an
 * acknowledgement, so it has no delete intent; only the content intent (tapping
 * the body) acknowledges, by launching [MainActivity] with [ACTION_ACK].
 *
 * The channel is silent and vibration-free on purpose: [ReminderSoundService]
 * plays the user's chosen tone and vibrates itself, because a channel bakes in
 * whatever sound it was created with and cannot be changed afterwards — which
 * would make "pick a reminder ringtone" impossible to honor after first run.
 */
internal object ReminderNotifier {
    const val CHANNEL_ID = "post_alarm_reminder"
    private const val CHANNEL_NAME = "Post-alarm reminders"

    /** One id, reused: a fresh nudge replaces the previous one in the shade. */
    const val NOTIFICATION_ID = 90001

    const val ACTION_ACK = "com.firstnode.firstnode.action.POST_ALARM_REMINDER_ACK"
    const val EXTRA_ALARM_ID = "postAlarmReminderAlarmId"

    private const val REQ_ACK = 0xF2
    private const val REQ_OPEN = 0xF3

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Checks you're really awake after you dismiss an alarm"
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    // Resources are registered by Flutter, so the icon has to be looked up by
    // name — same approach the `alarm` package uses for its own notification.
    @SuppressLint("DiscouragedApi")
    private fun iconResId(context: Context): Int {
        val resId = context.resources.getIdentifier(
            "notification_icon",
            "drawable",
            context.packageName,
        )
        return if (resId != 0) {
            resId
        } else {
            context.packageManager.getApplicationInfo(context.packageName, 0).icon
        }
    }

    fun build(context: Context, config: ReminderConfig): Notification {
        val label = config.label.ifEmpty { "Alarm" }
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(iconResId(context))
            .setContentTitle("Still awake?")
            .setContentText("$label was dismissed — tap to confirm you're up")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(ackIntent(context, config.alarmId))
            .setAutoCancel(true)
            .setOngoing(false)
            .setSound(null)
            .setVibrate(null)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    fun show(context: Context, config: ReminderConfig) {
        ensureChannel(context)
        val manager = NotificationManagerCompat.from(context)
        // Cancel first: re-posting the same id over a notification the user
        // never dismissed would quietly update it in place instead of alerting
        // again, and a nudge nobody sees arrive is no nudge at all.
        manager.cancel(NOTIFICATION_ID)
        manager.notify(NOTIFICATION_ID, build(context, config))
    }

    fun clear(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    /**
     * Tapping the notification. Goes straight to [MainActivity] (rather than
     * through a receiver that would then start it — Android 12+ bans that
     * "notification trampoline") so the acknowledgement is handled in
     * `MainActivity.onCreate`/`onNewIntent` even if Dart isn't running yet.
     */
    private fun ackIntent(context: Context, alarmId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_ACK
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_ALARM_ID, alarmId)
        }
        return PendingIntent.getActivity(
            context,
            REQ_ACK,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    /**
     * Where the system's next-alarm indicator goes when tapped (see
     * [ReminderScheduler]). Opens the app *without* acknowledging — only the
     * notification itself counts as "I'm awake".
     */
    fun openAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return PendingIntent.getActivity(
            context,
            REQ_OPEN,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
