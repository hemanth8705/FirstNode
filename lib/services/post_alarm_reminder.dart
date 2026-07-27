import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/alarm.dart';
import '../models/pool.dart';
import '../models/song.dart';

/// Which tone a post-alarm reminder should play for [alarm].
///
/// The reminder has its own [PostAlarmReminder.songName], stored separately from
/// the alarm's tone; when it hasn't been chosen (an alarm whose reminder was
/// just enabled, or one saved before this feature existed) we fall back to the
/// alarm's own sound so the nudge is never silent:
///   * Specific mode — the alarm's chosen tone.
///   * Random / Pools — the first tone in the alarm's pool. A reminder plays one
///     tone once, so there's nothing to shuffle or sequence through.
/// Failing all of that (no pool chosen, tone since deleted) it's the first
/// bundled tone.
Song resolveReminderTone(Alarm alarm, List<Pool> pools, List<Song> allSongs) {
  final chosen = songByName(allSongs, alarm.reminder.songName);
  if (chosen != null) return chosen;

  final fallbackName = alarm.soundMode == SoundMode.specific
      ? alarm.songName
      : _firstPoolSongName(alarm.poolId, pools);
  return songByName(allSongs, fallbackName) ?? kSongCatalog.first;
}

String? _firstPoolSongName(String? poolId, List<Pool> pools) {
  for (final p in pools) {
    if (p.id == poolId) return p.songs.isEmpty ? null : p.songs.first.name;
  }
  return null;
}

/// Starts, stops and inspects the native post-alarm reminder chain.
///
/// Dart owns the settings and the start/stop decisions; Android owns actually
/// running the chain (`AlarmManager` → `ReminderReceiver` → `ReminderSoundService`,
/// under `android/app/src/main/kotlin/.../reminder/`). That split is deliberate:
/// the nudges must keep arriving every interval until acknowledged, and anything
/// driven from Dart stops the moment the process is killed.
///
/// Every call is a no-op that swallows platform errors, so widget tests and iOS
/// (where this isn't implemented) run unaffected.
class PostAlarmReminderService {
  static const MethodChannel _channel = MethodChannel(
    'firstnode/post_alarm_reminder',
  );

  /// Begins nudging every [Alarm.reminder] interval until the user taps one.
  /// Replaces any chain already running — you can only have just dismissed one
  /// alarm.
  Future<void> start(
    Alarm alarm,
    List<Pool> pools,
    List<Song> allSongs,
  ) async {
    final tone = resolveReminderTone(alarm, pools, allSongs);
    await _invoke('start', {
      'alarmId': alarm.id,
      'label': alarm.label,
      'intervalMinutes': alarm.reminder.intervalMinutes,
      // Either a Flutter asset key or an absolute path to an imported file; the
      // native side handles both, exactly as it does for the alarm's own tone.
      'audioPath': tone.asset,
      'volume': (alarm.volume / 100).clamp(0.0, 1.0),
    });
  }

  Future<void> cancel() => _invoke('cancel', null);

  /// The alarm whose chain is currently running, or null if none is.
  Future<int?> activeAlarmId() => _invoke<int>('activeAlarmId', null);

  /// The alarm whose reminder the user acknowledged by tapping the notification,
  /// or null if they haven't. Reading it clears it, so the app confirms it once
  /// whether it was already open at the time or launched by the tap itself.
  Future<int?> consumeAcknowledgement() => _invoke<int>('consumeAck', null);

  Future<T?> _invoke<T>(String method, Map<String, Object?>? args) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // Not Android, or a widget test with no platform side.
    } on PlatformException catch (e) {
      debugPrint('PostAlarmReminderService.$method failed: $e');
      return null;
    }
  }
}
