import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';

/// Lets the user pick an audio file from their phone and turns it into a
/// [Song] usable everywhere the bundled tones are (specific/random/pool sound
/// modes, real scheduled alarms, and TEST).
class SongImportService {
  /// Opens the system file picker filtered to audio, copies the chosen file
  /// into the app's own storage (so it keeps working across app restarts and
  /// reboots regardless of where the original file lives), and probes its
  /// duration. Returns null if the user cancelled the picker.
  Future<Song> importFromDevice() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    final picked = result?.files.single;
    if (picked?.path == null) {
      throw const SongImportCancelled();
    }

    final sourcePath = picked!.path!;
    final displayName = p.basenameWithoutExtension(picked.name);

    final soundsDir = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'imported_sounds'),
    );
    await soundsDir.create(recursive: true);
    // Prefix with a timestamp so two imports of a same-named file don't collide
    // on disk (AppState.addCustomSong separately handles name collisions in the UI).
    final destPath = p.join(
      soundsDir.path,
      '${DateTime.timestamp().microsecondsSinceEpoch}_${picked.name}',
    );
    await File(sourcePath).copy(destPath);

    final duration = await _probeDuration(destPath);

    return Song(name: displayName, duration: duration, asset: destPath);
  }

  /// Loads (without audibly playing) the file to read its duration.
  Future<int> _probeDuration(String path) async {
    final probe = AudioPlayer();
    try {
      await probe.setSourceDeviceFile(path);
      final duration = await probe.getDuration();
      return duration == null || duration.inSeconds <= 0
          ? 60
          : duration.inSeconds;
    } finally {
      await probe.dispose();
    }
  }
}

/// Thrown when the user closes the file picker without choosing a file.
class SongImportCancelled implements Exception {
  const SongImportCancelled();
}
