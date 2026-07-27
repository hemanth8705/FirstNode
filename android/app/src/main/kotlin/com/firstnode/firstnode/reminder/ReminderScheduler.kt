package com.firstnode.firstnode.reminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Arms the next nudge in the chain with `AlarmManager`.
 *
 * Only ever *one* alarm is pending at a time; [ReminderReceiver] arms the
 * following one as soon as it fires. That's what makes "repeat until
 * acknowledged" indefinite and independent of Dart — the chain lives entirely in
 * `AlarmManager` + [ReminderStore], so it keeps going with the app backgrounded
 * or its process killed.
 */
internal object ReminderScheduler {
    private const val TAG = "ReminderScheduler"
    private const val REQ_TICK = 0xF1

    fun start(context: Context, config: ReminderConfig) {
        ReminderStore.save(context, config)
        armNext(context, config)
    }

    fun armNext(context: Context, config: ReminderConfig) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (manager == null) {
            Log.e(TAG, "AlarmManager unavailable — reminder chain cannot continue")
            return
        }
        val triggerAt = System.currentTimeMillis() + config.intervalMinutes * 60_000L
        try {
            // setAlarmClock, not setExactAndAllowWhileIdle: Doze throttles the
            // latter to roughly one firing per 9 minutes per app, which would
            // silently stretch the 1/2/5-minute intervals into "every ~9 min" for
            // exactly the case this feature exists for — phone face-down on the
            // nightstand, screen off, user back asleep. setAlarmClock is exempt
            // from that throttle and never rate-limited. The cost is the system's
            // next-alarm indicator showing the upcoming nudge, which for an alarm
            // clock app is honest rather than surprising.
            manager.setAlarmClock(
                AlarmManager.AlarmClockInfo(
                    triggerAt,
                    ReminderNotifier.openAppIntent(context),
                ),
                tickIntent(context),
            )
            Log.d(TAG, "Next reminder for alarm ${config.alarmId} armed at $triggerAt")
        } catch (e: SecurityException) {
            // Exact-alarm permission revoked mid-chain: an inexact fallback is
            // late but still eventually nudges, which beats going silent.
            Log.w(TAG, "Exact alarms not permitted; falling back to inexact", e)
            manager.set(AlarmManager.RTC_WAKEUP, triggerAt, tickIntent(context))
        }
    }

    /** Ends the chain: no more nudges, and the current notification goes away. */
    fun cancel(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager)
            ?.cancel(tickIntent(context))
        ReminderStore.clear(context)
        ReminderNotifier.clear(context)
    }

    /**
     * `AlarmManager` forgets everything across a reboot, so re-arm from the
     * stored chain. The missed nudge isn't replayed immediately — the next one is
     * simply a full interval out, since a device that just booted has no way to
     * know how long it was off.
     */
    fun rearmAfterBoot(context: Context) {
        val config = ReminderStore.load(context) ?: return
        Log.i(TAG, "Boot: re-arming reminder chain for alarm ${config.alarmId}")
        armNext(context, config)
    }

    private fun tickIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        REQ_TICK,
        Intent(context, ReminderReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
