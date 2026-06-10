import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state.dart';
import '../models/item.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import '../models/purchase.dart';
import 'merge_sync_service.dart';
import 'tombstone_service.dart';
import 'windows_firestore_service.dart';
import 'firebase_sync_service.dart';
import 'subscription_service.dart';

/// Sync status for UI display
enum SyncStatus {
  disabled,   // Cloud sync not enabled or not signed in
  synced,     // Up to date
  syncing,    // Currently syncing
  pending,    // Local changes waiting to sync
  error,      // Last sync failed
}

/// Auto-Sync Service — handles automatic upload on data changes + periodic polling
class AutoSyncService {
  static final AutoSyncService _instance = AutoSyncService._();
  factory AutoSyncService() => _instance;
  AutoSyncService._();

  static const _lastSyncKey = 'auto_sync_last_time';
  static const _pollIntervalMinutes = 3;
  static const _debounceSeconds = 10;

  AppState? _appState;
  Timer? _pollTimer;
  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _initialized = false;

  final syncStatus = ValueNotifier<SyncStatus>(SyncStatus.disabled);
  final lastSyncTime = ValueNotifier<DateTime?>(null);

  bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Initialize auto-sync with AppState reference
  Future<void> init(AppState appState) async {
    _appState = appState;
    _initialized = true;

    // Load last sync time
    final prefs = await SharedPreferences.getInstance();
    final lastStr = prefs.getString(_lastSyncKey);
    if (lastStr != null) {
      lastSyncTime.value = DateTime.tryParse(lastStr);
    }

    // Check if sync is available
    await _updateSyncAvailability();
  }

