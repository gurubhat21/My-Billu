import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';

/// Financial Year Service — manages FY lifecycle, DB switching, year-end close
class FYService {
  static final FYService instance = FYService._();
  FYService._();

  String _activeFY = '';
  List<String> _availableFYs = [];
  Map<String, dynamic> _fyConfig = {};

  String get activeFY => _activeFY;
  List<String> get availableFYs => List.unmodifiable(_availableFYs);

  /// Get FY string from a date (Indian FY: April–March)
  /// e.g., June 2026 → "2026-27", Feb 2027 → "2026-27"
  static String getFYFromDate(DateTime date) {
    final fyStart = date.month >= 4 ? date.year : date.year - 1;
    final fyEnd = fyStart + 1;
    return '$fyStart-${fyEnd.toString().substring(2)}';
  }

  /// Get FY display string e.g., "FY 2026-27"
  static String getFYDisplay(String fy) => 'FY $fy';

  /// Get start date of an FY (April 1st)
  static DateTime getFYStartDate(String fy) {
    final startYear = int.parse(fy.split('-').first);
    return DateTime(startYear, 4, 1);
  }

  /// Get end date of an FY (March 31st)
  static DateTime getFYEndDate(String fy) {
    final startYear = int.parse(fy.split('-').first);
    return DateTime(startYear + 1, 3, 31, 23, 59, 59);
  }

  /// Get the config file path
  String _getConfigPath() {
    final dataPath = DatabaseHelper.dataPath;
    if (dataPath != null) {
      return p.join(dataPath, 'fy_config.json');
    }
    // Android: use a path relative to app's files directory
    return _androidConfigPath ?? '';
  }

  String? _androidConfigPath;

  /// Get the DB filename for a specific FY
  static String getDBFileName(String fy) => 'my_billu_$fy.db';

  /// Initialize FY system — called at app startup
  Future<void> initialize() async {
    if (kIsWeb) return;

    // On Android, resolve the config path from sqflite
    if (DatabaseHelper.dataPath == null) {
      try {
        // Use sqflite's getDatabasesPath for Android
        final dbDir = await _getAndroidDbDir();
        if (dbDir.isNotEmpty) {
          _androidConfigPath = p.join(dbDir, 'fy_config.json');
        }
      } catch (_) {}
    }

    final configPath = _getConfigPath();
    if (configPath.isEmpty) {
      // Fallback: just set display FY
      _activeFY = getFYFromDate(DateTime.now());
      _availableFYs = [_activeFY];
      return;
    }

    final configFile = File(configPath);
    if (configFile.existsSync()) {
      // Load existing config
      try {
        _fyConfig = jsonDecode(configFile.readAsStringSync());
        _activeFY = _fyConfig['activeFY'] ?? getFYFromDate(DateTime.now());
        _availableFYs = List<String>.from(_fyConfig['availableFYs'] ?? [_activeFY]);
      } catch (_) {
        _activeFY = getFYFromDate(DateTime.now());
        _availableFYs = [_activeFY];
      }
    } else {
      // First time — migrate existing DB
      await _firstTimeMigration(configPath);
    }

    // Ensure the active FY DB exists
    await _ensureDBExists(_activeFY);
  }

  /// Get Android database directory path
  Future<String> _getAndroidDbDir() async {
    try {
      // Import dynamically — sqflite provides getDatabasesPath
      final db = await DatabaseHelper.instance.database;
      final dbPath = db.path as String;
      return p.dirname(dbPath);
    } catch (_) {
      return '';
    }
  }

  /// First-time migration: rename existing my_billu.db to FY-specific name
  Future<void> _firstTimeMigration(String configPath) async {
    String? dbDir = DatabaseHelper.dataPath;

    // On Android, derive dir from _androidConfigPath
    if (dbDir == null && _androidConfigPath != null) {
      dbDir = p.dirname(_androidConfigPath!);
    }
    if (dbDir == null) return;

    final currentFY = getFYFromDate(DateTime.now());
    _activeFY = currentFY;
    _availableFYs = [currentFY];

    // Close existing DB
    try {
      final db = await DatabaseHelper.instance.database;
      await db.close();
    } catch (_) {}
    DatabaseHelper.resetDB();

    final oldDbPath = p.join(dbDir, 'my_billu.db');
    final newDbPath = p.join(dbDir, getDBFileName(currentFY));

    final oldFile = File(oldDbPath);
    if (oldFile.existsSync() && !File(newDbPath).existsSync()) {
      // Copy old DB to FY-specific name (keep original as backup)
      oldFile.copySync(newDbPath);
      debugPrint('FY Migration: Copied $oldDbPath → $newDbPath');
    }

    // Save config
    _saveConfig(configPath);

    // Point DB helper to FY-specific file
    if (DatabaseHelper.dataPath != null) {
      DatabaseHelper.setDBFileName(getDBFileName(currentFY));
    } else {
      // Android: set the file name so DatabaseHelper uses it
      DatabaseHelper.setDBFileName(getDBFileName(currentFY));
    }
  }

