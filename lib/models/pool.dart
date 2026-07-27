import 'dart:math';

/// A "pool" is a named group of songs the alarm can draw from, played in
/// [PoolOrder.linear] or [PoolOrder.shuffle] order. Each song in the pool can
/// be trimmed (start/end) and have its own volume.
enum PoolOrder { linear, shuffle }

/// Upper bound for [Pool.frozenCount] — beyond a handful of fixed songs you're
/// really asking for [PoolOrder.linear].
const int kMaxFrozenSongs = 5;

class PoolSong {
  String name;
  int start; // trim start, seconds
  int end; // trim end, seconds
  int volume; // 0..100

  PoolSong({
    required this.name,
    this.start = 0,
    this.end = 60,
    this.volume = 80,
  });

  PoolSong clone() =>
      PoolSong(name: name, start: start, end: end, volume: volume);

  Map<String, dynamic> toJson() => {
    'name': name,
    'start': start,
    'end': end,
    'volume': volume,
  };

  factory PoolSong.fromJson(Map<String, dynamic> j) => PoolSong(
    name: j['name'],
    start: j['start'] ?? 0,
    end: j['end'] ?? 60,
    volume: j['volume'] ?? 80,
  );
}

class Pool {
  String id;
  String name;
  PoolOrder order;

  /// The songs in the order the user arranged them (drag-and-drop in the pool
  /// editor). This is the base ordering for both playback modes: [PoolOrder.linear]
  /// plays it exactly, and [PoolOrder.shuffle] keeps its first [frozenCount]
  /// entries before randomizing the rest.
  List<PoolSong> songs;

  /// How many songs stay put at the front under [PoolOrder.shuffle], so a
  /// favourite can always open the alarm while the rest stays a surprise.
  /// 0 (the default) shuffles everything — the original behavior.
  int frozenCount;

  Pool({
    required this.id,
    this.name = '',
    this.order = PoolOrder.linear,
    List<PoolSong>? songs,
    this.frozenCount = 0,
  }) : songs = songs ?? [];

  /// [frozenCount] clamped to what the pool actually holds — songs can be
  /// removed after a count was chosen, and freezing more than exist would just
  /// mean "freeze them all".
  int get effectiveFrozenCount => frozenCount.clamp(0, songs.length);

  Pool clone() => Pool(
    id: id,
    name: name,
    order: order,
    songs: songs.map((s) => s.clone()).toList(),
    frozenCount: frozenCount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'order': order.name,
    'songs': songs.map((s) => s.toJson()).toList(),
    'frozenCount': frozenCount,
  };

  factory Pool.fromJson(Map<String, dynamic> j) => Pool(
    id: j['id'],
    name: j['name'] ?? '',
    order: PoolOrder.values.byName(j['order']),
    songs: (j['songs'] as List)
        .map((e) => PoolSong.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    // Pools saved before frozen songs existed have no key — 0 keeps their
    // shuffle behaving exactly as it did.
    frozenCount: j['frozenCount'] ?? 0,
  );
}

/// The order one pass through [pool] plays in.
///
/// * [PoolOrder.linear] — the user's arrangement, exactly.
/// * [PoolOrder.shuffle] — the first [Pool.effectiveFrozenCount] songs stay in
///   place and everything after them is shuffled.
///
/// Always a permutation of [Pool.songs], so every song plays once before any
/// repeats. Pass [random] to make the shuffle deterministic in tests.
List<PoolSong> resolvePlayOrder(Pool pool, {Random? random}) {
  final songs = List<PoolSong>.of(pool.songs);
  if (pool.order == PoolOrder.linear) return songs;

  final frozen = pool.effectiveFrozenCount;
  final tail = songs.sublist(frozen)..shuffle(random);
  return [...songs.take(frozen), ...tail];
}
