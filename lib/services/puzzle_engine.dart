import 'dart:math';

import '../models/alarm.dart';
import '../models/puzzle.dart';

/// One concrete challenge shown on the puzzle-solve screen. A single
/// [MathPuzzle] can expand into several [MathStep]s (one per question).
sealed class PuzzleStep {}

class RewriteStep extends PuzzleStep {
  final String target;
  RewriteStep(this.target);
}

class MathStep extends PuzzleStep {
  final String text; // e.g. "3 + 4 × 2"
  final num answer;
  final MathLevelKind level;
  MathStep(this.text, this.answer, this.level);
}

/// Generates puzzle content. Ported from the original design's JS logic.
///
/// A [Random] can be injected for deterministic tests; otherwise a fresh one
/// is used.
class PuzzleEngine {
  final Random _rng;
  PuzzleEngine([Random? rng]) : _rng = rng ?? Random();

  int _randInt(int a, int b) => a + _rng.nextInt(b - a + 1);

  /// Builds a random string from the enabled character sets.
  String generateRewriteString(RewritePuzzle c) {
    var chars = '';
    if (c.upper) chars += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (c.lower) chars += 'abcdefghijklmnopqrstuvwxyz';
    if (c.numbers) chars += '0123456789';
    if (c.special) chars += '!@#\$%^&*';
    if (chars.isEmpty) chars = 'abcdefghijklmnopqrstuvwxyz';
    final len = c.length <= 0 ? 8 : c.length;
    final sb = StringBuffer();
    for (var i = 0; i < len; i++) {
      sb.write(chars[_randInt(0, chars.length - 1)]);
    }
    return sb.toString();
  }

  /// Builds one arithmetic question with [numVars] terms at the given [level].
  /// Operators grow with difficulty: easy = +/-, medium adds ×/÷, hard adds ^.
  /// Division is only used when it divides evenly (falls back to + otherwise).
  MathStep buildQuestion(MathLevelKind level, int numVars) {
    final n = max(2, numVars);
    final terms =
        List.generate(n, (_) => _randInt(1, level == MathLevelKind.hard ? 9 : 12));
    final pool = level == MathLevelKind.easy
        ? ['+', '-']
        : level == MathLevelKind.medium
            ? ['+', '-', '×', '÷']
            : ['+', '-', '×', '÷', '^'];

    num result = terms[0];
    final parts = <String>[terms[0].toString()];
    for (var i = 0; i < n - 1; i++) {
      var op = pool[_randInt(0, pool.length - 1)];
      var t = terms[i + 1];
      if (op == '÷' && (t == 0 || result % t != 0)) op = '+';
      if (op == '^') t = _randInt(2, 3);
      if (op == '+') {
        result += t;
      } else if (op == '-') {
        result -= t;
      } else if (op == '×') {
        result *= t;
      } else if (op == '÷') {
        result = result / t;
      } else if (op == '^') {
        result = pow(result, t);
      }
      parts.add(op);
      parts.add(t.toString());
    }
    return MathStep(parts.join(' '), result, level);
  }

  /// Expands an alarm's configured puzzles into the ordered list of concrete
  /// challenges the user must solve to dismiss it.
  List<PuzzleStep> resolveQueue(Alarm alarm) {
    final queue = <PuzzleStep>[];
    for (final p in alarm.puzzles) {
      switch (p) {
        case RewritePuzzle r:
          queue.add(RewriteStep(generateRewriteString(r)));
        case MathPuzzle m:
          for (final d in m.levels) {
            final count = d.mode == DiffMode.random
                ? _randInt(min(d.min, d.max), max(d.min, d.max))
                : d.count;
            for (var i = 0; i < count; i++) {
              queue.add(buildQuestion(d.level, m.variables));
            }
          }
      }
    }
    return queue;
  }
}
