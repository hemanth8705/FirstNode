import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm.dart';
import '../models/pool.dart';

/// The full set of persisted data, loaded together.
class AppData {
  final List<Alarm> alarms;
  final List<Pool> pools;
  AppData(this.alarms, this.pools);
}

/// Saves and loads the app's data as a single JSON string in
/// `shared_preferences` (a tiny key/value store on the device).
///
/// This is deliberately simple: our data is small, so we don't need a database.
/// The `_v1` in the key lets us migrate the format later if needed.
class Storage {
  static const String _key = 'firstnode_data_v1';

  Future<AppData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final alarms = (map['alarms'] as List)
        .map((e) => Alarm.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final pools = (map['pools'] as List)
        .map((e) => Pool.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return AppData(alarms, pools);
  }

  Future<void> save(List<Alarm> alarms, List<Pool> pools) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode({
      'alarms': alarms.map((a) => a.toJson()).toList(),
      'pools': pools.map((p) => p.toJson()).toList(),
    });
    await prefs.setString(_key, raw);
  }
}
