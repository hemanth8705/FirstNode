/// Puzzles the user must solve to dismiss an alarm.
///
/// There are two kinds. We model them as a **sealed** family so the compiler
/// forces us to handle both wherever we `switch` on a puzzle:
///   * [RewritePuzzle] — retype a randomly generated string exactly.
///   * [MathPuzzle]    — solve one or more arithmetic questions.
library;

enum PuzzleType { rewrite, math }

sealed class Puzzle {
  PuzzleType get type;

  /// A short human label for the list row ("Rewrite" / "Math").
  String get title;

  Map<String, dynamic> toJson();

  /// Deep copy — used when editing so we can cancel without mutating the saved alarm.
  Puzzle clone();

  static Puzzle fromJson(Map<String, dynamic> j) {
    return j['type'] == 'rewrite'
        ? RewritePuzzle.fromJson(j)
        : MathPuzzle.fromJson(j);
  }
}

/// "Retype this string" puzzle. Which character sets are allowed and how long.
class RewritePuzzle implements Puzzle {
  bool upper;
  bool lower;
  bool numbers;
  bool special;
  int length;

  RewritePuzzle({
    this.upper = true,
    this.lower = true,
    this.numbers = false,
    this.special = false,
    this.length = 8,
  });

  @override
  PuzzleType get type => PuzzleType.rewrite;

  @override
  String get title => 'Rewrite';

  @override
  RewritePuzzle clone() => RewritePuzzle(
    upper: upper,
    lower: lower,
    numbers: numbers,
    special: special,
    length: length,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'rewrite',
    'upper': upper,
    'lower': lower,
    'numbers': numbers,
    'special': special,
    'length': length,
  };

  factory RewritePuzzle.fromJson(Map<String, dynamic> j) => RewritePuzzle(
    upper: j['upper'] ?? true,
    lower: j['lower'] ?? true,
    numbers: j['numbers'] ?? false,
    special: j['special'] ?? false,
    length: j['length'] ?? 8,
  );
}

enum DiffMode { fixed, random }

enum MathLevelKind { easy, medium, hard }

/// How many questions of one difficulty level appear: either a [DiffMode.fixed]
/// [count], or a random amount between [min] and [max].
class Difficulty {
  final MathLevelKind level;
  DiffMode mode;
  int count;
  int min;
  int max;

  Difficulty({
    required this.level,
    this.mode = DiffMode.fixed,
    this.count = 0,
    this.min = 0,
    this.max = 0,
  });

  Difficulty clone() =>
      Difficulty(level: level, mode: mode, count: count, min: min, max: max);

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'mode': mode.name,
    'count': count,
    'min': min,
    'max': max,
  };

  factory Difficulty.fromJson(Map<String, dynamic> j) => Difficulty(
    level: MathLevelKind.values.byName(j['level']),
    mode: DiffMode.values.byName(j['mode']),
    count: j['count'] ?? 0,
    min: j['min'] ?? 0,
    max: j['max'] ?? 0,
  );
}

/// Arithmetic puzzle: [variables] terms per question, and a mix of how many
/// easy/medium/hard questions to ask. [levels] is always the three levels in
/// order (easy, medium, hard).
class MathPuzzle implements Puzzle {
  int variables;
  List<Difficulty> levels;

  MathPuzzle({this.variables = 2, List<Difficulty>? levels})
    : levels =
          levels ??
          [
            Difficulty(level: MathLevelKind.easy, count: 1),
            Difficulty(level: MathLevelKind.medium, count: 0),
            Difficulty(level: MathLevelKind.hard, count: 0),
          ];

  Difficulty level(MathLevelKind k) => levels.firstWhere((d) => d.level == k);

  @override
  PuzzleType get type => PuzzleType.math;

  @override
  String get title => 'Math';

  @override
  MathPuzzle clone() => MathPuzzle(
    variables: variables,
    levels: levels.map((d) => d.clone()).toList(),
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'math',
    'variables': variables,
    'levels': levels.map((d) => d.toJson()).toList(),
  };

  factory MathPuzzle.fromJson(Map<String, dynamic> j) => MathPuzzle(
    variables: j['variables'] ?? 2,
    levels: (j['levels'] as List)
        .map((e) => Difficulty.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}
