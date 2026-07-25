import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/alarm.dart';
import '../models/pool.dart';
import '../models/puzzle.dart';
import '../models/song.dart';
import '../services/storage.dart';

/// The single source of truth for the app's data (all alarms + pools).
///
/// It extends [ChangeNotifier], so widgets that `watch` it rebuild whenever we
/// call [notifyListeners]. Every mutation also saves to disk so data survives
/// an app restart.
class AppState extends ChangeNotifier {
  final Storage _storage;
  AppState(this._storage);

  List<Alarm> alarms = [];
  List<Pool> pools = [];
  List<Song> customSongs = [];
  bool loaded = false;

  /// Bundled tones + anything the user has imported — the full catalog every
  /// song picker and playback path should search.
  List<Song> get allSongs => [...kSongCatalog, ...customSongs];

  /// Completes when the first data load finishes. The alarm ring handler waits
  /// on this in case the app was cold-started by a firing alarm.
  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  /// Invoked after any change to the alarm list, so the scheduler can re-sync.
  void Function()? onAlarmsChanged;

  /// Called once at startup: load saved data, or seed sample data on first run.
  Future<void> init() async {
    final data = await _storage.load();
    if (data == null) {
      _seed();
      await _persist();
    } else {
      alarms = data.alarms;
      pools = data.pools;
      customSongs = data.customSongs;
    }
    _sortAlarms();
    loaded = true;
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
  }

  void _sortAlarms() =>
      alarms.sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));

  Future<void> _persist() => _storage.save(alarms, pools, customSongs);

  // ---------------------------------------------------------------- Alarms ---

  int _nextAlarmId() => alarms.isEmpty
      ? 1
      : alarms.map((a) => a.id).reduce((a, b) => a > b ? a : b) + 1;

  /// Insert a new alarm (id <= 0) or replace an existing one by id.
  Future<void> upsertAlarm(Alarm alarm) async {
    if (alarm.id <= 0) {
      alarm.id = _nextAlarmId();
      alarms.add(alarm);
    } else {
      final i = alarms.indexWhere((a) => a.id == alarm.id);
      if (i >= 0) {
        alarms[i] = alarm;
      } else {
        alarms.add(alarm);
      }
    }
    _sortAlarms();
    await _persist();
    notifyListeners();
    onAlarmsChanged?.call();
  }

  Future<void> deleteAlarm(int id) async {
    alarms.removeWhere((a) => a.id == id);
    await _persist();
    notifyListeners();
    onAlarmsChanged?.call();
  }

  Future<void> toggleAlarm(int id) async {
    final i = alarms.indexWhere((a) => a.id == id);
    if (i >= 0) {
      alarms[i].enabled = !alarms[i].enabled;
      await _persist();
      notifyListeners();
      onAlarmsChanged?.call();
    }
  }

  /// Force an alarm's enabled state (used to turn off a "once" alarm after it
  /// has rung). No-op if already in that state.
  Future<void> setEnabled(int id, bool value) async {
    final i = alarms.indexWhere((a) => a.id == id);
    if (i >= 0 && alarms[i].enabled != value) {
      alarms[i].enabled = value;
      await _persist();
      notifyListeners();
      onAlarmsChanged?.call();
    }
  }

  // ----------------------------------------------------------------- Pools ---

  Pool? poolById(String? id) {
    if (id == null) return null;
    for (final p in pools) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> upsertPool(Pool pool) async {
    final i = pools.indexWhere((p) => p.id == pool.id);
    if (i >= 0) {
      pools[i] = pool;
    } else {
      pools.add(pool);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deletePool(String id) async {
    pools.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  // ----------------------------------------------------------------- Songs ---

  /// Adds an imported tone, renaming it (Name, Name (2), …) if it collides
  /// with an existing bundled or imported name.
  Future<void> addCustomSong(Song song) async {
    var name = song.name;
    var n = 2;
    while (allSongs.any((s) => s.name == name)) {
      name = '${song.name} ($n)';
      n++;
    }
    customSongs.add(
      Song(
        name: name,
        duration: song.duration,
        asset: song.asset,
        imported: true,
      ),
    );
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------- Summaries ---

  /// The "Pool · Weekday Mix" / "Random song" / "Song · Radar" line on the home
  /// card. Lives here because it needs to look pools up by id.
  String soundSummary(Alarm a) {
    switch (a.soundMode) {
      case SoundMode.specific:
        return a.songName != null ? 'Song · ${a.songName}' : 'Song';
      case SoundMode.random:
        return 'Random song';
      case SoundMode.pool:
        final p = poolById(a.poolId);
        return p != null ? 'Pool · ${p.name}' : 'Pool';
    }
  }

  // ------------------------------------------------------------------ Seed ---

  /// Sample data shown on first launch so the app isn't empty and mirrors the
  /// original design. Users can delete these. Remove/disable before store
  /// release if a clean first-run is preferred.
  void _seed() {
    pools = [
      Pool(
        id: 'p1',
        name: 'Weekday Mix',
        order: PoolOrder.linear,
        songs: [
          PoolSong(name: 'Gentle Chime', start: 0, end: 12, volume: 80),
          PoolSong(name: 'Morning Rise', start: 0, end: 15, volume: 70),
        ],
      ),
    ];
    alarms = [
      Alarm(
        id: 1,
        hour: 6,
        minute: 30,
        label: 'Wake up',
        days: [0, 1, 2, 3, 4],
        enabled: true,
        soundMode: SoundMode.pool,
        poolId: 'p1',
        volume: 80,
        gradual: Gradual(enabled: true, duration: 60, interval: 10, step: 5),
        puzzles: [
          MathPuzzle(
            variables: 2,
            levels: [
              Difficulty(
                level: MathLevelKind.easy,
                mode: DiffMode.fixed,
                count: 2,
              ),
              Difficulty(
                level: MathLevelKind.medium,
                mode: DiffMode.random,
                min: 1,
                max: 2,
              ),
              Difficulty(
                level: MathLevelKind.hard,
                mode: DiffMode.fixed,
                count: 0,
              ),
            ],
          ),
        ],
      ),
      Alarm(
        id: 2,
        hour: 8,
        minute: 0,
        label: 'Gym',
        days: [0, 2, 4],
        enabled: false,
        soundMode: SoundMode.random,
        volume: 60,
      ),
      Alarm(
        id: 3,
        hour: 22,
        minute: 0,
        label: 'Wind down',
        days: [],
        enabled: true,
        soundMode: SoundMode.specific,
        songName: 'Radar',
        start: 0,
        end: 10,
        volume: 50,
        puzzles: [
          RewritePuzzle(
            upper: true,
            lower: true,
            numbers: false,
            special: false,
            length: 12,
          ),
        ],
      ),
    ];
  }
}
