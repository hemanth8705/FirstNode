// Post-alarm reminder: the parts that are pure Dart and worth pinning down.
// The chain itself runs in native code (see android/.../reminder/) and isn't
// reachable from a unit test.
import 'package:flutter_test/flutter_test.dart';

import 'package:firstnode/models/alarm.dart';
import 'package:firstnode/models/pool.dart';
import 'package:firstnode/models/song.dart';
import 'package:firstnode/services/formatters.dart';
import 'package:firstnode/services/post_alarm_reminder.dart';

void main() {
  group('PostAlarmReminder persistence', () {
    test('survives a JSON round trip', () {
      final alarm = Alarm(
        id: 7,
        hour: 6,
        minute: 30,
        reminder: PostAlarmReminder(
          enabled: true,
          intervalMinutes: 15,
          songName: 'Radar',
        ),
      );

      final restored = Alarm.fromJson(alarm.toJson());

      expect(restored.reminder.enabled, isTrue);
      expect(restored.reminder.intervalMinutes, 15);
      expect(restored.reminder.songName, 'Radar');
    });

    test('defaults to off for saves made before the feature existed', () {
      final json = Alarm(id: 1, hour: 7, minute: 0).toJson()
        ..remove('reminder');

      final restored = Alarm.fromJson(json);

      expect(restored.reminder.enabled, isFalse);
      expect(restored.reminder.intervalMinutes, 5);
      expect(restored.reminder.songName, isNull);
    });

    test('clone is a deep copy, so Cancel can discard reminder edits', () {
      final alarm = Alarm(id: 1, hour: 7, minute: 0);
      final draft = alarm.clone();

      draft.reminder.enabled = true;
      draft.reminder.intervalMinutes = 30;

      expect(alarm.reminder.enabled, isFalse);
      expect(alarm.reminder.intervalMinutes, 5);
    });

    test('every offered interval is a positive number of minutes', () {
      expect(kReminderIntervals, [1, 2, 5, 10, 15, 30]);
      expect(kReminderIntervals.every((m) => m > 0), isTrue);
    });
  });

  group('resolveReminderTone', () {
    final pools = [
      Pool(
        id: 'p1',
        name: 'Weekday Mix',
        songs: [
          PoolSong(name: 'Morning Rise', start: 0, end: 15, volume: 80),
          PoolSong(name: 'Sunrise', start: 0, end: 15, volume: 80),
        ],
      ),
    ];

    test('prefers the reminder\'s own tone', () {
      final alarm = Alarm(
        id: 1,
        hour: 7,
        minute: 0,
        songName: 'Radar',
        reminder: PostAlarmReminder(enabled: true, songName: 'Soft Pulse'),
      );

      expect(resolveReminderTone(alarm, pools, kSongCatalog).name, 'Soft Pulse');
    });

    test('falls back to the alarm\'s tone in Specific mode', () {
      final alarm = Alarm(id: 1, hour: 7, minute: 0, songName: 'Radar');

      expect(resolveReminderTone(alarm, pools, kSongCatalog).name, 'Radar');
    });

    test('falls back to the first pool tone in Pools mode', () {
      final alarm = Alarm(
        id: 1,
        hour: 7,
        minute: 0,
        soundMode: SoundMode.pool,
        poolId: 'p1',
      );

      expect(
        resolveReminderTone(alarm, pools, kSongCatalog).name,
        'Morning Rise',
      );
    });

    test('never returns null-ish when nothing is configured', () {
      final alarm = Alarm(
        id: 1,
        hour: 7,
        minute: 0,
        soundMode: SoundMode.random,
      );

      expect(
        resolveReminderTone(alarm, pools, kSongCatalog).name,
        kSongCatalog.first.name,
      );
    });

    test('falls back when the chosen tone has since been deleted', () {
      final alarm = Alarm(
        id: 1,
        hour: 7,
        minute: 0,
        songName: 'Radar',
        reminder: PostAlarmReminder(enabled: true, songName: 'Deleted Import'),
      );

      expect(resolveReminderTone(alarm, pools, kSongCatalog).name, 'Radar');
    });
  });

  test('fmtReminderInterval', () {
    expect(fmtReminderInterval(1), '1 min');
    expect(fmtReminderInterval(30), '30 min');
  });
}
