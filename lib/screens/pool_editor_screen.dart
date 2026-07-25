import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pool.dart';
import '../models/song.dart';
import '../services/formatters.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'song_picker_screen.dart';

/// Create or edit a pool: its name, playback order, and its list of songs
/// (each with its own trim range and volume). Works on a [pool] draft copy.
class PoolEditorScreen extends StatefulWidget {
  final Pool pool;
  final bool isNew;
  const PoolEditorScreen({required this.pool, required this.isNew, super.key});

  @override
  State<PoolEditorScreen> createState() => _PoolEditorScreenState();
}

class _PoolEditorScreenState extends State<PoolEditorScreen> {
  late final Pool draft = widget.pool;
  late final TextEditingController _nameCtrl = TextEditingController(
    text: draft.name,
  );
  int? _expandedIndex;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    context.read<AppState>().upsertPool(draft);
    Navigator.of(context).pop();
  }

  void _delete() {
    context.read<AppState>().deletePool(draft.id);
    Navigator.of(context).pop();
  }

  Future<void> _addSong() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SongPickerScreen(
          mode: SongPickerMode.poolAdd,
          onAdd: (name) => setState(() {
            draft.songs.add(
              PoolSong(
                name: name,
                start: 0,
                end: songDuration(context.read<AppState>().allSongs, name),
                volume: 80,
              ),
            );
          }),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EditHeader(
              title: 'Edit pool',
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  TextField(
                    controller: _nameCtrl,
                    onChanged: (v) => draft.name = v,
                    cursorColor: Colors.white,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Pool name',
                      hintStyle: TextStyle(color: AppColors.w(0.35)),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                  const SizedBox(height: 22),
                  const SectionLabel('PLAYBACK ORDER'),
                  const SizedBox(height: 10),
                  SegmentedControl<PoolOrder>(
                    value: draft.order,
                    onChanged: (o) => setState(() => draft.order = o),
                    options: const [
                      SegmentOption(PoolOrder.linear, 'Linear'),
                      SegmentOption(PoolOrder.shuffle, 'Shuffle'),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionLabel('SONGS'),
                      GestureDetector(
                        onTap: _addSong,
                        behavior: HitTestBehavior.opaque,
                        child: const Text(
                          '+ Add',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._songCards(),
                  if (!widget.isNew) ...[
                    const SizedBox(height: 22),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: _delete,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          'Delete pool',
                          style: TextStyle(
                            color: AppColors.w(0.4),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _songCards() {
    final cards = <Widget>[];
    for (var i = 0; i < draft.songs.length; i++) {
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 8));
      cards.add(_songCard(i, draft.songs[i]));
    }
    return cards;
  }

  Widget _songCard(int i, PoolSong s) {
    final expanded = _expandedIndex == i;
    final max = songDuration(
      context.read<AppState>().allSongs,
      s.name,
    ).toDouble();
    return AppCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandedIndex = expanded ? null : i),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fmtMMSS(s.start)}–${fmtMMSS(s.end)} · ${s.volume}%',
                        style: TextStyle(color: AppColors.w(0.4), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    draft.songs.removeAt(i);
                    _expandedIndex = null;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.w(0.35),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Start ${fmtMMSS(s.start)}',
                  style: TextStyle(color: AppColors.w(0.45), fontSize: 12),
                ),
                Text(
                  'End ${fmtMMSS(s.end)}',
                  style: TextStyle(color: AppColors.w(0.45), fontSize: 12),
                ),
              ],
            ),
            Slider(
              value: s.start.toDouble().clamp(0, max),
              max: max,
              onChanged: (v) => setState(() {
                final nv = (v / 5).round() * 5;
                s.start = nv.clamp(0, s.end - 5).toInt();
              }),
            ),
            Slider(
              value: s.end.toDouble().clamp(0, max),
              max: max,
              onChanged: (v) => setState(() {
                final nv = (v / 5).round() * 5;
                s.end = nv.clamp(s.start + 5, max.toInt()).toInt();
              }),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Volume',
                  style: TextStyle(color: AppColors.w(0.45), fontSize: 12),
                ),
                Text(
                  '${s.volume}%',
                  style: TextStyle(color: AppColors.w(0.45), fontSize: 12),
                ),
              ],
            ),
            Slider(
              value: s.volume.toDouble(),
              max: 100,
              divisions: 20,
              onChanged: (v) => setState(() => s.volume = v.round()),
            ),
          ],
        ],
      ),
    );
  }
}
