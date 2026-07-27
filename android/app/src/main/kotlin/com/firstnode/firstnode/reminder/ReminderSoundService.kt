package com.firstnode.firstnode.reminder

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Plays one reminder tone (and one short vibration) and gets out of the way.
 *
 * A foreground service is what lets audio start from the background at all on
 * modern Android, but this one is short-lived: unlike the alarm's service it does
 * not loop and does not wait to be stopped — the tone plays through once and the
 * service ends. That's the "lightweight follow-up, less intrusive than the
 * original alarm" behavior. The notification is *detached* rather than removed on
 * the way out, so it stays in the shade for the user to tap long after the sound
 * has finished.
 */
class ReminderSoundService : Service() {
    companion object {
        private const val TAG = "ReminderSoundService"

        /** Ceiling on one nudge, so a long imported tone can't drone on. */
        private const val MAX_RING_MILLIS = 30_000L

        private val VIBRATION_PATTERN = longArrayOf(0, 400, 250, 400)
    }

    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var timeout: Runnable? = null
    private var finished = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val config = ReminderStore.load(this)
        if (config == null) {
            // Acknowledged in the moment between the alarm firing and this
            // starting — don't make a sound the user already answered.
            stopSelf()
            return START_NOT_STICKY
        }

        try {
            startInForeground(config)
        } catch (e: Exception) {
            Log.e(TAG, "Could not start in the foreground", e)
            stopSelf()
            return START_NOT_STICKY
        }

        vibrate()
        playTone(config)
        timeout = Runnable { finish() }.also { handler.postDelayed(it, MAX_RING_MILLIS) }

        // START_NOT_STICKY: if the process dies mid-tone there's nothing worth
        // restarting — the next nudge is already armed.
        return START_NOT_STICKY
    }

    private fun startInForeground(config: ReminderConfig) {
        ReminderNotifier.ensureChannel(this)
        val notification = ReminderNotifier.build(this, config)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                ReminderNotifier.NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(ReminderNotifier.NOTIFICATION_ID, notification)
        }
    }

    /**
     * [ReminderConfig.audioPath] carries a tone straight from the app's own
     * library, so it comes in the two shapes `Song.asset` uses: a Flutter asset
     * key for the bundled tones (which live under `flutter_assets/` inside the
     * APK) and an absolute path for tones the user imported. Same mapping the
     * `alarm` package applies to `assetAudioPath`.
     */
    private fun playTone(config: ReminderConfig) {
        // Assigned before anything that can throw, so a failure part-way through
        // still leaves the player reachable for finish() to release.
        val mediaPlayer = MediaPlayer()
        player = mediaPlayer
        try {
            mediaPlayer.apply {
                val path = config.audioPath
                when {
                    path == null -> {
                        val fallback = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        if (fallback == null) {
                            Log.e(TAG, "No tone configured and no device default available")
                            finish()
                            return
                        }
                        setDataSource(this@ReminderSoundService, fallback)
                    }

                    path.startsWith("assets/") -> {
                        val descriptor = assets.openFd("flutter_assets/$path")
                        setDataSource(
                            descriptor.fileDescriptor,
                            descriptor.startOffset,
                            descriptor.length,
                        )
                    }

                    else -> setDataSource(path)
                }

                setAudioAttributes(
                    AudioAttributes.Builder()
                        // USAGE_ALARM, matching the alarm itself: a reminder that
                        // goes unheard because the phone is on silent defeats the
                        // point of the feature.
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                // Keeps the CPU alive for the length of the tone with the screen
                // off, without us managing a wake lock by hand.
                setWakeMode(this@ReminderSoundService, PowerManager.PARTIAL_WAKE_LOCK)
                setOnCompletionListener { finish() }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error what=$what extra=$extra")
                    finish()
                    true
                }
                prepare()
                setVolume(config.volume, config.volume)
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not play the reminder tone", e)
            finish()
        }
    }

    /** One short buzz, skipped when the device is set to silent. */
    private fun vibrate() {
        try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audio?.ringerMode == AudioManager.RINGER_MODE_SILENT) return

            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                    ?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            } ?: return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // -1: play the pattern once, don't repeat.
                vibrator.vibrate(VibrationEffect.createWaveform(VIBRATION_PATTERN, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(VIBRATION_PATTERN, -1)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not vibrate", e)
        }
    }

    private fun finish() {
        if (finished) return
        finished = true
        timeout?.let { handler.removeCallbacks(it) }
        releasePlayer()
        // STOP_FOREGROUND_DETACH keeps the notification in the shade after the
        // service goes away — the whole point is that it stays there to be
        // tapped whenever the user notices it.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_DETACH)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(false)
        }
        stopSelf()
    }

    private fun releasePlayer() {
        player?.apply {
            try {
                if (isPlaying) stop()
            } catch (e: IllegalStateException) {
                Log.e(TAG, "Illegal state stopping the reminder tone", e)
            }
            reset()
            release()
        }
        player = null
    }

    override fun onDestroy() {
        timeout?.let { handler.removeCallbacks(it) }
        releasePlayer()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
