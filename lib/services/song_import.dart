import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';

/// The outcome of a (possibly multi-file) import: what got imported, how many
/// were skipped as duplicates of a song already in the library (or of another
/// file in the same batch), and the display names of any files that failed.
class ImportBatchResult {
  final List<Song> imported;
  final int duplicates;
  final List<String> failed;

  const ImportBatchResult({
    required this.imported,
    required this.duplicates,
    required this.failed,
  });

  bool get isEmpty => imported.isEmpty && duplicates == 0 && failed.isEmpty;
}

/// Lets the user pick one or more audio files from their phone and turns them
/// into [Song]s usable everywhere the bundled tones are (specific/random/pool
/// sound modes and real scheduled alarms).
class SongImportService {
  /// Opens the system file picker (multi-select) filtered to audio, copies
  /// each chosen file into the app's own storage (so it keeps working across
  /// app restarts and reboots regardless of where the original file lives),
  /// probes its duration, and skips anything that looks like a re-import of a
  /// song already in [existing] (same original filename + size) or of another
  /// file already handled earlier in this same batch.
  ///
  /// [onProgress] is called before each file starts, as `(done, total, name)`.
  /// Returns null if the user closed the picker without choosing anything.
  Future<ImportBatchResult?> pickAndImport({
    required List<Song> existing,
    void Function(int done, int total, String name)? onProgress,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    final picked = result?.files ?? [];
    if (picked.isEmpty) return null;

    final soundsDir = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'imported_sounds'),
    );
    await soundsDir.create(recursive: true);

    final seenInBatch = <String>{};
    final knownKeys = {
      for (final s in existing.where((s) => s.originalFileName != null))
        '${s.originalFileName}:${s.sizeBytes}',
    };

    final imported = <Song>[];
    final failed = <String>[];
    var duplicates = 0;

    for (var i = 0; i < picked.length; i++) {
      final file = picked[i];
      onProgress?.call(i, picked.length, file.name);

      if (file.path == null) {
        failed.add(file.name);
        continue;
      }

      final key = '${file.name}:${file.size}';
      if (knownKeys.contains(key) || seenInBatch.contains(key)) {
        duplicates++;
        continue;
      }
      seenInBatch.add(key);

      try {
        final destPath = p.join(
          soundsDir.path,
          '${DateTime.timestamp().microsecondsSinceEpoch}_${file.name}',
        );
        await File(file.path!).copy(destPath);
        final duration = await _probeDuration(destPath);

        imported.add(
          Song(
            name: p.basenameWithoutExtension(file.name),
            duration: duration,
            asset: destPath,
            imported: true,
            dateAdded: DateTime.timestamp().millisecondsSinceEpoch,
            originalFileName: file.name,
            sizeBytes: file.size,
          ),
        );
      } catch (_) {
        failed.add(file.name);
      }
    }
    onProgress?.call(picked.length, picked.length, '');

    return ImportBatchResult(
      imported: imported,
      duplicates: duplicates,
      failed: failed,
    );
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
