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
///   * [poolAdd]  — adding tones to a pool. Rows are checkboxes: pick as many
///     as you like, then confirm with the "Add N songs" button, which calls
///     [onAdd] once with the whole batch.
enum SongPickerMode { specific, poolAdd }

class SongPickerScreen extends StatefulWidget {
  final SongPickerMode mode;
  final String? selectedName;
  final void Function(List<String> names)? onAdd;

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
  final Set<String> _checked = {};

  @override
  void dispose() {
    _audio.stopPreview();
    super.dispose();
  }

  void _toggle(String name) {
    if (widget.mode == SongPickerMode.specific) {
      setState(() => _selected = name);
    } else {
      setState(() {
        if (!_checked.add(name)) _checked.remove(name);
      });
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
    final app = context.read<AppState>();
    final progress = ValueNotifier<(int, int, String)>((0, 0, ''));

    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportProgressDialog(progress: progress),
    );

    ImportBatchResult? result;
    try {
      result = await SongImportService().pickAndImport(
        existing: app.customSongs,
        onProgress: (done, total, name) => progress.value = (done, total, name),
      );
    } catch (_) {
      result = const ImportBatchResult(imported: [], duplicates: 0, failed: []);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;
    progress.dispose();
    if (!mounted || result == null) return; // picker was cancelled

    if (result.imported.isEmpty) {
      if (result.duplicates > 0 || result.failed.isNotEmpty) {
        _toast(_summary(result));
      }
      return;
    }
    await app.addCustomSongs(result.imported);
    if (!mounted) return;
    setState(() {
      if (widget.mode == SongPickerMode.specific) {
        _selected = result!.imported.first.name;
      } else {
        _checked.addAll(result!.imported.map((s) => s.name));
      }
    });
    _toast(_summary(result));
  }

  String _summary(ImportBatchResult r) {
    final parts = <String>['${r.imported.length} imported'];
    if (r.duplicates > 0) {
      parts.add(
        '${r.duplicates} duplicate${r.duplicates == 1 ? '' : 's'} skipped',
      );
    }
    if (r.failed.isNotEmpty) parts.add('${r.failed.length} failed');
    return parts.join(' · ');
  }

  void _done() {
    _audio.stopPreview();
    if (widget.mode == SongPickerMode.specific) {
      Navigator.of(context).pop(_selected);
    } else {
      widget.onAdd?.call(_checked.toList());
      Navigator.of(context).pop();
    }
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
    final isPoolAdd = widget.mode == SongPickerMode.poolAdd;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(
              title: isPoolAdd ? 'Add songs to pool' : 'Choose a song',
              onBack: _back,
              trailing: isPoolAdd
                  ? null
                  : GestureDetector(
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
            if (isPoolAdd)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Opacity(
                    opacity: _checked.isEmpty ? 0.4 : 1,
                    child: IgnorePointer(
                      ignoring: _checked.isEmpty,
                      child: PrimaryButton(
                        label: _checked.isEmpty
                            ? 'Add songs'
                            : 'Add ${_checked.length} song${_checked.length == 1 ? '' : 's'}',
                        onTap: _done,
                      ),
                    ),
                  ),
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
    final isChecked = widget.mode == SongPickerMode.poolAdd && _checked.contains(s.name);
    return GestureDetector(
      onTap: () => _toggle(s.name),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: (isSelected || isChecked) ? AppColors.w(0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isSelected || isChecked) ? AppColors.w(0.3) : AppColors.w(0.08),
          ),
        ),
        child: Row(
          children: [
            if (widget.mode == SongPickerMode.poolAdd) ...[
              Icon(
                isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: isChecked ? Colors.white : AppColors.w(0.35),
              ),
              const SizedBox(width: 10),
            ],
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
