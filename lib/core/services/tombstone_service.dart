import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks deleted record IDs so sync doesn't bring them back.
/// Stores a map of collection -> Set<deletedId> in SharedPreferences.
class TombstoneService {
  static const _key = 'sync_tombstones';

  /// Record a deletion
  static Future<void> recordDeletion(String collection, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final tombstones = _load(prefs);
    tombstones.putIfAbsent(collection, () => <String>{});
    tombstones[collection]!.add(id);
    await _save(prefs, tombstones);
  }

  /// Get all tombstones as Map<collection, Set<id>>
  static Future<Map<String, Set<String>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _load(prefs);
  }

  /// Get tombstone IDs for a specific collection
  static Future<Set<String>> getForCollection(String collection) async {
    final all = await getAll();
    return all[collection] ?? <String>{};
  }

  /// Get all tombstones as a serializable map (for uploading to cloud)
  static Future<Map<String, List<String>>> toSerializable() async {
    final all = await getAll();
    return all.map((k, v) => MapEntry(k, v.toList()));
  }

  /// Merge cloud tombstones with local ones
  static Future<void> mergeFromCloud(Map<String, dynamic>? cloudTombstones) async {
    if (cloudTombstones == null || cloudTombstones.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final local = _load(prefs);
    for (final entry in cloudTombstones.entries) {
      final ids = (entry.value as List).map((e) => e.toString()).toSet();
      local.putIfAbsent(entry.key, () => <String>{});
      local[entry.key]!.addAll(ids);
    }
    await _save(prefs, local);
  }

  /// Filter out tombstoned records from a list
  static List<Map<String, dynamic>> filterDeleted(
    List<Map<String, dynamic>> records,
    Set<String> deletedIds,
  ) {
    if (deletedIds.isEmpty) return records;
    return records.where((r) {
      final id = r['id']?.toString() ?? '';
      return !deletedIds.contains(id);
    }).toList();
  }

  /// Clear all tombstones (e.g., after factory reset)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Map<String, Set<String>> _load(SharedPreferences prefs) {
    final json = prefs.getString(_key);
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(
        k,
        (v as List).map((e) => e.toString()).toSet(),
      ));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save(SharedPreferences prefs, Map<String, Set<String>> tombstones) async {
    final serializable = tombstones.map((k, v) => MapEntry(k, v.toList()));
    await prefs.setString(_key, jsonEncode(serializable));
  }
}
