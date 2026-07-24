import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../services/puzzle_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Configures a "rewrite" puzzle: which character sets and how long. Edits the
/// passed [puzzle] in place (the parent screen keeps a draft copy of the alarm).
class PuzzleRewriteScreen extends StatefulWidget {
  final RewritePuzzle puzzle;
  const PuzzleRewriteScreen({required this.puzzle, super.key});

  @override
  State<PuzzleRewriteScreen> createState() => _PuzzleRewriteScreenState();
}

class _PuzzleRewriteScreenState extends State<PuzzleRewriteScreen> {
  final PuzzleEngine _engine = PuzzleEngine();
  late String _preview = _engine.generateRewriteString(widget.puzzle);

  RewritePuzzle get p => widget.puzzle;

  void _changed() =>
      setState(() => _preview = _engine.generateRewriteString(p));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BackHeader(title: 'Rewrite puzzle'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  const SectionLabel('PREVIEW'),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        _preview,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontFamilyFallback: ['Menlo', 'Courier New'],
                          fontSize: 20,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SectionLabel('CHARACTERS'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoicePill(
                        label: 'A-Z',
                        active: p.upper,
                        onTap: () {
                          p.upper = !p.upper;
                          _changed();
                        },
                      ),
                      ChoicePill(
                        label: 'a-z',
                        active: p.lower,
                        onTap: () {
                          p.lower = !p.lower;
                          _changed();
                        },
                      ),
                      ChoicePill(
                        label: '0-9',
                        active: p.numbers,
                        onTap: () {
                          p.numbers = !p.numbers;
                          _changed();
                        },
                      ),
                      ChoicePill(
                        label: '#!*',
                        active: p.special,
                        onTap: () {
                          p.special = !p.special;
                          _changed();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionLabel('LENGTH'),
                      Text('${p.length} chars',
                          style: TextStyle(color: AppColors.w(0.55), fontSize: 12)),
                    ],
                  ),
                  Slider(
                    value: p.length.toDouble().clamp(4, 24),
                    min: 4,
                    max: 24,
                    divisions: 20,
                    onChanged: (v) {
                      p.length = v.round();
                      _changed();
                    },
                  ),
                  const SizedBox(height: 8),
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
}
