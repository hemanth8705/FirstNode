import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/audio_service.dart';
import '../services/formatters.dart';
import '../services/song_import.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

enum _SongSort { name, dateAdded, duration }

/// Manage every song in the library: search, sort, see counts, import (single
/// or multi-file, with progress + a summary when it's done), and delete
/// imported songs (built-in tones can't be removed).
class LibraryScreen extends StatefulWidget {
  /// When true, the file picker opens automatically as soon as this screen
  /// appears — used by Settings' "Import Songs" shortcut.
  final bool autoImport;
  const LibraryScreen({this.autoImport = false, super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final AudioService _audio = context.read<AudioService>();
  final _searchCtrl = TextEditingController();
  String _query = '';
  _SongSort _sort = _SongSort.name;

  @override
  void initState() {
    super.initState();
    if (widget.autoImport) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _import());
    }
  }

  @override
  void dispose() {
    _audio.stopPreview();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Song> _filterSort(List<Song> songs) {
    final list = songs
        .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    switch (_sort) {
      case _SongSort.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SongSort.dateAdded:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      case _SongSort.duration:
        list.sort((a, b) => a.duration.compareTo(b.duration));
    }
    return list;
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

    if (result.imported.isNotEmpty) {
      await app.addCustomSongs(result.imported);
    }
    if (mounted) _toast(_summary(result));
  }

  String _summary(ImportBatchResult r) {
    final parts = <String>['${r.imported.length} imported'];
    if (r.duplicates > 0) {
      parts.add(
        '${r.duplicates} duplicate${r.duplicates == 1 ? '' : 's'} skipped',
      );
    }
    if (r.failed.isNotEmpty) {
      parts.add('${r.failed.length} failed');
    }
    return parts.join(' · ');
  }

  Future<void> _delete(Song song) async {
    final app = context.read<AppState>();
    final usage = app.songUsage(song.name);
    final usedBy = <String>[
      if (usage.alarmLabels.isNotEmpty)
        '${usage.alarmLabels.length} alarm${usage.alarmLabels.length == 1 ? '' : 's'}',
      if (usage.poolNames.isNotEmpty)
        '${usage.poolNames.length} pool${usage.poolNames.length == 1 ? '' : 's'}',
    ];
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "${song.name}"?',
      message: usedBy.isEmpty
          ? 'This permanently deletes the imported file.'
          : 'Used by ${usedBy.join(' and ')} — deleting it leaves those without '
                'this sound.',
    );
    if (!confirmed) return;
    await app.removeCustomSong(song.name);
    if (mounted) _toast('Deleted ${song.name}');
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

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1600),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final builtIn = _filterSort(kSongCatalog);
    final imports = _filterSort(app.customSongs);
    final noMatches =
        _query.isNotEmpty && builtIn.isEmpty && imports.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(
              title: 'Music Library',
              trailing: GestureDetector(
                onTap: _import,
                behavior: HitTestBehavior.opaque,
                child: Tooltip(
                  message: 'Import songs',
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.add, size: 22, color: Colors.white),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    cursorColor: Colors.white,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search songs',
                      hintStyle: TextStyle(color: AppColors.w(0.35)),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.w(0.4),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.w(0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.w(0.25)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${app.allSongs.length} songs · ${kSongCatalog.length} '
                        'built-in · ${app.customSongs.length} imported',
                        style: TextStyle(color: AppColors.w(0.4), fontSize: 12),
                      ),
                      const Spacer(),
                      _sortPicker(),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: noMatches
                  ? EmptyState(
                      icon: Icons.search_off,
                      title: 'No songs match "$_query"',
                      actionLabel: 'Clear search',
                      onAction: () => setState(() {
                        _query = '';
                        _searchCtrl.clear();
                      }),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        if (builtIn.isNotEmpty) ...[
                          const SectionLabel('BUILT-IN'),
                          const SizedBox(height: 8),
                          for (final s in builtIn) ...[
                            _songRow(s),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 14),
                        ],
                        const SectionLabel('YOUR IMPORTS'),
                        const SizedBox(height: 8),
                        if (imports.isEmpty)
                          EmptyState(
                            icon: Icons.library_music_outlined,
                            title: 'No imported songs yet',
                            subtitle: 'Import audio files from your device to '
                                'use them as alarm tones.',
                            actionLabel: 'Import songs',
                            onAction: _import,
                          )
                        else
                          for (final s in imports) ...[
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

  Widget _sortPicker() {
    return PopupMenuButton<_SongSort>(
      initialValue: _sort,
      onSelected: (v) => setState(() => _sort = v),
      color: AppColors.surface,
      tooltip: 'Sort by',
      itemBuilder: (context) => const [
        PopupMenuItem(value: _SongSort.name, child: Text('Name')),
        PopupMenuItem(value: _SongSort.dateAdded, child: Text('Date added')),
        PopupMenuItem(value: _SongSort.duration, child: Text('Duration')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort, size: 16, color: AppColors.w(0.5)),
          const SizedBox(width: 4),
          Text(
            switch (_sort) {
              _SongSort.name => 'Name',
              _SongSort.dateAdded => 'Date added',
              _SongSort.duration => 'Duration',
            },
            style: TextStyle(color: AppColors.w(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _songRow(Song s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.w(0.08)),
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
                  s.imported ? fmtMMSS(s.duration) : '${fmtMMSS(s.duration)} · Built-in',
                  style: TextStyle(color: AppColors.w(0.4), fontSize: 12),
                ),
              ],
            ),
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
          if (s.imported) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _delete(s),
              behavior: HitTestBehavior.opaque,
              child: Tooltip(
                message: 'Delete ${s.name}',
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.w(0.4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
