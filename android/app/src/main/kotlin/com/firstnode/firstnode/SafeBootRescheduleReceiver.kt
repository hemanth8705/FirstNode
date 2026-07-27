package com.firstnode.firstnode

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.firstnode.firstnode.reminder.ReminderScheduler
import com.gdelataillade.alarm.api.AlarmApiImpl
import com.gdelataillade.alarm.services.AlarmStorage
import java.util.Date

/**
 * Replaces the `alarm` package's own BootReceiver (disabled in AndroidManifest.xml
 * via tools:node="remove"), which has a bug: on BOOT_COMPLETED it blindly replays
 * every stored alarm's last-known `dateTime` through AlarmApiImpl.setAlarm(). That
 * method treats anything under 5 seconds away as due "now" and fires it almost
 * immediately (see AlarmApiImpl.setAlarm -> handleImmediateAlarm) — so any alarm
 * whose one-shot time has already passed while the phone was off (extremely likely
 * for a daily 6:30am alarm if the phone reboots at, say, 2pm) rings immediately and
 * incorrectly right after boot, playing whatever tone/random pick was last computed.
 *
 * We only manage one-shot occurrences per alarm (repeat days are handled in Dart —
 * see AlarmScheduler.nextOccurrence — the native side has no notion of "every
 * Mon/Wed/Fri"), so it cannot correctly recompute a stale alarm's next occurrence
 * itself. The safe behavior is: re-arm only alarms still genuinely in the future;
 * silently drop anything already due and let the app's own AppState.ready ->
 * AlarmScheduler.syncAll() (which runs on next app open, and knows the real repeat
 * rule) reschedule it correctly. This trades "may not fire if the phone stays off
 * across the missed time and the app isn't reopened" for "never rings unexpectedly."
 */
class SafeBootRescheduleReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SafeBootReschedule"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        // A post-alarm reminder chain nobody acknowledged is still owed to the
        // user, and AlarmManager forgot it across the reboot. Unlike the alarms
        // below there's no stale-time hazard: a reminder has no "correct" wall
        // clock time, only "keep asking every N minutes."
        ReminderScheduler.rearmAfterBoot(context)

        val now = Date()
        val alarms = AlarmStorage(context).getSavedAlarms()
        val alarmApi = AlarmApiImpl(context)

        Log.i(TAG, "Boot: checking ${alarms.size} stored alarm(s)")
        for (alarm in alarms) {
            if (alarm.dateTime.after(now)) {
                Log.d(TAG, "Re-arming alarm ${alarm.id} (still in the future)")
                alarmApi.setAlarm(alarm)
            } else {
                Log.w(
                    TAG,
                    "Skipping alarm ${alarm.id} — stored time ${alarm.dateTime} already " +
                        "passed; the app will reschedule it correctly on next open",
                )
            }
        }
    }
}
