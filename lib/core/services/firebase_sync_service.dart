import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_state.dart';
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

  Future<void> uploadData(AppState appState) async {
    if (!isSignedIn || _isSyncing) return;
    // Check if cloud sync is enabled by admin
    final syncEnabled = await SubscriptionService().isCloudSyncEnabled();
    if (!syncEnabled) {
      debugPrint('Cloud sync is disabled by admin');
      throw Exception('Cloud sync is disabled. Contact admin to enable.');
    }
    _isSyncing = true;
    try {
      final localSettings = await appState.getAllSettings();
      final Map<String, dynamic> backup = {
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

      // Merge settings: download existing cloud settings first, then overlay local
      // This ensures password, expiry, and other device settings aren't lost
      Map<String, String> mergedSettings = {};
      try {
        final cloudJson = await _readChunked(userDoc, 'settings');
        if (cloudJson != null) {
          final cloudMap = Map<String, dynamic>.from(jsonDecode(cloudJson));
          for (final e in cloudMap.entries) {
            mergedSettings[e.key] = e.value.toString();
          }
        }
      } catch (_) {}
      // Local settings override cloud (local is fresher for this device)
      mergedSettings.addAll(localSettings);
      backup['settings'] = mergedSettings;

      await userDoc.set({
        'email': currentUser!.email,
        'displayName': currentUser!.displayName,
        'lastSyncAt': FieldValue.serverTimestamp(),
        'deviceName': defaultTargetPlatform.name,
        'version': '6.0.0',
      });

      // Upload all collections + settings using chunked writes
      final allKeys = ['items', 'customers', 'bills', 'purchases', 'quotations',
        'expenses', 'creditNotes', 'purchaseReturns', 'suppliers', 'recurringBills',
        'cashBookEntries', 'bankAccounts', 'settings'];

      for (final key in allKeys) {
        final data = backup[key];
        if (data == null) continue;
        await _writeChunked(userDoc, key, jsonEncode(data));
      }
    } finally {
      _isSyncing = false;
    }
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
          uploadData(appState);
        }
      }
    });
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }
}
