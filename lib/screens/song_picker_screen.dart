import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Two ways the song picker is used:
///   * [specific] — choosing the one tone for an alarm. Tapping returns the
///     chosen name via `Navigator.pop(context, name)`.
///   * [poolAdd]  — adding tones to a pool. Tapping calls [onAdd] and stays open
///     so several can be added; a Done button closes it.
enum SongPickerMode { specific, poolAdd }

class SongPickerScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(
              title: mode == SongPickerMode.specific
                  ? 'Choose a song'
                  : 'Add song to pool',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: kSongCatalog
                    .map((s) => _songRow(context, s))
                    .toList(),
              ),
            ),
            if (mode == SongPickerMode.poolAdd)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: PrimaryButton(
                  label: 'Done',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _songRow(BuildContext context, Song s) {
    final selected = mode == SongPickerMode.specific && selectedName == s.name;
    return GestureDetector(
      onTap: () {
        if (mode == SongPickerMode.specific) {
          Navigator.of(context).pop(s.name);
        } else {
          onAdd?.call(s.name);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Added ${s.name}'),
                duration: const Duration(milliseconds: 900),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.w(0.06))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
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
                    Icons.music_note,
                    size: 16,
                    color: AppColors.w(0.25),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      fmtMMSS(s.duration),
                      style: TextStyle(color: AppColors.w(0.4), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              selected ? '●' : '',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
