import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Configures a "math" puzzle: how many terms per question, and how many
/// easy/medium/hard questions to ask (fixed counts or random ranges). Edits the
/// passed [puzzle] in place.
class PuzzleMathScreen extends StatefulWidget {
  final MathPuzzle puzzle;
  const PuzzleMathScreen({required this.puzzle, super.key});

  @override
  State<PuzzleMathScreen> createState() => _PuzzleMathScreenState();
}

class _PuzzleMathScreenState extends State<PuzzleMathScreen> {
  MathPuzzle get p => widget.puzzle;

  static String _levelLabel(MathLevelKind k) =>
      k.name[0].toUpperCase() + k.name.substring(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BackHeader(title: 'Math puzzle'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionLabel('TERMS PER QUESTION'),
                      Text('${p.variables}',
                          style: TextStyle(color: AppColors.w(0.55), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleStepButton(
                        glyph: '−',
                        size: 30,
                        onTap: () =>
                            setState(() => p.variables = (p.variables - 1).clamp(2, 6)),
                      ),
                      Expanded(
                        child: Text('${p.variables}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 15)),
                      ),
                      CircleStepButton(
                        glyph: '+',
                        size: 30,
                        onTap: () =>
                            setState(() => p.variables = (p.variables + 1).clamp(2, 6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionLabel('DIFFICULTY MIX'),
                  const SizedBox(height: 6),
                  Text(
                    'Easy is addition/subtraction, medium adds multiplication/division, hard adds exponents. Set a fixed count or a random range for each.',
                    style: TextStyle(color: AppColors.w(0.32), fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  for (final d in p.levels) _difficultyCard(d),
                  const SizedBox(height: 4),
                  PrimaryButton(
                    label: 'Done',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyCard(Difficulty d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: AppColors.cardBorder,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_levelLabel(d.level),
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              _modeToggle(d),
            ],
          ),
          const SizedBox(height: 12),
          if (d.mode == DiffMode.fixed)
            _counterRow(
              'Count',
              d.count,
              onDec: () => setState(() => d.count = (d.count - 1).clamp(0, 10)),
              onInc: () => setState(() => d.count = (d.count + 1).clamp(0, 10)),
            )
          else ...[
            _counterRow(
              'Min',
              d.min,
              onDec: () => setState(() => d.min = (d.min - 1).clamp(0, d.max)),
              onInc: () => setState(() => d.min = (d.min + 1).clamp(0, d.max)),
            ),
            const SizedBox(height: 8),
            _counterRow(
              'Max',
              d.max,
              onDec: () => setState(() => d.max = (d.max - 1).clamp(d.min, 20)),
              onInc: () => setState(() => d.max = (d.max + 1).clamp(d.min, 20)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeToggle(Difficulty d) {
    Widget btn(String label, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? AppColors.onAccent : AppColors.w(0.55),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn('Fixed', d.mode == DiffMode.fixed, () => setState(() => d.mode = DiffMode.fixed)),
          const SizedBox(width: 3),
          btn('Random', d.mode == DiffMode.random, () => _setRandom(d)),
        ],
      ),
    );
  }

  void _setRandom(Difficulty d) => setState(() {
        d.mode = DiffMode.random;
        // Seed a sensible range the first time we switch to random.
        if (d.min == 0 && d.max == 0) {
          d.min = d.count;
          d.max = d.count + 2;
        }
        if (d.max < d.min) d.max = d.min;
      });

  Widget _counterRow(String label, int value,
      {required VoidCallback onDec, required VoidCallback onInc}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.w(0.5), fontSize: 13)),
        StepperControl(
          value: '$value',
          valueWidth: 24,
          gap: 14,
          onDec: onDec,
          onInc: onInc,
        ),
      ],
    );
  }
}
