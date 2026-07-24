import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../services/puzzle_engine.dart';
import 'puzzle_solve_screen.dart';
import 'ringing_screen.dart';

/// Starts the ring / puzzle experience for [alarm].
///
/// If the alarm has puzzles configured, the user must solve them to dismiss it;
/// otherwise a simple Dismiss screen shows. Used by the TEST button today, and
/// by real scheduled alarms in the next milestone.
void startRing(BuildContext context, Alarm alarm) {
  final queue = PuzzleEngine().resolveQueue(alarm);
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => queue.isEmpty
          ? RingingScreen(alarm: alarm)
          : PuzzleSolveScreen(alarm: alarm, queue: queue),
    ),
  );
}
