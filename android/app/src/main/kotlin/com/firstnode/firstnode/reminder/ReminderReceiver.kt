package com.firstnode.firstnode.reminder

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * One tick of the reminder chain. Fired by `AlarmManager`, with or without a
 * Flutter engine alive.
 */
class ReminderReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ReminderReceiver"
        private const val REQ_SERVICE = 0xF4
    }

    override fun onReceive(context: Context, intent: Intent) {
        // No stored chain means it was acknowledged or cancelled — a stray
        // already-in-flight alarm must not resurrect it.
        val config = ReminderStore.load(context)
        if (config == null) {
            Log.d(TAG, "Reminder fired with no active chain; ignoring")
            return
        }

        // Arm the follow-up *first*. Showing the nudge or playing its tone can
        // fail (notifications revoked, foreground-service start refused); the
        // chain must outlive any of that, or one bad nudge ends it silently.
        ReminderScheduler.armNext(context, config)
        ReminderNotifier.show(context, config)
        playTone(context)
    }

    /**
     * The tone needs to outlive this 10-second receiver, so a short foreground
     * service plays it. Handing the start to the system via a `PendingIntent`
     * (rather than calling `startForegroundService` directly) is the same
     * approach the `alarm` package uses from its own receiver, and is what keeps
     * Android 12+'s background foreground-service restrictions satisfied — the
     * exact alarm that woke us up is what grants the exemption.
     */
    private fun playTone(context: Context) {
        val serviceIntent = Intent(context, ReminderSoundService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.getForegroundService(
                    context,
                    REQ_SERVICE,
                    serviceIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ).send()
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            // The notification is already posted, so the nudge is still visible —
            // it just arrives silently.
            Log.e(TAG, "Could not start the reminder sound service", e)
        }
    }
}
