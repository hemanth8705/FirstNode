import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alarm.dart';
import '../models/puzzle.dart';
import '../models/song.dart';
import '../services/audio_service.dart';
import '../services/formatters.dart';
import '../services/post_alarm_reminder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'pool_picker_screen.dart';
import 'puzzle_math_screen.dart';
import 'puzzle_rewrite_screen.dart';
import 'song_picker_screen.dart';

/// Create or edit a single alarm. Works on a [draft] copy so that Cancel simply
/// discards changes; only Save writes back to the store.
class EditAlarmScreen extends StatefulWidget {
  final Alarm draft;
  final bool isNew;
  const EditAlarmScreen({required this.draft, required this.isNew, super.key});

  @override
  State<EditAlarmScreen> createState() => _EditAlarmScreenState();
}

class _EditAlarmScreenState extends State<EditAlarmScreen> {
  late final Alarm draft = widget.draft;
  late final TextEditingController _labelCtrl = TextEditingController(
    text: draft.label,
  );
  // Created once (not in build()) so unrelated setState calls elsewhere on this
  // screen — e.g. dragging the volume slider — don't reset the wheels' scroll
  // position back to the initial hour/minute.
  late final FixedExtentScrollController _hourCtrl = FixedExtentScrollController(
    initialItem: draft.hour,
  );
  late final FixedExtentScrollController _minuteCtrl =
      FixedExtentScrollController(initialItem: draft.minute);
  late final AudioService _audio = context.read<AudioService>();

