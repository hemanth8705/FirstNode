/// A "pool" is a named group of songs the alarm can draw from, played in
/// [PoolOrder.linear] or [PoolOrder.shuffle] order. Each song in the pool can
/// be trimmed (start/end) and have its own volume.
enum PoolOrder { linear, shuffle }

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
  List<PoolSong> songs;

  Pool({
    required this.id,
    this.name = '',
    this.order = PoolOrder.linear,
    List<PoolSong>? songs,
  }) : songs = songs ?? [];

  Pool clone() => Pool(
    id: id,
    name: name,
    order: order,
    songs: songs.map((s) => s.clone()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'order': order.name,
    'songs': songs.map((s) => s.toJson()).toList(),
  };

  factory Pool.fromJson(Map<String, dynamic> j) => Pool(
    id: j['id'],
    name: j['name'] ?? '',
    order: PoolOrder.values.byName(j['order']),
    songs: (j['songs'] as List)
        .map((e) => PoolSong.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}
