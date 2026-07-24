/// A tone the alarm can play.
///
/// For milestone 1 these are **bundled** tones that ship inside the app under
/// `assets/sounds/`. Later, when we add device-library support, the same model
/// can describe a song picked from the phone (with a different [asset] source).
class Song {
  final String name;
  final int duration; // length of the tone in seconds
  final String asset; // bundled asset path, e.g. assets/sounds/radar.wav

  const Song({required this.name, required this.duration, required this.asset});
}

/// The fixed catalog of bundled tones shipped with the app.
///
/// The names/durations here must match the audio files generated under
/// `assets/sounds/` (see DEVLOG "bundled tones" step).
const List<Song> kSongCatalog = [
  Song(name: 'Gentle Chime', duration: 12, asset: 'assets/sounds/gentle_chime.wav'),
  Song(name: 'Classic Beep', duration: 10, asset: 'assets/sounds/classic_beep.wav'),
  Song(name: 'Morning Rise', duration: 15, asset: 'assets/sounds/morning_rise.wav'),
  Song(name: 'Soft Pulse', duration: 12, asset: 'assets/sounds/soft_pulse.wav'),
  Song(name: 'Radar', duration: 10, asset: 'assets/sounds/radar.wav'),
  Song(name: 'Sunrise', duration: 15, asset: 'assets/sounds/sunrise.wav'),
];

/// Looks up a tone by name, or null if it isn't in the catalog.
Song? songByName(String? name) {
  if (name == null) return null;
  for (final s in kSongCatalog) {
    if (s.name == name) return s;
  }
  return null;
}

/// Duration (seconds) of a named tone; a safe default if it's unknown.
int songDuration(String? name) => songByName(name)?.duration ?? 60;
