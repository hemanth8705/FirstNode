import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/audio_service.dart';
import '../services/formatters.dart';
import '../services/song_import.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Two ways the song picker is used:
///   * [specific] — choosing the one tone for an alarm. Tapping a row just
///     selects/highlights it; the result is only returned when Done is
///     pressed (via `Navigator.pop(context, name)`).
///   * [poolAdd]  — adding tones to a pool. Tapping a row adds it immediately
///     (several can be added); Done just closes the screen.
enum SongPickerMode { specific, poolAdd }

class SongPickerScreen extends StatefulWidget {
  final SongPickerMode mode;
  final String? selectedName;
  final void Function(String name)? onAdd;

  const SongPickerScreen({
    required this.mode,
    this.selectedName,
    this.onAdd,
    super.key,
  });

  @override
  State<SongPickerScreen> createState() => _SongPickerScreenState();
}

class _SongPickerScreenState extends State<SongPickerScreen> {
  late final AudioService _audio = context.read<AudioService>();
  late String? _selected = widget.selectedName;

  @override
  void dispose() {
    _audio.stopPreview();
    super.dispose();
  }

  void _selectSong(String name) {
    if (widget.mode == SongPickerMode.specific) {
      setState(() => _selected = name);
    } else {
      widget.onAdd?.call(name);
      _toast('Added $name');
    }
  }

  Future<void> _togglePreview(Song s) async {
    final isThis = _audio.previewingName.value == s.name;
    final isPlaying = _audio.previewPlaying.value;
    if (isThis && isPlaying) {
      await _audio.pausePreview();
    } else if (isThis && !isPlaying) {
      await _audio.resumePreview();
    } else {
      await _audio.preview(context.read<AppState>().allSongs, s.name);
    }
  }

  Future<void> _import() async {
    try {
      final song = await SongImportService().importFromDevice();
      if (!mounted) return;
      await context.read<AppState>().addCustomSong(song);
      if (!mounted) return;
      _selectSong(song.name);
    } on SongImportCancelled {
      // User backed out of the picker — nothing to do.
    } catch (e) {
      if (mounted) _toast("Couldn't import that file");
    }
  }

  void _done() {
    _audio.stopPreview();
    Navigator.of(
      context,
    ).pop(widget.mode == SongPickerMode.specific ? _selected : null);
  }

  void _back() {
    _audio.stopPreview();
    Navigator.of(context).pop();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final songs = context.watch<AppState>().allSongs;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(
              title: widget.mode == SongPickerMode.specific
                  ? 'Choose a song'
                  : 'Add song to pool',
              onBack: _back,
              trailing: GestureDetector(
                onTap: _done,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _importRow(),
                  const SizedBox(height: 8),
                  for (final s in songs) ...[
                    _songRow(s),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _importRow() {
    return GestureDetector(
      onTap: _import,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.w(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.w(0.18)),
              ),
              child: Icon(Icons.add, size: 16, color: AppColors.w(0.7)),
            ),
            const SizedBox(width: 12),
            const Text(
              'Import from device',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _songRow(Song s) {
    final isSelected =
        widget.mode == SongPickerMode.specific && _selected == s.name;
    return GestureDetector(
      onTap: () => _selectSong(s.name),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.w(0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.w(0.3) : AppColors.w(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                s.imported ? Icons.folder_outlined : Icons.music_note,
                size: 16,
                color: AppColors.w(0.25),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    fmtMMSS(s.duration),
                    style: TextStyle(color: AppColors.w(0.4), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.check_circle, size: 18, color: Colors.white),
              ),
            AnimatedBuilder(
              animation: Listenable.merge([
                _audio.previewingName,
                _audio.previewPlaying,
              ]),
              builder: (context, _) => PreviewButton(
                playing:
                    _audio.previewingName.value == s.name &&
                    _audio.previewPlaying.value,
                onTap: () => _togglePreview(s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
