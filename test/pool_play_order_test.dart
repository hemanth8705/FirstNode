// Pool playback order: the manual arrangement, and how many songs shuffle
// leaves alone at the front.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:firstnode/models/pool.dart';
import 'package:firstnode/services/formatters.dart';

/// A, B, C, D, E, F — matching the worked example in the feature request.
Pool poolOf(
  int count, {
  PoolOrder order = PoolOrder.shuffle,
  int frozenCount = 0,
}) => Pool(
  id: 'p1',
  name: 'Test pool',
  order: order,
  frozenCount: frozenCount,
  songs: [
    for (var i = 0; i < count; i++)
      PoolSong(name: String.fromCharCode(65 + i), end: 10),
  ],
);

List<String> names(List<PoolSong> songs) => songs.map((s) => s.name).toList();

void main() {
  group('resolvePlayOrder — linear', () {
    test('follows the arranged order exactly', () {
      final pool = poolOf(6, order: PoolOrder.linear);

      expect(names(resolvePlayOrder(pool)), ['A', 'B', 'C', 'D', 'E', 'F']);
    });

    test('ignores frozenCount, since nothing is randomized anyway', () {
      final pool = poolOf(6, order: PoolOrder.linear, frozenCount: 3);

      expect(names(resolvePlayOrder(pool)), ['A', 'B', 'C', 'D', 'E', 'F']);
    });
  });

  group('resolvePlayOrder — shuffle', () {
    test('with no frozen songs, still a full permutation of the pool', () {
      final pool = poolOf(6);

      final order = resolvePlayOrder(pool, random: Random(1));

      expect(names(order).toSet(), {'A', 'B', 'C', 'D', 'E', 'F'});
      expect(order, hasLength(6));
    });

    test('freezing 2 keeps A and B first and permutes only the rest', () {
      final pool = poolOf(6, frozenCount: 2);

      // Several seeds, because a single shuffle could coincidentally leave the
      // tail in place and hide a bug.
      for (var seed = 0; seed < 25; seed++) {
        final order = names(resolvePlayOrder(pool, random: Random(seed)));

        expect(order.sublist(0, 2), ['A', 'B'], reason: 'seed $seed');
        expect(
          order.sublist(2).toSet(),
          {'C', 'D', 'E', 'F'},
          reason: 'seed $seed',
        );
      }
    });

    test('every song appears exactly once before any repeats', () {
      final pool = poolOf(6, frozenCount: 3);

      for (var seed = 0; seed < 25; seed++) {
        final order = names(resolvePlayOrder(pool, random: Random(seed)));

        expect(order, hasLength(6), reason: 'seed $seed');
        expect(order.toSet(), hasLength(6), reason: 'seed $seed');
      }
    });

    test('does actually shuffle the unfrozen tail', () {
      final pool = poolOf(6, frozenCount: 2);
      final arranged = names(pool.songs);

      final orders = {
        for (var seed = 0; seed < 25; seed++)
          names(resolvePlayOrder(pool, random: Random(seed))).join(),
      };

      expect(
        orders.length,
        greaterThan(1),
        reason: 'the tail should not come out the same every time',
      );
      expect(orders, contains(isNot(arranged.join())));
    });

    test('freezing everything is allowed and plays the arranged order', () {
      final pool = poolOf(3, frozenCount: 3);

      expect(names(resolvePlayOrder(pool, random: Random(7))), [
        'A',
        'B',
        'C',
      ]);
    });

    test('a stale count from deleted songs is clamped, not crashed', () {
      final pool = poolOf(2, frozenCount: 5);

      expect(pool.effectiveFrozenCount, 2);
      expect(names(resolvePlayOrder(pool, random: Random(3))), ['A', 'B']);
    });

    test('an empty pool resolves to an empty order', () {
      expect(resolvePlayOrder(poolOf(0, frozenCount: 2)), isEmpty);
    });

    test('does not mutate the pool it was given', () {
      final pool = poolOf(6, frozenCount: 1);

      resolvePlayOrder(pool, random: Random(5));

      expect(names(pool.songs), ['A', 'B', 'C', 'D', 'E', 'F']);
    });
  });

  group('Pool persistence', () {
    test('frozenCount and the song order survive a JSON round trip', () {
      final pool = poolOf(4, frozenCount: 2);
      pool.songs.insert(0, pool.songs.removeAt(3)); // drag D to the top

      final restored = Pool.fromJson(pool.toJson());

      expect(restored.frozenCount, 2);
      expect(names(restored.songs), ['D', 'A', 'B', 'C']);
    });

    test('pools saved before frozen songs existed shuffle everything', () {
      final json = poolOf(4).toJson()..remove('frozenCount');

      expect(Pool.fromJson(json).frozenCount, 0);
    });

    test('clone is a deep copy, so Cancel discards reorders and freezes', () {
      final pool = poolOf(3, frozenCount: 1);
      final draft = pool.clone();

      draft.frozenCount = 3;
      draft.songs.insert(0, draft.songs.removeAt(2));

      expect(pool.frozenCount, 1);
      expect(names(pool.songs), ['A', 'B', 'C']);
    });
  });

  group('summaries', () {
    test('poolSummary mentions frozen songs only when they apply', () {
      expect(poolSummary(poolOf(6, frozenCount: 2)), '6 songs · shuffle · 2 frozen');
      expect(poolSummary(poolOf(6)), '6 songs · shuffle');
      expect(
        poolSummary(poolOf(6, order: PoolOrder.linear, frozenCount: 2)),
        '6 songs · linear',
      );
      expect(poolSummary(poolOf(1)), '1 song · shuffle');
    });

    test('poolSongSummary flags a frozen song', () {
      final song = PoolSong(name: 'A', start: 0, end: 12, volume: 80);

      expect(poolSongSummary(song), '0:00–0:12 · 80%');
      expect(poolSongSummary(song, frozen: true), '0:00–0:12 · 80% · frozen');
    });
  });
}
