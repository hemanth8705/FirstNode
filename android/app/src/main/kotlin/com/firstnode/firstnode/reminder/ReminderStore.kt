package com.firstnode.firstnode.reminder

import android.content.Context

/**
 * Everything the native side needs to keep a post-alarm reminder chain running
 * on its own, without Dart. Written once by [ReminderBridge] when an alarm is
 * dismissed, then read by [ReminderReceiver] / [ReminderSoundService] on every
 * subsequent nudge.
 *
 * @param audioPath either a Flutter asset key (`assets/sounds/x.wav`) or an
 *   absolute path to an imported tone in the app's own storage — the same two
 *   shapes `Song.asset` uses in Dart. Null means "device default alarm sound".
 * @param volume 0.0–1.0, taken from the alarm's own volume so the nudge is as
 *   loud as the alarm the user configured.
 */
internal data class ReminderConfig(
    val alarmId: Int,
    val label: String,
    val intervalMinutes: Int,
    val audioPath: String?,
    val volume: Float,
)

/**
 * Persists the single active reminder chain (plus a pending acknowledgement)
 * in its own `SharedPreferences` file.
 *
 * Deliberately separate from the `shared_preferences` plugin's store: this is
 * read from a `BroadcastReceiver` and a `Service` that can run with no Flutter
 * engine alive, so it must not depend on the plugin's storage internals.
 *
 * There is only ever one chain at a time — you can only have just dismissed one
 * alarm — so starting a new chain replaces any previous one.
 */
internal object ReminderStore {
    private const val PREFS = "firstnode_post_alarm_reminder"

    private const val KEY_ACTIVE = "active"
    private const val KEY_ALARM_ID = "alarmId"
    private const val KEY_LABEL = "label"
    private const val KEY_INTERVAL = "intervalMinutes"
    private const val KEY_AUDIO_PATH = "audioPath"
    private const val KEY_VOLUME = "volume"

    /** Alarm id the user acknowledged, waiting for Dart to pick it up. */
    private const val KEY_PENDING_ACK = "pendingAckAlarmId"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(context: Context, config: ReminderConfig) {
        prefs(context).edit()
            .putBoolean(KEY_ACTIVE, true)
            .putInt(KEY_ALARM_ID, config.alarmId)
            .putString(KEY_LABEL, config.label)
            .putInt(KEY_INTERVAL, config.intervalMinutes)
            .putString(KEY_AUDIO_PATH, config.audioPath)
            .putFloat(KEY_VOLUME, config.volume)
            .apply()
    }

    /** The active chain, or null if there isn't one (acknowledged/cancelled). */
    fun load(context: Context): ReminderConfig? {
        val p = prefs(context)
        if (!p.getBoolean(KEY_ACTIVE, false)) return null
        return ReminderConfig(
            alarmId = p.getInt(KEY_ALARM_ID, -1),
            label = p.getString(KEY_LABEL, "") ?: "",
            intervalMinutes = p.getInt(KEY_INTERVAL, 5).coerceAtLeast(1),
            audioPath = p.getString(KEY_AUDIO_PATH, null),
            volume = p.getFloat(KEY_VOLUME, 1f).coerceIn(0f, 1f),
        )
    }

    /** Ends the chain. Leaves any pending acknowledgement untouched. */
    fun clear(context: Context) {
        prefs(context).edit()
            .remove(KEY_ACTIVE)
            .remove(KEY_ALARM_ID)
            .remove(KEY_LABEL)
            .remove(KEY_INTERVAL)
            .remove(KEY_AUDIO_PATH)
            .remove(KEY_VOLUME)
            .apply()
    }

    fun setPendingAck(context: Context, alarmId: Int) {
        prefs(context).edit().putInt(KEY_PENDING_ACK, alarmId).apply()
    }

    /**
     * Returns the acknowledged alarm id (once) and forgets it, so Dart can show
     * its confirmation exactly one time whether it was already running when the
     * notification was tapped or cold-started by it.
     */
    fun consumePendingAck(context: Context): Int? {
        val p = prefs(context)
        if (!p.contains(KEY_PENDING_ACK)) return null
        val id = p.getInt(KEY_PENDING_ACK, -1)
        p.edit().remove(KEY_PENDING_ACK).apply()
        return id
    }
}
