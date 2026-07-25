import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';

import '../models/alarm.dart' as model;
import '../models/pool.dart';
import '../models/song.dart';
import 'formatters.dart';

/// Bridges our data model to the `alarm` package, which does the hard native
/// work: firing at an exact time even when the app is killed, playing audio in a
/// foreground service, showing a full-screen notification, and surviving reboots.
///
/// We schedule the *next single occurrence* of each alarm. Repeats are handled by
/// rescheduling the following occurrence once an alarm is dismissed.
class AlarmScheduler {
  /// Ids we have scheduled, so [syncAll] can cancel ones that disappear.
  final Set<int> _scheduledIds = {};

  Future<void> init() => Alarm.init();

  /// The next DateTime this alarm should fire, based on its time and repeat days
  /// (0 = Monday … 6 = Sunday; empty = fire once at the next occurrence).
  DateTime nextOccurrence(model.Alarm a, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final base = DateTime(now.year, now.month, now.day, a.hour, a.minute);
    if (a.days.isEmpty) {
      return base.isAfter(now) ? base : base.add(const Duration(days: 1));
    }
    for (var i = 0; i < 8; i++) {
      final day = base.add(Duration(days: i));
      final ourWeekday = day.weekday - 1; // Dart: Mon=1..Sun=7 -> our 0..6
      if (a.days.contains(ourWeekday) && day.isAfter(now)) return day;
    }
    return base.add(const Duration(days: 1)); // safety fallback
  }

  Pool? _findPool(String? poolId, List<Pool> pools) {
    if (poolId == null) return null;
    for (final p in pools) {
      if (p.id == poolId) return p;
    }
    return null;
  }

  // Note: the `alarm` package's `assetAudioPath` accepts either a Flutter
  // asset key or an absolute device file path, so bundled and imported tones
  // (see models/song.dart) both just work by passing `song.asset` through.
  String _assetFor(model.Alarm a, List<Pool> pools, List<Song> allSongs) {
    switch (a.soundMode) {
      case model.SoundMode.specific:
        return songByName(allSongs, a.songName)?.asset ??
            kSongCatalog.first.asset;
      case model.SoundMode.random:
        final pool = _findPool(a.poolId, pools);
        if (pool != null && pool.songs.isNotEmpty) {
          // Random mode always shuffles, regardless of the pool's own order.
          final chosen = (pool.songs.toList()..shuffle()).first;
          return songByName(allSongs, chosen.name)?.asset ??
              kSongCatalog.first.asset;
        }
        // No pool chosen (e.g. an alarm saved before this mode required one)
        // — fall back to any song so the alarm still rings with something.
        return (allSongs.toList()..shuffle()).first.asset;
      case model.SoundMode.pool:
        final pool = _findPool(a.poolId, pools);
        if (pool != null && pool.songs.isNotEmpty) {
          final chosen = pool.order == PoolOrder.shuffle
              ? (pool.songs.toList()..shuffle()).first
              : pool.songs.first;
          return songByName(allSongs, chosen.name)?.asset ??
              kSongCatalog.first.asset;
        }
        return kSongCatalog.first.asset;
    }
  }

  VolumeSettings _volumeFor(model.Alarm a) {
    final vol = (a.volume / 100).clamp(0.0, 1.0);
    // "Gradual volume" maps to the package's linear fade (from silence up to the
    // set volume). The per-step interval/step aren't used by the fade API.
    if (a.gradual.enabled) {
      return VolumeSettings.fade(
        volume: vol,
        fadeDuration: Duration(seconds: a.gradual.duration),
      );
    }
    return VolumeSettings.fixed(volume: vol);
  }

  AlarmSettings _settingsFor(
    model.Alarm a,
    List<Pool> pools,
    List<Song> allSongs,
  ) {
    final hasPuzzles = a.puzzles.isNotEmpty;
    return AlarmSettings(
      id: a.id,
      dateTime: nextOccurrence(a),
      assetAudioPath: _assetFor(a, pools, allSongs),
      loopAudio: true,
      vibrate: true,
      androidFullScreenIntent: true,
      warningNotificationOnKill: Platform.isIOS,
      volumeSettings: _volumeFor(a),
      notificationSettings: NotificationSettings(
        title: a.label.isEmpty ? 'Alarm' : a.label,
        body:
            '${fmtTime(a.hour, a.minute)} — ${hasPuzzles ? 'solve to dismiss' : 'tap to dismiss'}',
        // Deliberately no Stop button when puzzles are required, so the alarm
        // can't be silenced from the notification without solving them.
        stopButton: hasPuzzles ? null : 'Stop',
        icon: 'notification_icon',
      ),
    );
  }

  /// Schedule a single alarm (or cancel it if disabled).
  Future<void> scheduleOne(
    model.Alarm a,
    List<Pool> pools,
    List<Song> allSongs,
  ) async {
    if (!a.enabled) {
      await cancel(a.id);
      return;
    }
    try {
      await Alarm.set(alarmSettings: _settingsFor(a, pools, allSongs));
      _scheduledIds.add(a.id);
    } catch (e) {
      debugPrint('AlarmScheduler: failed to schedule ${a.id}: $e');
    }
  }

  Future<void> cancel(int id) async {
    try {
      await Alarm.stop(id);
    } catch (e) {
      debugPrint('AlarmScheduler: failed to cancel $id: $e');
    }
    _scheduledIds.remove(id);
  }

  /// Reconcile all scheduled alarms with the current list: cancel ones that are
  /// now disabled or deleted, and (re)schedule every enabled one. Call after any
  /// change and at startup.
  Future<void> syncAll(
    List<model.Alarm> alarms,
    List<Pool> pools,
    List<Song> allSongs,
  ) async {
    final enabled = alarms.where((a) => a.enabled).toList();
    final enabledIds = enabled.map((a) => a.id).toSet();

    for (final id in _scheduledIds.toList()) {
      if (!enabledIds.contains(id)) await cancel(id);
    }
    for (final a in enabled) {
      await scheduleOne(a, pools, allSongs);
    }
  }
}