  /// Check if user is signed in and cloud sync is enabled
  Future<bool> _isSyncAvailable() async {
    try {
      if (isWindows) {
        final syncUser = await WindowsFirestoreService.getSyncUser();
        return syncUser?['uid'] != null && syncUser!['uid']!.isNotEmpty;
      } else if (isAndroid) {
        final syncService = FirebaseSyncService();
        if (!syncService.isSignedIn) return false;
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Update sync availability and status
  Future<void> _updateSyncAvailability() async {
    final available = await _isSyncAvailable();
    if (!available) {
      syncStatus.value = SyncStatus.disabled;
      stopPolling();
    } else if (syncStatus.value == SyncStatus.disabled) {
      syncStatus.value = SyncStatus.synced;
    }
  }

  /// Start the polling timer (call after sign-in)
  void startPolling() {
    stopPolling();
    _pollTimer = Timer.periodic(
      const Duration(minutes: _pollIntervalMinutes),
      (_) => _pollForUpdates(),
    );
    debugPrint('AutoSync: Polling started (every $_pollIntervalMinutes min)');
  }

  /// Stop the polling timer
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Called after any local data change (add/edit/delete)
  /// Debounces to avoid syncing on every tiny change
  void markDirty() {
    if (!_initialized || syncStatus.value == SyncStatus.disabled) return;

    syncStatus.value = SyncStatus.pending;

    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Start new debounce: sync after 10 seconds of inactivity
    _debounceTimer = Timer(
      const Duration(seconds: _debounceSeconds),
      () => _autoUpload(),
    );
  }

  /// Auto-upload local data to cloud (debounced)
  Future<void> _autoUpload() async {
    if (_isSyncing || _appState == null) return;

    final available = await _isSyncAvailable();
    if (!available) {
      syncStatus.value = SyncStatus.disabled;
      return;
    }

    await _performSync();
  }

  /// Poll cloud for updates (check if cloud has newer data)
  Future<void> _pollForUpdates() async {
    if (_isSyncing || _appState == null) return;

    final available = await _isSyncAvailable();
    if (!available) return;

    try {
      if (isWindows) {
        // Check cloud timestamp
        final cloudSyncTime = await WindowsFirestoreService.getLastSyncTime();
        if (cloudSyncTime != null && lastSyncTime.value != null) {
          if (cloudSyncTime.isAfter(lastSyncTime.value!.add(const Duration(seconds: 5)))) {
            debugPrint('AutoSync: Cloud has newer data, downloading...');
            await _performSync();
          }
        } else if (cloudSyncTime != null && lastSyncTime.value == null) {
          // First sync — download
          await _performSync();
        }
      } else if (isAndroid) {
        // For Android, just do a full sync periodically
        await _performSync();
      }
    } catch (e) {
      debugPrint('AutoSync: Poll error: $e');
    }
  }

  /// Perform full sync (merge local + cloud)
  Future<void> _performSync() async {
    if (_isSyncing || _appState == null) return;
    _isSyncing = true;
    syncStatus.value = SyncStatus.syncing;

    try {
      if (isWindows) {
        await _windowsSync();
      } else if (isAndroid) {
        await _androidSync();
      }

      // Update last sync time
      final now = DateTime.now();
      lastSyncTime.value = now;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, now.toIso8601String());

      syncStatus.value = SyncStatus.synced;
      debugPrint('AutoSync: Sync completed successfully');
    } catch (e) {
      syncStatus.value = SyncStatus.error;
      debugPrint('AutoSync: Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Windows sync using REST API
  Future<void> _windowsSync() async {
    final appState = _appState!;
    final localSettings = await appState.getAllSettings();

    // Build local data
    final localData = <String, List<Map<String, dynamic>>>{
      'items': appState.items.map((i) => i.toMap()).toList(),
      'customers': appState.customers.map((c) => c.toMap()).toList(),
      'bills': appState.bills.map((b) => b.toMap()).toList(),
      'purchases': appState.purchases.map((p) => p.toMap()).toList(),
      'quotations': appState.quotations.map((q) => q.toMap()).toList(),
      'expenses': appState.expenses.map((e) => e.toMap()).toList(),
      'creditNotes': appState.creditNotes.map((c) => c.toMap()).toList(),
      'purchaseReturns': appState.purchaseReturns.map((p) => p.toMap()).toList(),
      'suppliers': appState.suppliers.map((s) => s.toMap()).toList(),
      'recurringBills': appState.recurringBills.map((r) => r.toMap()).toList(),
      'cashBookEntries': appState.cashBookEntries.map((e) => e.toMap()).toList(),
      'bankAccounts': appState.bankAccounts.map((a) => a.toMap()).toList(),
    };

    // Download cloud data for merge
    Map<String, dynamic>? cloudData;
    try {
      cloudData = await WindowsFirestoreService.downloadSyncData();
    } catch (_) {}

    // Merge cloud tombstones with local
    if (cloudData != null && cloudData['_tombstones'] != null) {
      await TombstoneService.mergeFromCloud(
        Map<String, dynamic>.from(cloudData['_tombstones'] as Map));
    }
    final allTombstones = await TombstoneService.getAll();

    // Merge each collection
    final mergedBackup = <String, dynamic>{};
    for (final key in localData.keys) {
      final cloudList = (cloudData?[key] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      switch (key) {
        case 'bills':
          mergedBackup[key] = MergeSyncService.mergeBills(localData[key]!, cloudList);
          break;
        case 'purchases':
          mergedBackup[key] = MergeSyncService.mergePurchases(localData[key]!, cloudList);
          break;
        case 'quotations':
          mergedBackup[key] = MergeSyncService.mergeQuotations(localData[key]!, cloudList);
          break;
        case 'creditNotes':
          mergedBackup[key] = MergeSyncService.mergeCreditNotes(localData[key]!, cloudList);
          break;
        case 'purchaseReturns':
          mergedBackup[key] = MergeSyncService.mergePurchaseReturns(localData[key]!, cloudList);
          break;
        default:
          mergedBackup[key] = MergeSyncService.mergeCollections(localData[key]!, cloudList);
      }
      // Filter out tombstoned records
      mergedBackup[key] = TombstoneService.filterDeleted(
          mergedBackup[key] as List<Map<String, dynamic>>,
          allTombstones[key] ?? {});
    }

    // Merge settings
    final cloudSettings = <String, String>{};
    if (cloudData?['settings'] != null) {
      final cs = cloudData!['settings'];
      if (cs is Map) {
        for (final e in cs.entries) {
          cloudSettings[e.key.toString()] = e.value.toString();
        }
      }
    }
    mergedBackup['settings'] = MergeSyncService.mergeSettings(localSettings, cloudSettings);

    // Include tombstones in upload
    final tombstones = await TombstoneService.toSerializable();
    mergedBackup['_tombstones'] = tombstones;

    // Upload merged data
    await WindowsFirestoreService.uploadSyncData(mergedBackup);

    // Import cloud-only records into local DB
    if (cloudData != null) {
      final db = appState.dbHelper;
      for (final key in ['items', 'customers', 'bills', 'purchases']) {
        final mergedList = mergedBackup[key] as List<Map<String, dynamic>>;
        final localIds = localData[key]!.map((r) => r['id'].toString()).toSet();

        for (final record in mergedList) {
          final id = record['id']?.toString() ?? '';
          if (id.isNotEmpty && !localIds.contains(id) && !(allTombstones[key]?.contains(id) ?? false)) {
            try {
              switch (key) {
                case 'items': await db.insertItem(Item.fromMap(record)); break;
                case 'customers': await db.insertCustomer(Customer.fromMap(record)); break;
                case 'bills': await db.insertBill(Bill.fromMap(record)); break;
                case 'purchases': await db.insertPurchase(Purchase.fromMap(record)); break;
              }
            } catch (_) {}
          }
        }

        // Delete locally any records deleted on other devices
        final deletedIds = allTombstones[key] ?? {};
        for (final id in deletedIds) {
          if (localIds.contains(id)) {
            try {
              switch (key) {
                case 'items': await db.deleteItem(id); break;
                case 'customers': await db.deleteCustomer(id); break;
                case 'bills': await db.deleteBill(id); break;
                case 'purchases': await db.deletePurchase(id); break;
              }
            } catch (_) {}
          }
        }
      }

      // Update JSON-blob collections
      final jsonCollections = {
        'quotations': 'quotations_data', 'expenses': 'expenses_data',
        'creditNotes': 'credit_notes_data', 'purchaseReturns': 'purchase_returns_data',
        'suppliers': 'suppliers_data', 'recurringBills': 'recurring_bills_data',
        'cashBookEntries': 'cash_book_entries', 'bankAccounts': 'bank_accounts',
      };
      for (final entry in jsonCollections.entries) {
        final mergedList = mergedBackup[entry.key] as List<Map<String, dynamic>>;
        if (mergedList.length > (localData[entry.key]?.length ?? 0)) {
          await db.setSetting(entry.value, jsonEncode(mergedList));
        }
      }

      await appState.reloadAllData();
    }
  }

  /// Android sync using Firebase SDK
  Future<void> _androidSync() async {
    final syncService = FirebaseSyncService();
    if (!syncService.isSignedIn) return;
    await syncService.smartSync(_appState!);
  }

  /// Manual sync (for the button) — returns true on success
  Future<bool> syncNow() async {
    final available = await _isSyncAvailable();
    if (!available) return false;

    try {
      await _performSync();
      return syncStatus.value == SyncStatus.synced;
    } catch (_) {
      return false;
    }
  }

  /// Refresh sync availability (call after sign-in/sign-out)
  Future<void> refreshStatus() async {
    await _updateSyncAvailability();
    if (syncStatus.value != SyncStatus.disabled) {
      startPolling();
    }
  }

  /// Dispose timers
  void dispose() {
    stopPolling();
    syncStatus.dispose();
    lastSyncTime.dispose();
  }
}
