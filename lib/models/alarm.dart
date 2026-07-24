import 'puzzle.dart';

/// Where the alarm's audio comes from.
///   * [specific] — one chosen tone.
///   * [random]   — a random tone each time it rings.
///   * [pool]     — draw from a named [Pool] of tones.
enum SoundMode { specific, random, pool }

/// "Gradual volume": ramp the volume up over time instead of starting loud.
class Gradual {
  bool enabled;
  int duration; // total ramp length, seconds
  int interval; // step every N seconds
  int step; // increase by N percent each step

  Gradual({
    this.enabled = false,
    this.duration = 60,
    this.interval = 10,
    this.step = 5,
  });

  Gradual clone() => Gradual(
    enabled: enabled,
    duration: duration,
    interval: interval,
    step: step,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'duration': duration,
    'interval': interval,
    'step': step,
  };

  factory Gradual.fromJson(Map<String, dynamic> j) => Gradual(
    enabled: j['enabled'] ?? false,
    duration: j['duration'] ?? 60,
    interval: j['interval'] ?? 10,
    step: j['step'] ?? 5,
  );
}

class Alarm {
  int id;
  int hour; // 0..23
  int minute; // 0..59
  String label;
  List<int> days; // repeat days, 0 = Monday .. 6 = Sunday. Empty = once.
  bool enabled;

  SoundMode soundMode;
  String? songName; // used when soundMode == specific
  String? poolId; // used when soundMode == pool
  int start; // trim start (seconds) for a specific song
  int end; // trim end (seconds) for a specific song
  int volume; // 0..100

  Gradual gradual;
  List<Puzzle> puzzles;

  Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = '',
    List<int>? days,
    this.enabled = true,
    this.soundMode = SoundMode.specific,
    this.songName,
    this.poolId,
    this.start = 0,
    this.end = 60,
    this.volume = 70,
    Gradual? gradual,
    List<Puzzle>? puzzles,
  }) : days = days ?? [],
       gradual = gradual ?? Gradual(),
       puzzles = puzzles ?? [];

  /// Minutes since midnight — used to sort alarms by time.
  int get minutesOfDay => hour * 60 + minute;

  /// Deep copy for editing (so Cancel can discard changes safely).
  Alarm clone() => Alarm(
    id: id,
    hour: hour,
    minute: minute,
    label: label,
    days: List<int>.of(days),
    enabled: enabled,
    soundMode: soundMode,
    songName: songName,
    poolId: poolId,
    start: start,
    end: end,
    volume: volume,
    gradual: gradual.clone(),
    puzzles: puzzles.map((p) => p.clone()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'label': label,
    'days': days,
    'enabled': enabled,
    'soundMode': soundMode.name,
    'songName': songName,
    'poolId': poolId,
    'start': start,
    'end': end,
    'volume': volume,
    'gradual': gradual.toJson(),
    'puzzles': puzzles.map((p) => p.toJson()).toList(),
  };

  factory Alarm.fromJson(Map<String, dynamic> j) => Alarm(
    id: j['id'],
    hour: j['hour'],
    minute: j['minute'],
    label: j['label'] ?? '',
    days: (j['days'] as List).map((e) => e as int).toList(),
    enabled: j['enabled'] ?? true,
    soundMode: SoundMode.values.byName(j['soundMode']),
    songName: j['songName'],
    poolId: j['poolId'],
    start: j['start'] ?? 0,
    end: j['end'] ?? 60,
    volume: j['volume'] ?? 70,
    gradual: Gradual.fromJson(Map<String, dynamic>.from(j['gradual'])),
    puzzles: (j['puzzles'] as List)
        .map((e) => Puzzle.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}
