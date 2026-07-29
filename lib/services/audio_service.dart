import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/alarm.dart';
import '../models/pool.dart';
import '../models/song.dart';

/// Plays alarm tones for the real ring flow (including true sequential
/// pool playback — see [playPool]) and short song previews (song picker
/// list, Edit Alarm's trim preview).
///
/// One shared [AudioPlayer] is used so we never play two things at once —
/// starting anything (ring, pool sequence, or preview) stops whatever was
/// playing before.
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _trimSub;

  /// The name of the song currently loaded for preview (list/trim preview),
  /// or null if nothing is. Not used for the alarm ring flow.
  final ValueNotifier<String?> previewingName = ValueNotifier(null);

  /// Whether the current preview is actively playing (vs. paused/stopped).
  final ValueNotifier<bool> previewPlaying = ValueNotifier(false);

  // ---------------------------------------------------- Pool sequencing ---
  StreamSubscription<Duration>? _poolPosSub;
  Timer? _poolFadeTimer;
  Stopwatch? _fadeStopwatch;
  int? _fadeDurationSec;
  List<PoolSong> _poolQueue = [];
  int _poolIndex = 0;
  List<Song> _poolCatalog = [];
  int _poolBaseVolume = 100;
  bool _poolActive = false;

  // ---------------------------------------------- Single-song alarm loop ---
  bool _alarmLoopActive = false;
  Song? _alarmLoopSong;
  int _alarmLoopStart = 0;
  int _alarmLoopVolume = 100;

  AudioService() {
    _player.onPlayerComplete.listen((_) {
      previewPlaying.value = false;
      if (_poolActive) {
        _advancePoolTrack();
      } else if (_alarmLoopActive && _alarmLoopSong != null) {
        // Safety net: if ReleaseMode.loop somehow didn't restart the audio
        // (can happen with certain file types or platform quirks), force a
        // replay from the configured trim start.
        _playSource(_alarmLoopSong!, _alarmLoopVolume);
        if (_alarmLoopStart > 0) {
          _player.seek(Duration(seconds: _alarmLoopStart));
        }
      }
    });
  }

  Future<void> _playSource(Song song, int volumePercent) async {
    await _player.setVolume((volumePercent / 100).clamp(0.0, 1.0));
    if (song.imported) {
      // An absolute path to a file we copied into app storage on import.
      await _player.play(DeviceFileSource(song.asset));
    } else {
      // audioplayers' AssetSource is relative to the `assets/` folder, so we
      // strip the leading "assets/" from the bundled catalog path.
      final rel = song.asset.startsWith('assets/')
          ? song.asset.substring('assets/'.length)
          : song.asset;
      await _player.play(AssetSource(rel));
    }
  }

  Future<void> _play(
    Song song,
    int volumePercent, {
    int startSec = 0,
    int? endSec,
  }) async {
    _cancelPoolTimers();
    _cancelAlarmLoop();
    _trimSub?.cancel();
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    _alarmLoopActive = true;
    _alarmLoopSong = song;
    _alarmLoopStart = startSec;
    _alarmLoopVolume = volumePercent;
    await _playSource(song, volumePercent);
    if (startSec > 0) {
      await _player.seek(Duration(seconds: startSec));
    }
    if (endSec != null && endSec > startSec) {
      _trimSub = _player.onPositionChanged.listen((pos) {
        if (pos.inSeconds >= endSec) {
          _player.seek(Duration(seconds: startSec));
        }
      });
    }
  }

  Future<void> playSongByName(
    List<Song> allSongs,
    String? name, {
    int volume = 100,
  }) async {
    final song = songByName(allSongs, name) ?? kSongCatalog.first;
    await _play(song, volume);
  }

  Pool? _findPool(String? poolId, List<Pool> pools) {
    if (poolId == null) return null;
    for (final p in pools) {
      if (p.id == poolId) return p;
    }
    return null;
  }

  /// Picks and plays the right tone for [alarm], honoring its sound mode.
  /// Dart drives audio for ALL modes — the native alarm side plays a silent
  /// placeholder to keep the foreground service alive.
  Future<void> playForAlarm(
    Alarm alarm,
    List<Pool> pools,
    List<Song> allSongs,
  ) async {
    switch (alarm.soundMode) {
      case SoundMode.specific:
        final song = songByName(allSongs, alarm.songName) ?? kSongCatalog.first;
        await _play(
          song,
          alarm.volume,
          startSec: alarm.start,
          endSec: alarm.end,
        );
      case SoundMode.random:
        final pool = _findPool(alarm.poolId, pools);
        if (pool != null && pool.songs.isNotEmpty) {
          // Random mode always shuffles, regardless of the pool's own order.
          final chosen = (pool.songs.toList()..shuffle()).first;
          await playSongByName(allSongs, chosen.name, volume: alarm.volume);
        } else {
          // No pool chosen (e.g. an alarm saved before this mode required one)
          // — fall back to any song so the alarm still rings with something.
          final shuffled = allSongs.toList()..shuffle();
          await _play(shuffled.first, alarm.volume);
        }
      case SoundMode.pool:
        final pool = _findPool(alarm.poolId, pools);
        if (pool != null && pool.songs.isNotEmpty) {
          await playPool(pool, allSongs, alarm);
        } else {
          await playSongByName(allSongs, null, volume: alarm.volume);
        }
    }
  }

  // ------------------------------------------------------ Pool sequence ---

  /// Plays a pool as a true sequence: each song plays its own trimmed
  /// start/end range at its own relative volume (combined with the alarm's
  /// overall volume), automatically advancing to the next song and looping
  /// back to the first once the list is exhausted — continues until [stop]
  /// is called. The order comes from [resolvePlayOrder] (linear plays the
  /// user's arrangement; shuffle keeps the pool's frozen songs first and
  /// randomizes the rest) and is decided once at the start of ringing, so the
  /// same order repeats on each pass. If gradual volume is enabled, the
  /// combined volume ramps in linearly over its configured duration,
  /// continuing seamlessly across song changes.
  Future<void> playPool(Pool pool, List<Song> allSongs, Alarm alarm) async {
    _cancelAlarmLoop();
    _cancelPoolTimers();
    _trimSub?.cancel();
    if (pool.songs.isEmpty) {
      await _play(kSongCatalog.first, alarm.volume);
      return;
    }
    _poolActive = true;
    _poolCatalog = allSongs;
    _poolBaseVolume = alarm.volume;
    _poolQueue = resolvePlayOrder(pool);
    _poolIndex = 0;
    if (alarm.gradual.enabled && alarm.gradual.duration > 0) {
      _fadeStopwatch = Stopwatch()..start();
      _fadeDurationSec = alarm.gradual.duration;
      _poolFadeTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => _applyPoolVolume(),
      );
    }
    await _playPoolTrack();
  }

  Future<void> _playPoolTrack() async {
    _poolPosSub?.cancel();
    final track = _poolQueue[_poolIndex];
    final song = songByName(_poolCatalog, track.name) ?? kSongCatalog.first;
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.stop); // we drive advancing/looping ourselves
    final combinedPercent = (_poolBaseVolume * track.volume / 100).round();
    await _playSource(song, combinedPercent);
    if (track.start > 0) {
      await _player.seek(Duration(seconds: track.start));
    }
    if (_fadeDurationSec != null) await _applyPoolVolume();
    _poolPosSub = _player.onPositionChanged.listen((pos) {
      if (pos.inSeconds >= track.end) _advancePoolTrack();
    });
  }

  void _advancePoolTrack() {
    _poolPosSub?.cancel();
    _poolIndex = (_poolIndex + 1) % _poolQueue.length;
    _playPoolTrack();
  }

  Future<void> _applyPoolVolume() async {
    if (_poolQueue.isEmpty) return;
    final track = _poolQueue[_poolIndex];
    var fraction = (_poolBaseVolume * track.volume / 100) / 100;
    if (_fadeDurationSec != null && _fadeStopwatch != null) {
      final elapsed = _fadeStopwatch!.elapsedMilliseconds / 1000.0;
      final t = (elapsed / _fadeDurationSec!).clamp(0.0, 1.0);
      fraction *= t;
      if (t >= 1.0) {
        _fadeDurationSec = null;
        _fadeStopwatch = null;
        _poolFadeTimer?.cancel();
      }
    }
    await _player.setVolume(fraction.clamp(0.0, 1.0));
  }

  void _cancelAlarmLoop() {
    _alarmLoopActive = false;
    _alarmLoopSong = null;
  }

  void _cancelPoolTimers() {
    _poolActive = false;
    _poolPosSub?.cancel();
    _poolFadeTimer?.cancel();
    _fadeStopwatch = null;
    _fadeDurationSec = null;
  }

  Future<void> stop() async {
    _cancelAlarmLoop();
    _cancelPoolTimers();
    await _player.stop();
  }

  // ------------------------------------------------------------- Preview ---

  /// Plays [name] once (no loop) for a quick preview. If [endSec] is given,
  /// playback automatically pauses once it reaches that position — used by
  /// the Edit Alarm screen to preview exactly the trimmed start/end range the
  /// alarm will actually play. Omit [endSec] to just play from [startSec] to
  /// the natural end of the file (used by the song-list preview).
  Future<void> preview(
    List<Song> allSongs,
    String? name, {
    int startSec = 0,
    int? endSec,
    int volume = 100,
  }) async {
    _cancelAlarmLoop();
    _cancelPoolTimers();
    _trimSub?.cancel();
    final song = songByName(allSongs, name) ?? kSongCatalog.first;
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.stop);
    await _playSource(song, volume);
    if (startSec > 0) {
      await _player.seek(Duration(seconds: startSec));
    }
    previewingName.value = name;
    previewPlaying.value = true;
    if (endSec != null) {
      _trimSub = _player.onPositionChanged.listen((pos) {
        if (pos.inSeconds >= endSec) {
          _trimSub?.cancel();
          _player.pause();
          previewPlaying.value = false;
        }
      });
    }
  }

  Future<void> pausePreview() async {
    await _player.pause();
    previewPlaying.value = false;
  }

  Future<void> resumePreview() async {
    await _player.resume();
    previewPlaying.value = true;
  }

  Future<void> stopPreview() async {
    _trimSub?.cancel();
    await _player.stop();
    previewPlaying.value = false;
    previewingName.value = null;
  }

  void dispose() {
    _cancelAlarmLoop();
    _cancelPoolTimers();
    _trimSub?.cancel();
    previewingName.dispose();
    previewPlaying.dispose();
    _player.dispose();
  }
}
