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

  Future<void> _playAsset(String asset, int volumePercent) async {
    await _player.stop();
    // Loop so the tone keeps ringing until dismissed.
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume((volumePercent / 100).clamp(0.0, 1.0));
    // audioplayers' AssetSource is relative to the `assets/` folder, so we
    // strip the leading "assets/" from the catalog path.
    final rel =
        asset.startsWith('assets/') ? asset.substring('assets/'.length) : asset;
    await _player.play(AssetSource(rel));
  }

  Future<void> playSongByName(String? name, {int volume = 100}) async {
    final song = songByName(name) ?? kSongCatalog.first;
    await _playAsset(song.asset, volume);
  }

  /// Picks and plays the right tone for [alarm], honoring its sound mode.
  Future<void> playForAlarm(Alarm alarm, List<Pool> pools) async {
    switch (alarm.soundMode) {
      case SoundMode.specific:
        await playSongByName(alarm.songName, volume: alarm.volume);
      case SoundMode.random:
        final shuffled = kSongCatalog.toList()..shuffle();
        await _playAsset(shuffled.first.asset, alarm.volume);
      case SoundMode.pool:
        Pool? pool;
        for (final p in pools) {
          if (p.id == alarm.poolId) {
            pool = p;
            break;
          }
        }
        final firstName =
            (pool != null && pool.songs.isNotEmpty) ? pool.songs.first.name : null;
        await playSongByName(firstName, volume: alarm.volume);
    }
  }

  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();
}
