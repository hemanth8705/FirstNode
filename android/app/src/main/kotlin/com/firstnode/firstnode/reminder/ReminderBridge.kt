package com.firstnode.firstnode.reminder

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Dart ↔ native seam for post-alarm reminders.
 *
 * Dart owns the *settings* (which alarm, how often, which tone) and starts or
 * stops a chain; the native side owns *running* it. Acknowledgement flows back
 * the other way: the tap is handled here (see [handleAckIntent]) and Dart picks
 * the result up with `consumeAck` once it's running.
 */
class ReminderBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "ReminderBridge"
        const val CHANNEL = "firstnode/post_alarm_reminder"

        /**
         * The user tapped a reminder notification: end the chain immediately and
         * leave a note for Dart.
         *
         * Called from `MainActivity` before Flutter is necessarily up, because
         * this is the one path that must never depend on Dart being alive — the
         * tap is the only thing that stops the reminders.
         *
         * Returns true if [intent] was an acknowledgement.
         */
        fun handleAckIntent(context: Context, intent: Intent?): Boolean {
            if (intent == null || intent.action != ReminderNotifier.ACTION_ACK) return false
            val alarmId = intent.getIntExtra(ReminderNotifier.EXTRA_ALARM_ID, -1)
            Log.i(TAG, "Reminder acknowledged for alarm $alarmId")
            ReminderScheduler.cancel(context)
            ReminderStore.setPendingAck(context, alarmId)
            // The Activity keeps this Intent as its current one, so clear the
            // action: a later, unrelated onNewIntent must not re-acknowledge.
            intent.action = null
            return true
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val alarmId = call.argument<Int>("alarmId")
                val intervalMinutes = call.argument<Int>("intervalMinutes")
                if (alarmId == null || intervalMinutes == null) {
                    result.error(
                        "invalid_arguments",
                        "alarmId and intervalMinutes are required",
                        null,
                    )
                    return
                }
                ReminderScheduler.start(
                    context,
                    ReminderConfig(
                        alarmId = alarmId,
                        label = call.argument<String>("label") ?: "",
                        intervalMinutes = intervalMinutes.coerceAtLeast(1),
                        audioPath = call.argument<String>("audioPath"),
                        volume = (call.argument<Double>("volume") ?: 1.0)
                            .toFloat()
                            .coerceIn(0f, 1f),
                    ),
                )
                result.success(null)
            }

            "cancel" -> {
                ReminderScheduler.cancel(context)
                result.success(null)
            }

            /** Alarm id of the running chain, or null if none is running. */
            "activeAlarmId" -> result.success(ReminderStore.load(context)?.alarmId)

            "consumeAck" -> result.success(ReminderStore.consumePendingAck(context))

            else -> result.notImplemented()
        }
    }
}