  @override
  void dispose() {
    _audio.stopPreview();
    _labelCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _toggleDay(int d) => setState(() {
    if (draft.days.contains(d)) {
      draft.days.remove(d);
    } else {
      draft.days.add(d);
    }
    draft.days.sort();
  });

  // -------------------------------------------------------------- Save ------

  void _save() {
    context.read<AppState>().upsertAlarm(draft);
    Navigator.of(context).pop();
  }

  void _delete() {
    context.read<AppState>().deleteAlarm(draft.id);
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------- Sound navigation ----

  Future<void> _openSongPicker() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SongPickerScreen(
          mode: SongPickerMode.specific,
          selectedName: draft.songName,
        ),
      ),
    );
    if (result != null && mounted) {
      final allSongs = context.read<AppState>().allSongs;
      setState(() {
        draft.songName = result;
        draft.start = 0;
        draft.end = songDuration(allSongs, result);
      });
    }
  }

  Future<void> _openReminderSongPicker() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SongPickerScreen(
          mode: SongPickerMode.specific,
          selectedName: draft.reminder.songName,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => draft.reminder.songName = result);
    }
  }

  Future<void> _openPoolPicker() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PoolPickerScreen(selectedPoolId: draft.poolId),
      ),
    );
    if (result != null && mounted) {
      setState(() => draft.poolId = result);
    }
  }

  // --------------------------------------------------- Puzzle navigation ----

  Future<void> _openPuzzleConfig(Puzzle p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => p is RewritePuzzle
            ? PuzzleRewriteScreen(puzzle: p)
            : PuzzleMathScreen(puzzle: p as MathPuzzle),
      ),
    );
    if (mounted) setState(() {}); // refresh the summary line
  }

  Future<void> _addPuzzle(Puzzle p) async {
    setState(() => draft.puzzles.add(p));
    await _openPuzzleConfig(p);
  }

  void _removePuzzle(int i) => setState(() => draft.puzzles.removeAt(i));

  // ---------------------------------------------------------------- Build ---

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EditHeader(
              title: widget.isNew ? 'New alarm' : 'Edit alarm',
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: [
                  _timePicker(),
                  const SizedBox(height: 28),
                  _repeat(),
                  const SizedBox(height: 28),
                  _labelField(),
                  const SizedBox(height: 28),
                  _sound(app),
                  const SizedBox(height: 28),
                  _volume(),
                  const SizedBox(height: 28),
                  _gradual(),
                  const SizedBox(height: 28),
                  _puzzles(),
                  const SizedBox(height: 28),
                  _postAlarmReminder(app),
                  if (!widget.isNew) ...[
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: _delete,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Delete alarm',
                            style: TextStyle(
                              color: AppColors.w(0.4),
                              fontSize: 14,
                            ),
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

  /// Two scrollable wheels (hour 0-23, minute 0-59 — one-minute steps) rather
  /// than tap-to-step arrows, matching how native mobile time pickers work.
  Widget _timePicker() {
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _wheel(
              controller: _hourCtrl,
              count: 24,
              onChanged: (v) => draft.hour = v,
            ),
          ),
          Text(
            ':',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              color: AppColors.w(0.3),
            ),
          ),
          Expanded(
            child: _wheel(
              controller: _minuteCtrl,
              count: 60,
              onChanged: (v) => draft.minute = v,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 44,
      backgroundColor: Colors.transparent,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          border: Border.symmetric(horizontal: BorderSide(color: AppColors.w(0.1))),
        ),
      ),
      onSelectedItemChanged: (i) => setState(() => onChanged(i)),
      children: [
        for (var i = 0; i < count; i++)
          Center(
            child: Text(
              i.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w300,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _repeat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('REPEAT'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final active = draft.days.contains(i);
            return GestureDetector(
              onTap: () => _toggleDay(i),
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.accent : Colors.transparent,
                  border: Border.all(color: AppColors.w(0.15)),
                ),
                child: Text(
                  kDayLabels[i],
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? AppColors.onAccent : AppColors.w(0.6),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _labelField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('LABEL'),
        const SizedBox(height: 10),
        TextField(
          controller: _labelCtrl,
          onChanged: (v) => draft.label = v,
          cursorColor: Colors.white,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Alarm label',
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
      ],
    );
  }

  Widget _sound(AppState app) {
    final children = <Widget>[
      const SectionLabel('SOUND'),
      const SizedBox(height: 10),
      SegmentedControl<SoundMode>(
        value: draft.soundMode,
        onChanged: (m) => setState(() => draft.soundMode = m),
        options: const [
          SegmentOption(SoundMode.specific, 'Specific'),
          SegmentOption(SoundMode.random, 'Random'),
          SegmentOption(SoundMode.pool, 'Pools'),
        ],
      ),
    ];

    switch (draft.soundMode) {
      case SoundMode.specific:
        children.addAll([
          const SizedBox(height: 12),
          _toneCard(
            songName: draft.songName,
            onOpen: _openSongPicker,
            onTogglePreview: _toggleEditPreview,
          ),
          const SizedBox(height: 14),
          _trimSliders(),
        ]);
      case SoundMode.random:
        children.addAll([
          const SizedBox(height: 12),
          AppCard(
            onTap: _openPoolPicker,
            child: _rowWithChevron(
              app.poolById(draft.poolId)?.name ?? 'Choose a pool',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A random song from the selected pool will play each time this alarm rings.',
            style: TextStyle(
              color: AppColors.w(0.4),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ]);
      case SoundMode.pool:
        children.addAll([
          const SizedBox(height: 12),
          AppCard(
            onTap: _openPoolPicker,
            child: _rowWithChevron(
              app.poolById(draft.poolId)?.name ?? 'Choose a pool',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Plays according to the pool's own order — Linear follows the order you arranged, Shuffle randomizes it while keeping any frozen songs first.",
            style: TextStyle(
              color: AppColors.w(0.4),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// A chosen-tone card, shared by Specific mode and the post-alarm reminder:
  /// song name (scrolls if too long to fit) on the left, a preview Play/Pause
  /// button and a chevron (both open the song picker) on the right.
  Widget _toneCard({
    required String? songName,
    required VoidCallback onOpen,
    required VoidCallback onTogglePreview,
  }) {
    final hasSong = songName != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: AppColors.cardBorder,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 20,
                child: MarqueeOrText(
                  text: songName ?? 'Choose a song',
                  style: TextStyle(
                    color: hasSong ? Colors.white : AppColors.w(0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (hasSong) _previewButton(songName, onTogglePreview),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.chevron_right, size: 18, color: AppColors.w(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _previewButton(String? songName, VoidCallback onTap) {
    return AnimatedBuilder(
      animation: Listenable.merge([_audio.previewingName, _audio.previewPlaying]),
      builder: (context, _) => PreviewButton(
        playing:
            _audio.previewingName.value == songName &&
            _audio.previewPlaying.value,
        size: 28,
        filled: true,
        onTap: onTap,
      ),
    );
  }

  /// Previews exactly the currently-selected start/end range — "hear what the
  /// alarm will actually play." Toggling off stops (rather than pauses) since
  /// the trim bounds can change between presses.
  Future<void> _toggleEditPreview() async {
    final isThis = _audio.previewingName.value == draft.songName;
    final isPlaying = _audio.previewPlaying.value;
    if (isThis && isPlaying) {
      await _audio.stopPreview();
    } else {
      await _audio.preview(
        context.read<AppState>().allSongs,
        draft.songName,
        startSec: draft.start,
        endSec: draft.end,
        volume: draft.volume,
      );
    }
  }

  /// The reminder plays its tone from the start, so unlike the alarm preview
  /// there's no trim range to honor here.
  Future<void> _toggleReminderPreview() async {
    final name = draft.reminder.songName;
    final isThis = _audio.previewingName.value == name;
    if (isThis && _audio.previewPlaying.value) {
      await _audio.stopPreview();
    } else {
      await _audio.preview(
        context.read<AppState>().allSongs,
        name,
        volume: draft.volume,
      );
    }
  }

  Widget _rowWithChevron(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, size: 18, color: AppColors.w(0.4)),
      ],
    );
  }

  Widget _trimSliders() {
    final max = songDuration(context.read<AppState>().allSongs, draft.songName);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Start ${fmtMMSS(draft.start)}',
              style: TextStyle(color: AppColors.w(0.45), fontSize: 12),
            ),
            Text(
              'End ${fmtMMSS(draft.end)}',
              style: TextStyle(color: AppColors.w(0.45), fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: draft.start.toDouble().clamp(0, max.toDouble()),
          max: max.toDouble(),
          divisions: max > 0 ? max : null,
          onChanged: (v) => setState(() {
            draft.start = v.round().clamp(0, draft.end - 1).toInt();
          }),
        ),
        Slider(
          value: draft.end.toDouble().clamp(0, max.toDouble()),
          max: max.toDouble(),
          divisions: max > 0 ? max : null,
          onChanged: (v) => setState(() {
            draft.end = v.round().clamp(draft.start + 1, max).toInt();
          }),
        ),
      ],
    );
  }

  Widget _volume() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel('VOLUME'),
            Text(
              '${draft.volume}%',
              style: TextStyle(color: AppColors.w(0.55), fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: draft.volume.toDouble(),
          max: 100,
          divisions: 20,
          onChanged: (v) => setState(() => draft.volume = v.round()),
        ),
        Text(
          "Relative to your phone's system alarm volume — 100% here means as loud as the system allows.",
          style: TextStyle(color: AppColors.w(0.32), fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  Widget _gradual() {
    final g = draft.gradual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel('GRADUAL VOLUME'),
            AppToggle(
              value: g.enabled,
              onTap: () => setState(() => g.enabled = !g.enabled),
            ),
          ],
        ),
        if (g.enabled) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _gradualRow(
                  'Ramp duration',
                  '${g.duration}s',
                  onDec: () => setState(
                    () => g.duration = (g.duration - 10).clamp(10, 300),
                  ),
                  onInc: () => setState(
                    () => g.duration = (g.duration + 10).clamp(10, 300),
                  ),
                  showDivider: true,
                ),
                _gradualRow(
                  'Every',
                  '${g.interval}s',
                  onDec: () => setState(
                    () => g.interval = (g.interval - 5).clamp(5, 60),
                  ),
                  onInc: () => setState(
                    () => g.interval = (g.interval + 5).clamp(5, 60),
                  ),
                  showDivider: true,
                ),
                _gradualRow(
                  'Increase by',
                  '${g.step}%',
                  onDec: () =>
                      setState(() => g.step = (g.step - 1).clamp(1, 20)),
                  onInc: () =>
                      setState(() => g.step = (g.step + 1).clamp(1, 20)),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _gradualRow(
    String label,
    String display, {
    required VoidCallback onDec,
    required VoidCallback onInc,
    required bool showDivider,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.w(0.06))),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.w(0.7), fontSize: 14)),
          StepperControl(value: display, onDec: onDec, onInc: onInc),
        ],
      ),
    );
  }

  Widget _puzzles() {
    final rows = <Widget>[];
    for (var i = 0; i < draft.puzzles.length; i++) {
      final p = draft.puzzles[i];
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(
        AppCard(
          onTap: () => _openPuzzleConfig(p),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summarizePuzzle(p),
                      style: TextStyle(color: AppColors.w(0.4), fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _removePuzzle(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.w(0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('PUZZLES TO DISMISS'),
        const SizedBox(height: 10),
        ...rows,
        if (rows.isNotEmpty) const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _outlineButton(
                '+ Rewrite puzzle',
                () => _addPuzzle(RewritePuzzle(length: 8)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _outlineButton(
                '+ Math puzzle',
                () => _addPuzzle(MathPuzzle()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// "Post-alarm reminder": the follow-up nudges that keep coming after this
  /// alarm is dismissed until the user taps one. Sits after the puzzles because
  /// that's the order the user experiences it in — ring, dismiss, then this.
  Widget _postAlarmReminder(AppState app) {
    final r = draft.reminder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel('POST-ALARM REMINDER'),
            AppToggle(value: r.enabled, onTap: () => _toggleReminder(app)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'After this alarm is dismissed, keeps sending a notification until you '
          'tap it to confirm you are actually awake. Swiping it away or ignoring '
          'it just schedules the next one.',
          style: TextStyle(color: AppColors.w(0.32), fontSize: 12, height: 1.5),
        ),
        if (r.enabled) ...[
          const SizedBox(height: 18),
          const SectionLabel('REMIND ME EVERY'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in kReminderIntervals)
                ChoicePill(
                  label: fmtReminderInterval(minutes),
                  active: r.intervalMinutes == minutes,
                  onTap: () => setState(() => r.intervalMinutes = minutes),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionLabel('REMINDER SOUND'),
          const SizedBox(height: 10),
          _toneCard(
            songName: r.songName,
            onOpen: _openReminderSongPicker,
            onTogglePreview: _toggleReminderPreview,
          ),
          const SizedBox(height: 10),
          Text(
            'Plays once per reminder at this alarm\'s volume — a nudge, not a '
            'second alarm.',
            style: TextStyle(color: AppColors.w(0.32), fontSize: 12, height: 1.5),
          ),
        ],
      ],
    );
  }

  /// Turning the reminder on fills in a tone straight away — whatever this alarm
  /// itself would play — so the sound row is never blank and the reminder can
  /// never end up silent.
  void _toggleReminder(AppState app) {
    final r = draft.reminder;
    setState(() {
      r.enabled = !r.enabled;
      r.songName ??= resolveReminderTone(draft, app.pools, app.allSongs).name;
    });
  }

  Widget _outlineButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.w(0.15)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}
