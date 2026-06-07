import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Merge Sync Service — merges local and cloud data by UUID
/// Instead of overwriting, keeps ALL records from both sides.
/// When same UUID exists on both, keeps the one with latest updatedAt.
/// Also resolves number conflicts (e.g., two bills with same billNumber).
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

  /// Merge and resolve number conflicts for bills.
  /// Sorts by createdAt, detects duplicate billNumbers, renumbers conflicts.
  static List<Map<String, dynamic>> mergeBills(
    List<Map<String, dynamic>> localData,
    List<Map<String, dynamic>> cloudData,
  ) {
    final merged = mergeCollections(localData, cloudData);
    return _resolveNumberConflicts(merged, 'billNumber');
  }

  /// Merge and resolve number conflicts for purchases.
  static List<Map<String, dynamic>> mergePurchases(
    List<Map<String, dynamic>> localData,
    List<Map<String, dynamic>> cloudData,
  ) {
    final merged = mergeCollections(localData, cloudData);
    return _resolveNumberConflicts(merged, 'purchaseNumber');
  }

  /// Merge and resolve number conflicts for quotations.
  static List<Map<String, dynamic>> mergeQuotations(
    List<Map<String, dynamic>> localData,
    List<Map<String, dynamic>> cloudData,
  ) {
    final merged = mergeCollections(localData, cloudData);
    return _resolveNumberConflicts(merged, 'quotationNumber');
  }

  /// Merge and resolve number conflicts for credit notes.
  static List<Map<String, dynamic>> mergeCreditNotes(
    List<Map<String, dynamic>> localData,
    List<Map<String, dynamic>> cloudData,
  ) {
    final merged = mergeCollections(localData, cloudData);
    return _resolveNumberConflicts(merged, 'creditNoteNumber');
  }

  /// Merge and resolve number conflicts for purchase returns.
  static List<Map<String, dynamic>> mergePurchaseReturns(
    List<Map<String, dynamic>> localData,
    List<Map<String, dynamic>> cloudData,
  ) {
    final merged = mergeCollections(localData, cloudData);
    return _resolveNumberConflicts(merged, 'returnNumber');
  }

  /// Resolve number conflicts in a merged list.
  /// Sorts by creation time, finds duplicates, renumbers the later ones.
  static List<Map<String, dynamic>> _resolveNumberConflicts(
    List<Map<String, dynamic>> records,
    String numberField,
  ) {
    if (records.length <= 1) return records;

    // Sort by creation time (earliest first)
    records.sort((a, b) => _parseTime(a).compareTo(_parseTime(b)));

    // Find duplicate numbers
    final usedNumbers = <String>{};
    final conflicts = <int>[]; // indices of records with duplicate numbers

    for (var i = 0; i < records.length; i++) {
      final number = records[i][numberField]?.toString() ?? '';
      if (number.isEmpty) continue;
      if (usedNumbers.contains(number)) {
        conflicts.add(i);
      } else {
        usedNumbers.add(number);
      }
    }

    if (conflicts.isEmpty) return records;

    debugPrint('MergeSync: Found ${conflicts.length} $numberField conflicts, renumbering...');

    // Renumber conflicting records
    for (final idx in conflicts) {
      final oldNumber = records[idx][numberField]?.toString() ?? '';
      final newNumber = _generateUniqueNumber(oldNumber, usedNumbers);
      records[idx] = Map<String, dynamic>.from(records[idx]);
      records[idx][numberField] = newNumber;
      usedNumbers.add(newNumber);
      debugPrint('MergeSync: Renumbered $numberField: $oldNumber → $newNumber');
    }

    return records;
  }

  /// Generate a unique number by appending a suffix.
  /// Takes "INV2606-0001" and tries "INV2606-0001-M1", "INV2606-0001-M2", etc.
  /// Or for simple numbers like "001", tries extracting the numeric part and incrementing.
  static String _generateUniqueNumber(String originalNumber, Set<String> usedNumbers) {
    // Try to find the numeric portion and increment
    final numMatch = RegExp(r'(\d+)$').firstMatch(originalNumber);
    if (numMatch != null) {
      final prefix = originalNumber.substring(0, numMatch.start);
      final numStr = numMatch.group(1)!;
      final padLen = numStr.length;
      var nextNum = int.parse(numStr) + 1;

      // Keep incrementing until we find a unique number
      for (var attempt = 0; attempt < 1000; attempt++) {
        final candidate = '$prefix${nextNum.toString().padLeft(padLen, '0')}';
        if (!usedNumbers.contains(candidate)) {
          return candidate;
        }
        nextNum++;
      }
    }

    // Fallback: append -M suffix
    for (var i = 1; i <= 100; i++) {
      final candidate = '$originalNumber-M$i';
      if (!usedNumbers.contains(candidate)) {
        return candidate;
      }
    }

    return '$originalNumber-${DateTime.now().millisecondsSinceEpoch}';
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
