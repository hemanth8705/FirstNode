package com.firstnode.firstnode

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

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
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
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
}
