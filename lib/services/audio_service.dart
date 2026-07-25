import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/alarm.dart';
import '../models/pool.dart';
import '../models/song.dart';

/// Plays alarm tones (TEST / real ring flow) and short song previews (song
/// picker list, Edit Alarm's trim preview).
///
/// One shared [AudioPlayer] is used so we never play two things at once —
/// starting anything (ring or preview) stops whatever was playing before.
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _trimSub;

  /// The name of the song currently loaded for preview (list/trim preview),
  /// or null if nothing is. Not used for the looping alarm ring/TEST flow.
  final ValueNotifier<String?> previewingName = ValueNotifier(null);

  /// Whether the current preview is actively playing (vs. paused/stopped).
  final ValueNotifier<bool> previewPlaying = ValueNotifier(false);

  AudioService() {
    _player.onPlayerComplete.listen((_) {
      previewPlaying.value = false;
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

  Future<void> _play(Song song, int volumePercent) async {
    _trimSub?.cancel();
    await _player.stop();
    // Loop so the tone keeps ringing until dismissed.
    await _player.setReleaseMode(ReleaseMode.loop);
    await _playSource(song, volumePercent);
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
  Future<void> playForAlarm(
    Alarm alarm,
    List<Pool> pools,
    List<Song> allSongs,
  ) async {
    switch (alarm.soundMode) {
      case SoundMode.specific:
        await playSongByName(allSongs, alarm.songName, volume: alarm.volume);
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
          final chosen = pool.order == PoolOrder.shuffle
              ? (pool.songs.toList()..shuffle()).first
              : pool.songs.first;
          await playSongByName(allSongs, chosen.name, volume: alarm.volume);
        } else {
          await playSongByName(allSongs, null, volume: alarm.volume);
        }
    }
  }

  Future<void> stop() => _player.stop();

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
    _trimSub?.cancel();
    previewingName.dispose();
    previewPlaying.dispose();
    _player.dispose();
  }
}
