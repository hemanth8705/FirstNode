import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alarm.dart';
import '../services/audio_service.dart';
import '../services/puzzle_engine.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Shown when a ringing alarm has puzzles: the user must solve each queued
/// challenge in turn to dismiss it. Audio plays until the last puzzle is solved.
///
/// For a real fired alarm, [blockBack] is set so the system back button can't
/// dismiss it without solving.
class PuzzleSolveScreen extends StatefulWidget {
  final Alarm alarm;
  final List<PuzzleStep> queue;

  /// See [RingingScreen.playInApp]. For a real alarm, [blockBack] prevents
  /// backing out without solving, and [onStop] stops it and reschedules/disables.
  final bool playInApp;
  final bool blockBack;
  final Future<void> Function()? onStop;

  const PuzzleSolveScreen({
    required this.alarm,
    required this.queue,
    this.playInApp = true,
    this.blockBack = false,
    this.onStop,
    super.key,
  });

  @override
  State<PuzzleSolveScreen> createState() => _PuzzleSolveScreenState();
}

class _PuzzleSolveScreenState extends State<PuzzleSolveScreen> {
  late final AudioService _audio = context.read<AudioService>();
  final TextEditingController _input = TextEditingController();
  int _idx = 0;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.playInApp) {
      final app = context.read<AppState>();
      _audio.playForAlarm(widget.alarm, app.pools, app.allSongs);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    if (widget.playInApp) _audio.stop();
    super.dispose();
  }

  PuzzleStep get _step => widget.queue[_idx];

  void _submit() {
    final step = _step;
    var correct = false;
    if (step is RewriteStep) {
      correct = _input.text == step.target;
    } else if (step is MathStep) {
      final parsed = double.tryParse(_input.text.trim());
      correct = parsed != null && parsed == step.answer.toDouble();
    }

    if (!correct) {
      setState(() => _error = 'Not quite — try again.');
      return;
    }

    if (_idx + 1 >= widget.queue.length) {
      _finish(); // solved everything -> dismiss
    } else {
      setState(() {
        _idx++;
        _error = '';
        _input.clear();
      });
    }
  }

  Future<void> _finish() async {
    await widget.onStop?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    return PopScope(
      canPop: !widget.blockBack,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              children: [
                Text(
                  'PUZZLE ${_idx + 1} OF ${widget.queue.length}',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.5,
                    color: AppColors.w(0.4),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (step is RewriteStep) ..._rewrite(step),
                      if (step is MathStep) ..._math(step),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          _error,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.w(0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _rewrite(RewriteStep step) {
    return [
      Text(
        'REWRITE THIS',
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 0.5,
          color: AppColors.w(0.4),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        step.target,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: ['Menlo', 'Courier New'],
          fontSize: 24,
          letterSpacing: 3,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 20),
      _inputField(hint: 'Type it exactly', mono: true),
      const SizedBox(height: 20),
      _submitButton(),
    ];
  }

  List<Widget> _math(MathStep step) {
    return [
      Text(
        'SOLVE',
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 0.5,
          color: AppColors.w(0.4),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        step.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w300,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 20),
      _inputField(
        hint: 'Answer',
        keyboardType: const TextInputType.numberWithOptions(signed: true),
      ),
      const SizedBox(height: 20),
      _submitButton(),
    ];
  }

  Widget _inputField({
    required String hint,
    bool mono = false,
    TextInputType? keyboardType,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: TextField(
        controller: _input,
        keyboardType: keyboardType,
        autofocus: true,
        textAlign: TextAlign.center,
        cursorColor: Colors.white,
        style: TextStyle(
          color: Colors.white,
          fontSize: mono ? 15 : 18,
          fontFamily: mono ? 'monospace' : null,
          fontFamilyFallback: mono ? const ['Menlo', 'Courier New'] : null,
        ),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.w(0.35)),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.w(0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.w(0.3)),
          ),
        ),
      ),
    );
  }

  Widget _submitButton() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: PrimaryButton(label: 'Submit', onTap: _submit),
    );
  }
}
