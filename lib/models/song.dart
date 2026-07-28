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

  /// When this song was imported (epoch milliseconds), used to sort the
  /// library by "date added". `0` for bundled tones and for songs imported
  /// before this field existed.
  final int dateAdded;

  /// The picked file's name (before any collision-renaming) and size in
  /// bytes, kept only for imported songs so a re-import of the same file can
  /// be recognised as a duplicate. Null for bundled tones.
  final String? originalFileName;
  final int? sizeBytes;

  const Song({
    required this.name,
    required this.duration,
    required this.asset,
    this.imported = false,
    this.dateAdded = 0,
    this.originalFileName,
    this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'duration': duration,
    'asset': asset,
    'imported': imported,
    'dateAdded': dateAdded,
    'originalFileName': originalFileName,
    'sizeBytes': sizeBytes,
  };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
    name: j['name'],
    duration: j['duration'],
    asset: j['asset'],
    imported: j['imported'] ?? false,
    dateAdded: j['dateAdded'] ?? 0,
    originalFileName: j['originalFileName'],
    sizeBytes: j['sizeBytes'],
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
