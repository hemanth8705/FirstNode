import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alarm.dart';
import '../models/puzzle.dart';
import '../models/song.dart';
import '../services/formatters.dart';
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
  late final TextEditingController _labelCtrl =
      TextEditingController(text: draft.label);

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- Time ------

  void _incHour() => setState(() => draft.hour = (draft.hour + 1) % 24);
  void _decHour() => setState(() => draft.hour = (draft.hour + 23) % 24);
  void _incMinute() => setState(() => draft.minute = (draft.minute + 5) % 60);
  void _decMinute() => setState(() => draft.minute = (draft.minute + 55) % 60);

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
      setState(() {
        draft.songName = result;
        draft.start = 0;
        draft.end = songDuration(result);
      });
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
                            style: TextStyle(color: AppColors.w(0.4), fontSize: 14),
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

  Widget _timePicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _timeColumn(
          draft.hour.toString().padLeft(2, '0'),
          onUp: _incHour,
          onDown: _decHour,
        ),
        const SizedBox(width: 22),
        Text(
          ':',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w300,
            color: AppColors.w(0.3),
          ),
        ),
        const SizedBox(width: 22),
        _timeColumn(
          draft.minute.toString().padLeft(2, '0'),
          onUp: _incMinute,
          onDown: _decMinute,
        ),
      ],
    );
  }

  Widget _timeColumn(String value, {required VoidCallback onUp, required VoidCallback onDown}) {
    Widget arrow(String glyph, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            child: Text(glyph, style: TextStyle(fontSize: 18, color: AppColors.w(0.5))),
          ),
        );
    return Column(
      children: [
        arrow('▲', onUp),
        const SizedBox(height: 8),
        SizedBox(
          width: 70,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        arrow('▼', onDown),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          SegmentOption(SoundMode.pool, 'Pool'),
        ],
      ),
    ];

    switch (draft.soundMode) {
      case SoundMode.specific:
        children.addAll([
          const SizedBox(height: 12),
          AppCard(
            onTap: _openSongPicker,
            child: _rowWithChevron(draft.songName ?? 'Choose a song'),
          ),
          const SizedBox(height: 14),
          _trimSliders(),
        ]);
      case SoundMode.random:
        children.addAll([
          const SizedBox(height: 12),
          Text(
            'A random song from your library will play each time this alarm rings.',
            style: TextStyle(color: AppColors.w(0.4), fontSize: 13, height: 1.5),
          ),
        ]);
      case SoundMode.pool:
        children.addAll([
          const SizedBox(height: 12),
          AppCard(
            onTap: _openPoolPicker,
            child: _rowWithChevron(app.poolById(draft.poolId)?.name ?? 'Choose a pool'),
          ),
        ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _rowWithChevron(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        Icon(Icons.chevron_right, size: 18, color: AppColors.w(0.4)),
      ],
    );
  }

  Widget _trimSliders() {
    final max = songDuration(draft.songName);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Start ${fmtMMSS(draft.start)}',
                style: TextStyle(color: AppColors.w(0.45), fontSize: 12)),
            Text('End ${fmtMMSS(draft.end)}',
                style: TextStyle(color: AppColors.w(0.45), fontSize: 12)),
          ],
        ),
        Slider(
          value: draft.start.toDouble().clamp(0, max.toDouble()),
          max: max.toDouble(),
          onChanged: (v) => setState(() {
            final nv = (v / 5).round() * 5;
            draft.start = nv.clamp(0, draft.end - 5).toInt();
          }),
        ),
        Slider(
          value: draft.end.toDouble().clamp(0, max.toDouble()),
          max: max.toDouble(),
          onChanged: (v) => setState(() {
            final nv = (v / 5).round() * 5;
            draft.end = nv.clamp(draft.start + 5, max).toInt();
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
            Text('${draft.volume}%',
                style: TextStyle(color: AppColors.w(0.55), fontSize: 12)),
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
                _gradualRow('Ramp duration', '${g.duration}s',
                    onDec: () => setState(() => g.duration = (g.duration - 10).clamp(10, 300)),
                    onInc: () => setState(() => g.duration = (g.duration + 10).clamp(10, 300)),
                    showDivider: true),
                _gradualRow('Every', '${g.interval}s',
                    onDec: () => setState(() => g.interval = (g.interval - 5).clamp(5, 60)),
                    onInc: () => setState(() => g.interval = (g.interval + 5).clamp(5, 60)),
                    showDivider: true),
                _gradualRow('Increase by', '${g.step}%',
                    onDec: () => setState(() => g.step = (g.step - 1).clamp(1, 20)),
                    onInc: () => setState(() => g.step = (g.step + 1).clamp(1, 20)),
                    showDivider: false),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _gradualRow(String label, String display,
      {required VoidCallback onDec, required VoidCallback onInc, required bool showDivider}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: showDivider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.w(0.06))))
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
                    Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(summarizePuzzle(p),
                        style: TextStyle(color: AppColors.w(0.4), fontSize: 12)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _removePuzzle(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline, size: 18, color: AppColors.w(0.35)),
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
              child: _outlineButton('+ Rewrite puzzle',
                  () => _addPuzzle(RewritePuzzle(length: 8))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _outlineButton('+ Math puzzle', () => _addPuzzle(MathPuzzle())),
            ),
          ],
        ),
      ],
    );
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
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }
}
