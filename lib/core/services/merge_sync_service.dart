import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Merge Sync Service — merges local and cloud data by UUID
/// Instead of overwriting, keeps ALL records from both sides.
/// When same UUID exists on both, keeps the one with latest updatedAt.
class MergeSyncService {
  /// Merge two lists of record maps by UUID.
  /// Returns merged list containing union of both, newest wins on conflicts.
  static List<Map<String, dynamic>> mergeCollections(
    List<Map<String, dynamic>> localData,
    List<Map<String, dynamic>> cloudData,
  ) {
    final merged = <String, Map<String, dynamic>>{};

    // Add all local records
    for (final record in localData) {
      final id = record['id']?.toString() ?? '';
      if (id.isNotEmpty) merged[id] = record;
    }

    int addedFromCloud = 0;
    int updatedFromCloud = 0;

    // Merge cloud records
    for (final record in cloudData) {
      final id = record['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      if (!merged.containsKey(id)) {
        // New from cloud — add it
        merged[id] = record;
        addedFromCloud++;
      } else {
        // Conflict — compare updatedAt (or createdAt as fallback)
        final localTime = _parseTime(merged[id]!);
        final cloudTime = _parseTime(record);
        if (cloudTime.isAfter(localTime)) {
          merged[id] = record; // Cloud version is newer
          updatedFromCloud++;
        }
      }
    }

    if (addedFromCloud > 0 || updatedFromCloud > 0) {
      debugPrint('MergeSync: +$addedFromCloud new, ~$updatedFromCloud updated from cloud');
    }

    return merged.values.toList();
  }

  /// Merge settings maps (key-value pairs).
  /// Local settings take priority for user preferences.
  /// Cloud-only keys are preserved (e.g., settings from other devices).
  static Map<String, String> mergeSettings(
    Map<String, String> localSettings,
    Map<String, String> cloudSettings,
  ) {
    final merged = Map<String, String>.from(cloudSettings);
    merged.addAll(localSettings);
    return merged;
  }

  /// Merge JSON-blob collections stored in settings.
  /// These are collections like quotations, expenses, etc. stored as JSON arrays.
  static List<Map<String, dynamic>> mergeJsonBlobCollection(
    String? localJson,
    String? cloudJson,
  ) {
    final localList = parseJsonList(localJson);
    final cloudList = parseJsonList(cloudJson);

    if (localList.isEmpty) return cloudList;
    if (cloudList.isEmpty) return localList;

    return mergeCollections(localList, cloudList);
  }

  /// Parse timestamp from a record map.
  /// Tries updatedAt first, then createdAt, then date, then returns epoch.
  static DateTime _parseTime(Map<String, dynamic> record) {
    for (final key in ['updatedAt', 'createdAt', 'date', 'timestamp']) {
      final val = record[key];
      if (val != null && val.toString().isNotEmpty) {
        final dt = DateTime.tryParse(val.toString());
        if (dt != null) return dt;
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Parse a JSON string into a list of maps.
  static List<Map<String, dynamic>> parseJsonList(String? json) {
    if (json == null || json.isEmpty || json == '[]') return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('MergeSync: Error parsing JSON list: $e');
    }
    return [];
  }
}
