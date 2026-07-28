import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pool.dart';
import '../models/song.dart';
import '../services/formatters.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'song_picker_screen.dart';

/// Create or edit a pool: its name, playback order, how many songs stay frozen
/// at the front when shuffling, and its list of songs (each with its own trim
/// range and volume, and draggable into any order). Works on a [pool] draft copy.
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

  /// The song whose trim/volume sliders are open, held by identity rather than
  /// by index so dragging the list around doesn't expand a different card.
  PoolSong? _expanded;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    context.read<AppState>().upsertPool(draft);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "${draft.name}"?',
      message: 'This permanently deletes the pool. Alarms using it will fall '
          'back to no pool selected.',
    );
    if (!confirmed || !mounted) return;
    context.read<AppState>().deletePool(draft.id);
    Navigator.of(context).pop();
  }

  Future<void> _addSong() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SongPickerScreen(
          mode: SongPickerMode.poolAdd,
          onAdd: (names) {
            if (names.isEmpty) return;
            setState(() {
              final catalog = context.read<AppState>().allSongs;
              for (final name in names) {
                draft.songs.add(
                  PoolSong(
                    name: name,
                    start: 0,
                    end: songDuration(catalog, name),
                    volume: 80,
                  ),
                );
              }
            });
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    'Added ${names.length} song${names.length == 1 ? '' : 's'}',
                  ),
                  duration: const Duration(milliseconds: 1200),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _removeSong(int i) async {
    final song = draft.songs[i];
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove "${song.name}" from this pool?',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      draft.songs.removeAt(i);
      _expanded = null;
      // Keep the stored count in range so the frozen pills below match what
      // the pool can actually freeze.
      draft.frozenCount = draft.effectiveFrozenCount;
    });
  }

  /// Drag-and-drop: pull the song out and reinsert it where it was dropped.
  /// [newIndex] is the song's final index — `onReorderItem` already corrects for
  /// the removal, unlike the older `onReorder`.
  void _reorder(int oldIndex, int newIndex) => setState(() {
    draft.songs.insert(newIndex, draft.songs.removeAt(oldIndex));
  });

  /// Whether the song at [i] is one of the ones held in place. Only shuffle
  /// order has anything to hold in place — linear plays everything in order
  /// anyway.
  bool _isFrozen(int i) =>
      draft.order == PoolOrder.shuffle && i < draft.effectiveFrozenCount;

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
            // One CustomScrollView rather than a ListView holding a nested
            // reorderable list: the sliver version shares the screen's single
            // scroll position, so dragging a song past the top or bottom edge
            // scrolls the whole form the way you'd expect.
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _nameField(),
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
                        if (draft.order == PoolOrder.shuffle) _frozenSongs(),
                        const SizedBox(height: 22),
                        _songsHeader(),
                        const SizedBox(height: 10),
                      ]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverReorderableList(
                      itemCount: draft.songs.length,
                      onReorderItem: _reorder,
                      proxyDecorator: _liftedCard,
                      itemBuilder: (context, i) => _songCard(i, draft.songs[i]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (draft.songs.isEmpty)
                            EmptyState(
                              icon: Icons.queue_music_outlined,
                              title: 'No songs yet',
                              subtitle:
                                  'Add songs to build this pool\'s playlist.',
                              actionLabel: '+ Add song',
                              onAction: _addSong,
                            ),
                          if (!widget.isNew) ...[
                            const SizedBox(height: 22),
                            GestureDetector(
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
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// How a card looks while it's being dragged.
  ///
  /// The list renders the lifted card in an overlay, which sits outside the
  /// Scaffold and so has no [Material] ancestor. Without one, picking up a card
  /// whose trim/volume sliders are open throws "No Material widget found" —
  /// [Slider] insists on a Material to draw its ink on. Transparency keeps the
  /// card's own dark background and rounded corners looking unchanged.
  Widget _liftedCard(Widget child, int index, Animation<double> animation) {
    return Material(type: MaterialType.transparency, child: child);
  }

  Widget _nameField() {
    return TextField(
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
    );
  }

  /// How many songs shuffle leaves alone at the front. Offered up to whichever
  /// is smaller: [kMaxFrozenSongs] or the number of songs in the pool.
  Widget _frozenSongs() {
    final maxFrozen = draft.songs.length < kMaxFrozenSongs
        ? draft.songs.length
        : kMaxFrozenSongs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        const SectionLabel('FROZEN SONGS'),
        const SizedBox(height: 10),
        if (maxFrozen == 0)
          Text(
            'Add songs to the pool to choose how many stay in place.',
            style: TextStyle(color: AppColors.w(0.32), fontSize: 12, height: 1.5),
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 0; n <= maxFrozen; n++)
                ChoicePill(
                  label: n == 0 ? 'None' : 'First $n',
                  active: draft.effectiveFrozenCount == n,
                  onTap: () => setState(() => draft.frozenCount = n),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Keeps this many songs at the top of the list in place; only the '
            'songs after them get shuffled. Drag the songs below to choose '
            'which ones those are.',
            style: TextStyle(color: AppColors.w(0.32), fontSize: 12, height: 1.5),
          ),
        ],
      ],
    );
  }

  Widget _songsHeader() {
    return Row(
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
    );
  }

  Widget _songCard(int i, PoolSong s) {
    final expanded = _expanded == s;
    final max = songDuration(
      context.read<AppState>().allSongs,
      s.name,
    ).toDouble();
    return Padding(
      // The gap belongs inside the item: a reorderable list has no room for
      // separators between its children.
      key: ObjectKey(s),
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: AppColors.w(0.3),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _expanded = expanded ? null : s),
                    behavior: HitTestBehavior.opaque,
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
                          poolSongSummary(s, frozen: _isFrozen(i)),
                          style: TextStyle(
                            color: AppColors.w(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _removeSong(i),
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
                divisions: max > 0 ? max.toInt() : null,
                onChanged: (v) => setState(() {
                  s.start = v.round().clamp(0, s.end - 1).toInt();
                }),
              ),
              Slider(
                value: s.end.toDouble().clamp(0, max),
                max: max,
                divisions: max > 0 ? max.toInt() : null,
                onChanged: (v) => setState(() {
                  s.end = v.round().clamp(s.start + 1, max.toInt()).toInt();
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
      ),
    );
  }
}
