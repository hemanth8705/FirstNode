import 'package:audioplayers/audioplayers.dart';

import '../models/alarm.dart';
import '../models/pool.dart';
import '../models/song.dart';

/// Plays alarm tones. For milestone 1 this powers the in-app TEST / ring flow;
/// the same service will be reused when real scheduled alarms fire.
///
/// One shared [AudioPlayer] is used so we never play two tones at once.
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> _play(Song song, int volumePercent) async {
    await _player.stop();
    // Loop so the tone keeps ringing until dismissed.
    await _player.setReleaseMode(ReleaseMode.loop);
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

  Future<void> playSongByName(
    List<Song> allSongs,
    String? name, {
    int volume = 100,
  }) async {
    final song = songByName(allSongs, name) ?? kSongCatalog.first;
    await _play(song, volume);
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
        final shuffled = allSongs.toList()..shuffle();
        await _play(shuffled.first, alarm.volume);
      case SoundMode.pool:
        Pool? pool;
        for (final p in pools) {
          if (p.id == alarm.poolId) {
            pool = p;
            break;
          }
        }
        final firstName = (pool != null && pool.songs.isNotEmpty)
            ? pool.songs.first.name
            : null;
        await playSongByName(allSongs, firstName, volume: alarm.volume);
    }
  }

  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();
}
