/// A tone the alarm can play.
///
/// [imported] distinguishes the two sources: bundled tones ship inside the app
/// under `assets/sounds/` and [asset] is a Flutter asset path; imported tones
/// are files the user picked from their phone, copied into the app's own
/// storage (see [lib/services/song_import.dart]) and [asset] is that absolute
/// file path.
class Song {
  final String name;
  final int duration; // length of the tone in seconds
  final String asset;
  final bool imported;

  const Song({
    required this.name,
    required this.duration,
    required this.asset,
    this.imported = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'duration': duration,
    'asset': asset,
    'imported': imported,
  };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
    name: j['name'],
    duration: j['duration'],
    asset: j['asset'],
    imported: j['imported'] ?? false,
  );
}

/// The fixed catalog of bundled tones shipped with the app.
///
/// The names/durations here must match the audio files generated under
/// `assets/sounds/` (see DEVLOG "bundled tones" step).
const List<Song> kSongCatalog = [
  Song(
    name: 'Gentle Chime',
    duration: 12,
    asset: 'assets/sounds/gentle_chime.wav',
  ),
  Song(
    name: 'Classic Beep',
    duration: 10,
    asset: 'assets/sounds/classic_beep.wav',
  ),
  Song(
    name: 'Morning Rise',
    duration: 15,
    asset: 'assets/sounds/morning_rise.wav',
  ),
  Song(name: 'Soft Pulse', duration: 12, asset: 'assets/sounds/soft_pulse.wav'),
  Song(name: 'Radar', duration: 10, asset: 'assets/sounds/radar.wav'),
  Song(name: 'Sunrise', duration: 15, asset: 'assets/sounds/sunrise.wav'),
];

/// Looks up a tone by name within [catalog] (pass `AppState.allSongs` so both
/// bundled and imported tones are searched), or null if not found.
Song? songByName(List<Song> catalog, String? name) {
  if (name == null) return null;
  for (final s in catalog) {
    if (s.name == name) return s;
  }
  return null;
}

/// Duration (seconds) of a named tone within [catalog]; a safe default if
/// it's unknown.
int songDuration(List<Song> catalog, String? name) =>
    songByName(catalog, name)?.duration ?? 60;
