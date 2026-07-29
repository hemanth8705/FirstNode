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

/// Generates puzzle content. Each difficulty level uses a distinct set of
/// expression templates so the progression is obvious:
///   * **Easy** — two-term addition/subtraction, small numbers.
///   * **Medium** — multiplication/division, proper order of operations.
///   * **Hard** — parentheses/brackets, multi-step calculations.
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

  // --------------------------------------------------------- Easy (2 terms) --

  MathStep _buildEasy() {
    if (_rng.nextBool()) {
      final a = _randInt(1, 50);
      final b = _randInt(1, 50);
      return MathStep('$a + $b', a + b, MathLevelKind.easy);
    }
    final a = _randInt(2, 50);
    final b = _randInt(1, a);
    return MathStep('$a − $b', a - b, MathLevelKind.easy);
  }

  // ------------------------------------------------------ Medium (2-3 terms) -

  MathStep _buildMedium(int numVars) {
    final maxType = numVars >= 3 ? 6 : 1;
    for (var i = 0; i < 30; i++) {
      final result = _tryMedium(_randInt(0, maxType));
      if (result != null) return result;
    }
    return MathStep('12 × 6', 72, MathLevelKind.medium);
  }

  MathStep? _tryMedium(int type) {
    switch (type) {
      case 0: // a × b
        final a = _randInt(2, 12);
        final b = _randInt(2, 12);
        return MathStep('$a × $b', a * b, MathLevelKind.medium);
      case 1: // a ÷ b (generate clean division by construction)
        final b = _randInt(2, 12);
        final q = _randInt(2, 12);
        return MathStep('${b * q} ÷ $b', q, MathLevelKind.medium);
      case 2: // a + b × c (PEMDAS: multiply first)
        final a = _randInt(1, 30);
        final b = _randInt(2, 9);
        final c = _randInt(2, 9);
        return MathStep('$a + $b × $c', a + b * c, MathLevelKind.medium);
      case 3: // a × b + c
        final a = _randInt(2, 9);
        final b = _randInt(2, 9);
        final c = _randInt(1, 30);
        return MathStep('$a × $b + $c', a * b + c, MathLevelKind.medium);
      case 4: // a − b × c (ensure non-negative)
        final b = _randInt(2, 5);
        final c = _randInt(2, 5);
        final product = b * c;
        final a = _randInt(product, product + 30);
        return MathStep('$a − $b × $c', a - product, MathLevelKind.medium);
      case 5: // a × b − c (ensure non-negative)
        final a = _randInt(2, 9);
        final b = _randInt(2, 9);
        final product = a * b;
        if (product < 2) return null;
        final c = _randInt(1, product - 1);
        return MathStep('$a × $b − $c', product - c, MathLevelKind.medium);
      case 6: // a + b ÷ c (clean division by construction)
        final c = _randInt(2, 9);
        final q = _randInt(1, 9);
        final b = c * q;
        final a = _randInt(1, 30);
        return MathStep('$a + $b ÷ $c', a + q, MathLevelKind.medium);
      default:
        return null;
    }
  }

  // -------------------------------------------------------- Hard (3-4 terms) -

  MathStep _buildHard(int numVars) {
    final maxType = numVars >= 4 ? 7 : 4;
    for (var i = 0; i < 30; i++) {
      final result = _tryHard(_randInt(0, maxType));
      if (result != null) return result;
    }
    return MathStep('(12 + 8) × 4', 80, MathLevelKind.hard);
  }

  MathStep? _tryHard(int type) {
    switch (type) {
      case 0: // (a + b) × c
        final a = _randInt(2, 15);
        final b = _randInt(2, 15);
        final c = _randInt(2, 9);
        return MathStep('($a + $b) × $c', (a + b) * c, MathLevelKind.hard);
      case 1: // a × (b + c)
        final a = _randInt(2, 9);
        final b = _randInt(2, 15);
        final c = _randInt(2, 15);
        return MathStep('$a × ($b + $c)', a * (b + c), MathLevelKind.hard);
      case 2: // (a − b) × c
        final a = _randInt(5, 20);
        final b = _randInt(1, a - 1);
        final c = _randInt(2, 9);
        return MathStep('($a − $b) × $c', (a - b) * c, MathLevelKind.hard);
      case 3: // (a + b) ÷ c (clean division by construction)
        final c = _randInt(2, 9);
        final q = _randInt(2, 12);
        final sum = c * q;
        final a = _randInt(1, sum - 1);
        final b = sum - a;
        return MathStep('($a + $b) ÷ $c', q, MathLevelKind.hard);
      case 4: // a ÷ (b + c) (clean division by construction)
        final bc = _randInt(2, 9);
        final q = _randInt(2, 12);
        final a = bc * q;
        final b = _randInt(1, bc - 1);
        final c = bc - b;
        return MathStep('$a ÷ ($b + $c)', q, MathLevelKind.hard);
      case 5: // (a + b) × (c + d)
        final a = _randInt(2, 9);
        final b = _randInt(2, 9);
        final c = _randInt(2, 9);
        final d = _randInt(2, 9);
        return MathStep(
          '($a + $b) × ($c + $d)',
          (a + b) * (c + d),
          MathLevelKind.hard,
        );
      case 6: // a × (b − c) + d
        final b = _randInt(5, 15);
        final c = _randInt(1, b - 1);
        final a = _randInt(2, 9);
        final d = _randInt(1, 20);
        return MathStep(
          '$a × ($b − $c) + $d',
          a * (b - c) + d,
          MathLevelKind.hard,
        );
      case 7: // (a ÷ b) × (c + d) (clean division by construction)
        final b = _randInt(2, 9);
        final q = _randInt(2, 9);
        final a = b * q;
        final c = _randInt(2, 9);
        final d = _randInt(2, 9);
        return MathStep(
          '($a ÷ $b) × ($c + $d)',
          q * (c + d),
          MathLevelKind.hard,
        );
      default:
        return null;
    }
  }

  // --------------------------------------------------- Public entry points ---

  MathStep buildQuestion(MathLevelKind level, int numVars) {
    switch (level) {
      case MathLevelKind.easy:
        return _buildEasy();
      case MathLevelKind.medium:
        return _buildMedium(numVars);
      case MathLevelKind.hard:
        return _buildHard(numVars);
    }
  }

  /// Expands an alarm's configured puzzles into the ordered list of concrete
  /// challenges the user must solve to dismiss it. The queue is shuffled so
  /// mixed difficulties are interleaved rather than grouped.
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
    queue.shuffle(_rng);
    return queue;
  }
}
