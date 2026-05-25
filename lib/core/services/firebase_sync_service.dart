import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_state.dart';

class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _autoSyncTimer;
  bool _isSyncing = false;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isAutoSyncActive => _autoSyncTimer != null;
  bool get isSyncing => _isSyncing;

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, use Firebase Auth popup directly
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        final result = await _auth.signInWithPopup(provider);
        return result.user;
      } else if (defaultTargetPlatform == TargetPlatform.windows ||
                 defaultTargetPlatform == TargetPlatform.linux ||
                 defaultTargetPlatform == TargetPlatform.macOS) {
        // On desktop, use signInWithProvider (opens system browser)
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        final result = await _auth.signInWithProvider(provider);
        return result.user;
      } else {
        // On Android/iOS, use google_sign_in package
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

  Future<void> signOut() async {
    stopAutoSync();
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _auth.signOut();
  }

  Future<void> uploadData(AppState appState) async {
    if (!isSignedIn || _isSyncing) return;
    _isSyncing = true;
    try {
      final settings = await appState.getAllSettings();
      final backup = {
        'version': '2.0.0',
        'timestamp': DateTime.now().toIso8601String(),
        'deviceName': defaultTargetPlatform.name,
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
        'settings': settings,
      };

      final userDoc = _firestore.collection('users').doc(currentUser!.uid);

      await userDoc.set({
        'email': currentUser!.email,
        'displayName': currentUser!.displayName,
        'lastSyncAt': FieldValue.serverTimestamp(),
        'deviceName': defaultTargetPlatform.name,
        'version': '2.0.0',
      });

      final collections = ['items', 'customers', 'bills', 'purchases', 'quotations',
        'expenses', 'creditNotes', 'purchaseReturns', 'suppliers', 'recurringBills',
        'cashBookEntries', 'bankAccounts'];

      for (final key in collections) {
        final list = backup[key] as List?;
        if (list != null) {
          await userDoc.collection('data').doc(key).set({
            'data': list,
            'count': list.length,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (backup['settings'] != null) {
        await userDoc.collection('data').doc('settings').set({
          'data': backup['settings'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<Map<String, dynamic>?> downloadData() async {
    if (!isSignedIn) return null;
    try {
      final userDoc = _firestore.collection('users').doc(currentUser!.uid);
      final metaSnap = await userDoc.get();
      if (!metaSnap.exists) return null;

      final backup = <String, dynamic>{
        'version': '2.0.0',
        'timestamp': metaSnap.data()?['lastSyncAt']?.toString() ?? DateTime.now().toIso8601String(),
      };

      final collections = ['items', 'customers', 'bills', 'purchases', 'quotations',
        'expenses', 'creditNotes', 'purchaseReturns', 'suppliers', 'recurringBills',
        'cashBookEntries', 'bankAccounts'];

      for (final key in collections) {
        final snap = await userDoc.collection('data').doc(key).get();
        if (snap.exists && snap.data()?['data'] != null) {
          backup[key] = List<Map<String, dynamic>>.from(
            (snap.data()!['data'] as List).map((e) => Map<String, dynamic>.from(e)));
        }
      }

      final settingsSnap = await userDoc.collection('data').doc('settings').get();
      if (settingsSnap.exists && settingsSnap.data()?['data'] != null) {
        backup['settings'] = Map<String, dynamic>.from(settingsSnap.data()!['data']);
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
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (isSignedIn && !_isSyncing) {
        uploadData(appState);
      }
    });
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }
}