  /// Get effective data path (works on both Windows and Android)
  Future<String?> _getEffectiveDataPath() async {
    if (DatabaseHelper.dataPath != null) return DatabaseHelper.dataPath;
    // Android: derive from _androidConfigPath or sqflite
    if (_androidConfigPath != null) return p.dirname(_androidConfigPath!);
    try {
      final dbDir = await _getAndroidDbDir();
      if (dbDir.isNotEmpty) return dbDir;
    } catch (_) {}
    return null;
  }

  /// Ensure DB file exists for a given FY
  Future<void> _ensureDBExists(String fy) async {
    DatabaseHelper.setDBFileName(getDBFileName(fy));

    // Opening the database will create it if it doesn't exist
    await DatabaseHelper.instance.database;
  }

  /// Save FY config to disk
  void _saveConfig([String? path]) {
    final configPath = path ?? _getConfigPath();
    if (configPath.isEmpty) return;

    _fyConfig = {
      'activeFY': _activeFY,
      'availableFYs': _availableFYs,
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    try {
      final file = File(configPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_fyConfig));
    } catch (e) {
      debugPrint('FY config save error: $e');
    }
  }

  /// Switch to a different FY
  Future<void> switchToFY(String fy) async {
    if (fy == _activeFY) return;

    // Close current DB
    try {
      final db = await DatabaseHelper.instance.database;
      await db.close();
    } catch (_) {}
    DatabaseHelper.resetDB();

    // Switch to new FY DB
    _activeFY = fy;
    DatabaseHelper.setDBFileName(getDBFileName(fy));
    _saveConfig();

    debugPrint('Switched to FY: $fy');
  }

  /// Close current year and create new FY
  /// Returns the new FY string
  Future<String> closeYearAndCreateNew({
    required List<Map<String, dynamic>> itemsData,
    required List<Map<String, dynamic>> customersData,
    required List<Map<String, dynamic>> suppliersData,
    required List<Map<String, dynamic>> bankAccountsData,
    required List<Map<String, dynamic>> recurringBillsData,
    required List<Map<String, dynamic>> unpaidBillsData,
    required Map<String, String> settingsToCarry,
  }) async {
    final dataPath = await _getEffectiveDataPath();
    if (dataPath == null) throw Exception('Data path not set');

    // Determine new FY
    final currentStartYear = int.parse(_activeFY.split('-').first);
    final newStartYear = currentStartYear + 1;
    final newFY = '$newStartYear-${(newStartYear + 1).toString().substring(2)}';

    // Check if new FY already exists
    if (_availableFYs.contains(newFY)) {
      throw Exception('FY $newFY already exists');
    }

    // Close current DB
    try {
      final db = await DatabaseHelper.instance.database;
      await db.close();
    } catch (_) {}
    DatabaseHelper.resetDB();

    // Create new FY DB
    DatabaseHelper.setDBFileName(getDBFileName(newFY));
    final newDb = await DatabaseHelper.instance.database;

    // Carry forward items (with stock)
    for (final item in itemsData) {
      await newDb.insert('items', item, conflictAlgorithm: 1); // replace
    }

    // Carry forward customers (with outstanding balance)
    for (final customer in customersData) {
      await newDb.insert('customers', customer, conflictAlgorithm: 1);
    }

    // Carry forward unpaid bills
    for (final bill in unpaidBillsData) {
      bill['items'] = bill['items'] is String ? bill['items'] : jsonEncode(bill['items']);
      await newDb.insert('bills', bill, conflictAlgorithm: 1);
    }

    // Carry forward settings (business info, preferences — NOT invoice numbers)
    for (final entry in settingsToCarry.entries) {
      await newDb.insert('settings', {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: 1);
    }

    // Save suppliers, bank accounts, recurring bills as settings JSON
    await newDb.insert('settings', {
      'key': 'suppliers_data',
      'value': jsonEncode(suppliersData),
    }, conflictAlgorithm: 1);

    await newDb.insert('settings', {
      'key': 'bank_accounts',
      'value': jsonEncode(bankAccountsData),
    }, conflictAlgorithm: 1);

    await newDb.insert('settings', {
      'key': 'recurring_bills_data',
      'value': jsonEncode(recurringBillsData),
    }, conflictAlgorithm: 1);

    // Initialize empty JSON data for other entities
    for (final key in [
      'quotations_data', 'expenses_data', 'credit_notes_data',
      'purchase_returns_data', 'cash_book_entries', 'audit_log',
    ]) {
      await newDb.insert('settings', {'key': key, 'value': '[]'},
          conflictAlgorithm: 1);
    }

    // Update FY list
    _availableFYs.add(newFY);
    _activeFY = newFY;
    _saveConfig();

    debugPrint('Year closed. New FY: $newFY created successfully.');
    return newFY;
  }

  /// Check if we're viewing the current calendar FY
  bool isCurrentCalendarFY() {
    return _activeFY == getFYFromDate(DateTime.now());
  }
}
