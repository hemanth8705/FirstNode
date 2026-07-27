package com.firstnode.firstnode

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.firstnode.firstnode.reminder.ReminderBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Alarms must be fully interactive from the lock screen — visible, awake, and
 * able to receive taps (Dismiss, puzzle input) — without requiring the user to
 * unlock first, exactly like the stock Clock/Phone apps. FlutterActivity
 * doesn't opt into this by itself. The `alarm` package used to configure it
 * automatically in versions before 5.0.0, but no longer does (we depend on
 * 5.5.0), so without this the full-screen-intent notification can launch this
 * Activity over the lock screen, but it stays non-interactive until the user's
 * own unlock gesture forces Android to fully resume it — which is exactly the
 * "alarm doesn't start / Dismiss doesn't respond until I unlock" bug.
 *
 * This Activity is also where a tapped post-alarm reminder lands, since
 * Android 12+ forbids routing a notification tap through a receiver that then
 * starts an Activity. See [ReminderBridge.handleAckIntent].
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super, so the acknowledgement is recorded no matter what
        // happens while the Flutter engine starts up. Dart reads it back later
        // via the `consumeAck` channel call.
        ReminderBridge.handleAckIntent(this, intent)

        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    /** Reached when the app was already running when the reminder was tapped. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        ReminderBridge.handleAckIntent(this, intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ReminderBridge.CHANNEL)
            .setMethodCallHandler(ReminderBridge(applicationContext))
    }
}
