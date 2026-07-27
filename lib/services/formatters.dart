import '../models/pool.dart';
import '../models/puzzle.dart';

/// Small pure functions that turn data into the short strings shown in the UI.
/// Kept separate so they're easy to reuse and test.

/// Day initials, Monday-first, matching the design (note two "T" and two "S").
const List<String> kDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// 24-hour clock, e.g. 6 -> "06", 30 -> "30" => "06:30".
String fmtTime(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// Seconds -> "m:ss", e.g. 65 -> "1:05".
String fmtMMSS(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// The post-alarm reminder interval, e.g. 5 -> "5 min".
String fmtReminderInterval(int minutes) => '$minutes min';

/// "Once" / "Every day" / "M W F" style summary of repeat days.
String repeatSummary(List<int> days) {
  if (days.isEmpty) return 'Once';
  if (days.length == 7) return 'Every day';
  final sorted = [...days]..sort();
  return sorted.map((d) => kDayLabels[d]).join(' ');
}

/// "6 songs · shuffle · 2 frozen" — the second line of a row in the pool list.
/// The frozen part is only shown when it actually affects playback.
String poolSummary(Pool pool) {
  final count = pool.songs.length;
  final parts = ['$count song${count == 1 ? '' : 's'}', pool.order.name];
  if (pool.order == PoolOrder.shuffle && pool.effectiveFrozenCount > 0) {
    parts.add('${pool.effectiveFrozenCount} frozen');
  }
  return parts.join(' · ');
}

/// "0:00–0:12 · 80%" for one song inside a pool, with "· frozen" appended when
/// shuffle is holding it in place.
String poolSongSummary(PoolSong song, {bool frozen = false}) {
  final base = '${fmtMMSS(song.start)}–${fmtMMSS(song.end)} · ${song.volume}%';
  return frozen ? '$base · frozen' : base;
}

/// One-line description of a puzzle for the "Puzzles to dismiss" list.
String summarizePuzzle(Puzzle p) {
  switch (p) {
    case RewritePuzzle r:
      final flags = <String>[];
      if (r.upper) flags.add('A-Z');
      if (r.lower) flags.add('a-z');
      if (r.numbers) flags.add('0-9');
      if (r.special) flags.add('#!*');
      return '${flags.isEmpty ? 'a-z' : flags.join(' ')} · ${r.length} chars';
    case MathPuzzle m:
      final parts = <String>[];
      for (final d in m.levels) {
        if (d.mode == DiffMode.fixed && d.count > 0) {
          parts.add('${d.count} ${d.level.name}');
        }
        if (d.mode == DiffMode.random) {
          parts.add('${d.min}–${d.max} ${d.level.name}');
        }
      }
      return '${parts.isEmpty ? 'no questions' : parts.join(', ')} · ${m.variables} terms';
  }
}
