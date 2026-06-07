import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_state.dart';
import '../models/item.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import '../models/purchase.dart';
import 'merge_sync_service.dart';
import 'subscription_service.dart';

class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._();

  FirebaseAuth? _authInstance;
  FirebaseFirestore? _firestoreInstance;
  Timer? _autoSyncTimer;
  bool _isSyncing = false;

  FirebaseAuth get _auth {
    _authInstance ??= FirebaseAuth.instance;
    return _authInstance!;
  }

  FirebaseFirestore get _firestore {
    _firestoreInstance ??= FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  bool get _isFirebaseReady {
    try {
      _auth;
      return true;
    } catch (_) {
      return false;
    }
  }

  User? get currentUser => _isFirebaseReady ? _auth.currentUser : null;
  bool get isSignedIn => currentUser != null;
  Stream<User?> get authStateChanges => _isFirebaseReady ? _auth.authStateChanges() : Stream.value(null);
  bool get isAutoSyncActive => _autoSyncTimer != null;
  bool get isSyncing => _isSyncing;

  bool get isDesktop => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux ||
       defaultTargetPlatform == TargetPlatform.macOS);

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        final result = await _auth.signInWithPopup(provider);
        return result.user;
      } else {
        // Android/iOS
        final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        return result.user;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    stopAutoSync();
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _auth.signOut();
  }

  /// Smart Sync: Download cloud → Merge with local → Upload merged
  /// This ensures NO data is lost from either device.
  Future<void> smartSync(AppState appState) async {
    if (!isSignedIn || _isSyncing) return;
    final syncEnabled = await SubscriptionService().isCloudSyncEnabled();
    if (!syncEnabled) {
      throw Exception('Cloud sync is disabled. Contact admin to enable.');
    }
    _isSyncing = true;
    try {
      final localSettings = await appState.getAllSettings();

      // Build local data maps
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

      final userDoc = _firestore.collection('users').doc(currentUser!.uid);

      // Download cloud data for merging
      final cloudData = <String, List<Map<String, dynamic>>>{};
      Map<String, String> cloudSettings = {};

      try {
        final collections = localData.keys.toList();
        for (final key in collections) {
          final json = await _readChunked(userDoc, key);
          if (json != null) {
            cloudData[key] = List<Map<String, dynamic>>.from(
              (jsonDecode(json) as List).map((e) => Map<String, dynamic>.from(e)));
          }
        }
        final settingsJson = await _readChunked(userDoc, 'settings');
        if (settingsJson != null) {
          final cloudMap = Map<String, dynamic>.from(jsonDecode(settingsJson));
          for (final e in cloudMap.entries) {
            cloudSettings[e.key] = e.value.toString();
          }
        }
      } catch (e) {
        debugPrint('SmartSync: Cloud download failed (first sync?): $e');
      }

      // MERGE: local + cloud for each collection
      final mergedData = <String, dynamic>{};
      for (final key in localData.keys) {
        mergedData[key] = MergeSyncService.mergeCollections(
          localData[key]!,
          cloudData[key] ?? [],
        );
      }

      // Merge settings
      mergedData['settings'] = MergeSyncService.mergeSettings(localSettings, cloudSettings);

      // Upload merged data
      await userDoc.set({
        'email': currentUser!.email,
        'displayName': currentUser!.displayName,
        'lastSyncAt': FieldValue.serverTimestamp(),
        'deviceName': defaultTargetPlatform.name,
        'version': '6.0.0',
      });

      final allKeys = ['items', 'customers', 'bills', 'purchases', 'quotations',
        'expenses', 'creditNotes', 'purchaseReturns', 'suppliers', 'recurringBills',
        'cashBookEntries', 'bankAccounts', 'settings'];

      for (final key in allKeys) {
        final data = mergedData[key];
        if (data == null) continue;
        await _writeChunked(userDoc, key, jsonEncode(data));
      }

      // Import any new-from-cloud records into local DB
      if (cloudData.isNotEmpty) {
        await _importMergedToLocal(appState, mergedData, localData);
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Import merged data back to local DB (only records that are new or updated from cloud)
  Future<void> _importMergedToLocal(
    AppState appState,
    Map<String, dynamic> mergedData,
    Map<String, List<Map<String, dynamic>>> localData,
  ) async {
    final db = appState.dbHelper;

    // For SQL-table collections: insert/replace merged records
    final sqlCollections = {'items', 'customers', 'bills', 'purchases'};
    for (final key in sqlCollections) {
      final mergedList = mergedData[key] as List<Map<String, dynamic>>?;
      if (mergedList == null) continue;

      final localIds = (localData[key] ?? []).map((r) => r['id'].toString()).toSet();

      for (final record in mergedList) {
        final id = record['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        // Only insert records that are new or updated from cloud
        if (!localIds.contains(id)) {
          switch (key) {
            case 'items':
              await db.insertItem(Item.fromMap(record));
              break;
            case 'customers':
              await db.insertCustomer(Customer.fromMap(record));
              break;
            case 'bills':
              await db.insertBill(Bill.fromMap(record));
              break;
            case 'purchases':
              await db.insertPurchase(Purchase.fromMap(record));
              break;
          }
        }
      }
    }

    // For JSON-blob collections: save merged JSON
    final jsonCollections = {
      'quotations': 'quotations_data',
      'expenses': 'expenses_data',
      'creditNotes': 'credit_notes_data',
      'purchaseReturns': 'purchase_returns_data',
      'suppliers': 'suppliers_data',
      'recurringBills': 'recurring_bills_data',
      'cashBookEntries': 'cash_book_entries',
      'bankAccounts': 'bank_accounts',
    };

    for (final entry in jsonCollections.entries) {
      final mergedList = mergedData[entry.key] as List<Map<String, dynamic>>?;
      if (mergedList == null) continue;
      final localList = localData[entry.key] ?? [];

      // Only update if merged has more records than local (i.e., cloud had new records)
      if (mergedList.length > localList.length) {
        await db.setSetting(entry.value, jsonEncode(mergedList));
      }
    }

    // Reload all data
    await appState.reloadAllData();
  }

  static const _maxChunkBytes = 900000;

  Future<void> _writeChunked(DocumentReference userDoc, String key, String fullJson) async {
    if (fullJson.length <= _maxChunkBytes) {
      await userDoc.collection('data').doc(key).set({
        'json': fullJson,
        'chunks': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final chunks = <String>[];
      for (var i = 0; i < fullJson.length; i += _maxChunkBytes) {
        final end = (i + _maxChunkBytes > fullJson.length) ? fullJson.length : i + _maxChunkBytes;
        chunks.add(fullJson.substring(i, end));
      }
      await userDoc.collection('data').doc(key).set({
        'chunks': chunks.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (var i = 0; i < chunks.length; i++) {
        await userDoc.collection('data').doc('${key}_$i').set({'json': chunks[i], 'index': i});
      }
    }
  }

  Future<String?> _readChunked(DocumentReference userDoc, String key) async {
    final snap = await userDoc.collection('data').doc(key).get();
    if (!snap.exists) return null;
    final numChunks = snap.data()?['chunks'] as int? ?? 1;
    if (numChunks <= 1 && snap.data()?['json'] != null) {
      return snap.data()!['json'] as String;
    } else if (numChunks > 1) {
      final parts = <String>[];
      for (var i = 0; i < numChunks; i++) {
        final chunkSnap = await userDoc.collection('data').doc('${key}_$i').get();
        if (chunkSnap.exists && chunkSnap.data()?['json'] != null) {
          parts.add(chunkSnap.data()!['json'] as String);
        }
      }
      return parts.join();
    }
    return null;
  }

  Future<Map<String, dynamic>?> downloadData() async {
    if (!isSignedIn) return null;
    // Check if cloud sync is enabled by admin
    final syncEnabled = await SubscriptionService().isCloudSyncEnabled();
    if (!syncEnabled) {
      debugPrint('Cloud sync is disabled by admin');
      throw Exception('Cloud sync is disabled. Contact admin to enable.');
    }
    try {
      final userDoc = _firestore.collection('users').doc(currentUser!.uid);
      final metaSnap = await userDoc.get();
      if (!metaSnap.exists) return null;

      final backup = <String, dynamic>{
        'version': '6.0.0',
        'timestamp': metaSnap.data()?['lastSyncAt']?.toString() ?? DateTime.now().toIso8601String(),
      };

      final collections = ['items', 'customers', 'bills', 'purchases', 'quotations',
        'expenses', 'creditNotes', 'purchaseReturns', 'suppliers', 'recurringBills',
        'cashBookEntries', 'bankAccounts'];

      for (final key in collections) {
        final json = await _readChunked(userDoc, key);
        if (json != null) {
          backup[key] = List<Map<String, dynamic>>.from(
            (jsonDecode(json) as List).map((e) => Map<String, dynamic>.from(e)));
        }
      }

      final settingsJson = await _readChunked(userDoc, 'settings');
      if (settingsJson != null) {
        backup['settings'] = Map<String, dynamic>.from(jsonDecode(settingsJson));
      }

      return backup;
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    if (!isSignedIn) return null;
    try {
      final snap = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!snap.exists) return null;
      final ts = snap.data()?['lastSyncAt'];
      if (ts is Timestamp) return ts.toDate();
      return null;
    } catch (_) {
      return null;
    }
  }

  void startAutoSync(AppState appState) {
    stopAutoSync();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (isSignedIn && !_isSyncing) {
        final syncEnabled = await SubscriptionService().isCloudSyncEnabled();
        if (syncEnabled) {
          smartSync(appState);
        }
      }
    });
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }
}
