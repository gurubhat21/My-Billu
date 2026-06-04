import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_id_service.dart';

/// Subscription status for the app
enum SubscriptionStatus {
  unregistered,  // Gmail not yet linked
  active,        // Subscription valid
  trial,         // Trial period
  expired,       // Past expiry date
  revoked,       // Admin revoked
  deviceMismatch,// Gmail registered to different device
  grace,         // Offline grace period (7 days)
  error,         // Could not check
}

/// Result of a subscription check
class SubscriptionResult {
  final SubscriptionStatus status;
  final String? email;
  final String? deviceId;
  final DateTime? expiryDate;
  final int? daysLeft;
  final String? message;

  SubscriptionResult({
    required this.status,
    this.email,
    this.deviceId,
    this.expiryDate,
    this.daysLeft,
    this.message,
  });
}

/// Manages subscription state via Firestore
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._();
  factory SubscriptionService() => _instance;
  SubscriptionService._();

  // Local cache keys
  static const _emailKey = 'sub_registered_email';
  static const _statusKey = 'sub_cached_status';
  static const _expiryKey = 'sub_cached_expiry';
  static const _lastCheckKey = 'sub_last_check';
  static const _graceDays = 7;

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore {
    _firestoreInstance ??= FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  /// Get the subscriptions collection reference
  CollectionReference get _subsCollection => _firestore.collection('subscriptions');

  /// Get locally cached registered email
  Future<String?> getCachedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  /// Save email locally after registration
  Future<void> _cacheEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  /// Cache subscription result locally for offline use
  Future<void> _cacheResult(SubscriptionResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusKey, result.status.name);
    if (result.expiryDate != null) {
      await prefs.setString(_expiryKey, result.expiryDate!.toIso8601String());
    }
    await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
  }

  /// Get cached result for offline use
  Future<SubscriptionResult?> _getCachedResult() async {
    final prefs = await SharedPreferences.getInstance();
    final statusStr = prefs.getString(_statusKey);
    final expiryStr = prefs.getString(_expiryKey);
    final lastCheckStr = prefs.getString(_lastCheckKey);
    final email = prefs.getString(_emailKey);

    if (statusStr == null || lastCheckStr == null) return null;

    final lastCheck = DateTime.tryParse(lastCheckStr);
    if (lastCheck == null) return null;

    final daysSinceCheck = DateTime.now().difference(lastCheck).inDays;
    final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;

    // If cached status was active and within grace period
    if (daysSinceCheck <= _graceDays &&
        (statusStr == 'active' || statusStr == 'trial')) {
      final daysLeft = expiry != null ? expiry.difference(DateTime.now()).inDays : null;
      return SubscriptionResult(
        status: SubscriptionStatus.grace,
        email: email,
        expiryDate: expiry,
        daysLeft: daysLeft,
        message: 'Offline mode — last checked $daysSinceCheck day(s) ago',
      );
    }

    return null; // Cache expired
  }

  /// Register a new device with email
  Future<SubscriptionResult> registerDevice(String email, String displayName) async {
    final deviceService = DeviceIdService();
    final deviceId = deviceService.deviceId;
    if (deviceId == null) {
      return SubscriptionResult(
        status: SubscriptionStatus.error,
        message: 'Device ID not available',
      );
    }

    try {
      // Check if email already registered
      final doc = await _subsCollection.doc(email).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // Check platform-specific device ID (Android)
        String existingAndroidId = data['androidDeviceId'] as String? ?? '';
        // Backward compat: if androidDeviceId is empty, check old deviceId
        if (existingAndroidId.isEmpty) {
          final oldDeviceId = data['deviceId'] as String? ?? '';
          if (oldDeviceId.startsWith('and_')) {
            existingAndroidId = oldDeviceId;
          }
        }

        if (existingAndroidId.isNotEmpty && existingAndroidId != deviceId) {
          // Already bound to different Android device
          return SubscriptionResult(
            status: SubscriptionStatus.deviceMismatch,
            email: email,
            deviceId: existingAndroidId,
            message: 'This Gmail is already registered to another Android device. Contact admin for device migration.',
          );
        }

        // Same device re-registering — update with both legacy + platform fields
        await _subsCollection.doc(email).update({
          ...deviceService.toBackwardCompatMap(),
          'displayName': displayName,
          'lastOnlineAt': FieldValue.serverTimestamp(),
          'appVersion': '6.0.0',
        });
      } else {
        // New registration — create with 7-day trial
        final trialExpiry = DateTime.now().add(const Duration(days: 7));
        await _subsCollection.doc(email).set({
          'email': email,
          'displayName': displayName,
          ...deviceService.toBackwardCompatMap(),
          'subscriptionStatus': 'trial',
          'expiryDate': Timestamp.fromDate(trialExpiry),
          'registeredAt': FieldValue.serverTimestamp(),
          'lastOnlineAt': FieldValue.serverTimestamp(),
          'lastCheckAt': FieldValue.serverTimestamp(),
          'appVersion': '6.0.0',
          'migrationHistory': [],
          'notes': '',
        });
      }

      await _cacheEmail(email);

      // Check subscription status after registration
      return await checkSubscription(email);
    } catch (e) {
      debugPrint('Registration error: $e');
      return SubscriptionResult(
        status: SubscriptionStatus.error,
        email: email,
        message: 'Registration failed: $e',
      );
    }
  }

  /// Check subscription status for registered email
  Future<SubscriptionResult> checkSubscription(String email) async {
    final deviceService = DeviceIdService();
    final deviceId = deviceService.deviceId;

    try {
      final doc = await _subsCollection.doc(email).get();

      if (!doc.exists) {
        return SubscriptionResult(
          status: SubscriptionStatus.unregistered,
          email: email,
          message: 'No subscription found',
        );
      }

      final data = doc.data() as Map<String, dynamic>;
      final statusStr = data['subscriptionStatus'] as String? ?? 'trial';
      final expiryTs = data['expiryDate'] as Timestamp?;
      final expiryDate = expiryTs?.toDate();

      // Check platform-specific device match (Android)
      String registeredAndroidId = data['androidDeviceId'] as String? ?? '';
      // Backward compat: if androidDeviceId is empty, check old deviceId
      if (registeredAndroidId.isEmpty) {
        final oldDeviceId = data['deviceId'] as String? ?? '';
        if (oldDeviceId.startsWith('and_')) {
          registeredAndroidId = oldDeviceId;
        }
      }

      if (registeredAndroidId.isNotEmpty && registeredAndroidId != deviceId) {
        final result = SubscriptionResult(
          status: SubscriptionStatus.deviceMismatch,
          email: email,
          deviceId: registeredAndroidId,
          message: 'This account is bound to a different Android device. Contact admin.',
        );
        await _cacheResult(result);
        return result;
      }

      // Check if revoked
      if (statusStr == 'revoked') {
        final result = SubscriptionResult(
          status: SubscriptionStatus.revoked,
          email: email,
          expiryDate: expiryDate,
          message: 'Subscription has been revoked by admin.',
        );
        await _cacheResult(result);
        return result;
      }

      // Check expiry
      if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
        // Update status in Firestore
        await _subsCollection.doc(email).update({
          'subscriptionStatus': 'expired',
          'lastCheckAt': FieldValue.serverTimestamp(),
        });
        final result = SubscriptionResult(
          status: SubscriptionStatus.expired,
          email: email,
          expiryDate: expiryDate,
          daysLeft: 0,
          message: 'Subscription expired on ${expiryDate.toIso8601String().split('T').first}',
        );
        await _cacheResult(result);
        return result;
      }

      // Active or trial
      final daysLeft = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : 999;
      final status = statusStr == 'trial' ? SubscriptionStatus.trial : SubscriptionStatus.active;

      // Update last online with both legacy + platform-specific fields
      await _subsCollection.doc(email).update({
        'lastOnlineAt': FieldValue.serverTimestamp(),
        'lastCheckAt': FieldValue.serverTimestamp(),
        ...deviceService.toBackwardCompatMap(),
        'appVersion': '6.0.0',
      });

      // Log app open to activity_log subcollection
      await logAppOpen(email);

      final result = SubscriptionResult(
        status: status,
        email: email,
        expiryDate: expiryDate,
        daysLeft: daysLeft,
      );
      await _cacheResult(result);
      return result;
    } catch (e) {
      debugPrint('Subscription check error: $e');
      // Try offline cache
      final cached = await _getCachedResult();
      if (cached != null) return cached;

      return SubscriptionResult(
        status: SubscriptionStatus.error,
        email: email,
        message: 'Could not verify subscription. Check internet.',
      );
    }
  }

  /// Log an app open event to the activity_log subcollection
  Future<void> logAppOpen(String email) async {
    try {
      final deviceService = DeviceIdService();
      await _subsCollection.doc(email).collection('activity_log').add({
        'type': 'app_open',
        'timestamp': FieldValue.serverTimestamp(),
        'deviceId': deviceService.deviceId ?? 'unknown',
        'deviceName': deviceService.deviceName ?? 'unknown',
      });
    } catch (e) {
      debugPrint('Failed to log app open: $e');
    }
  }

  /// Clear local registration data (for admin reset)
  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_statusKey);
    await prefs.remove(_expiryKey);
    await prefs.remove(_lastCheckKey);
  }

  // ====== ADMIN FUNCTIONS ======

  /// Get all subscriptions (admin only)
  Future<List<Map<String, dynamic>>> getAllSubscriptions() async {
    try {
      final snap = await _subsCollection.orderBy('registeredAt', descending: true).get();
      return snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Failed to fetch subscriptions: $e');
      return [];
    }
  }

  /// Activate a subscription (admin)
  Future<void> activateSubscription(String email, DateTime expiryDate) async {
    await _subsCollection.doc(email).update({
      'subscriptionStatus': 'active',
      'expiryDate': Timestamp.fromDate(expiryDate),
    });
  }

  /// Revoke a subscription (admin)
  Future<void> revokeSubscription(String email) async {
    await _subsCollection.doc(email).update({
      'subscriptionStatus': 'revoked',
    });
  }

  /// Migrate device — unbind old device so user can re-register on new one (admin)
  /// [platform] can be 'android', 'windows', or 'all' to clear both
  Future<void> migrateDevice(String email, {String reason = 'Device migration', String platform = 'android'}) async {
    final doc = await _subsCollection.doc(email).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final oldAndroidId = data['androidDeviceId'] ?? data['deviceId'] ?? '';
    final oldWindowsId = data['windowsDeviceId'] ?? '';
    final history = List<Map<String, dynamic>>.from(data['migrationHistory'] ?? []);
    history.add({
      'oldAndroidDeviceId': oldAndroidId,
      'oldWindowsDeviceId': oldWindowsId,
      'platform': platform,
      'migratedAt': DateTime.now().toIso8601String(),
      'reason': reason,
    });

    final updateFields = <String, dynamic>{
      'migrationHistory': history,
    };

    if (platform == 'android' || platform == 'all') {
      updateFields['androidDeviceId'] = '';
      updateFields['androidDeviceName'] = '';
      updateFields['androidDeviceModel'] = '';
      // Also clear legacy fields when clearing android
      updateFields['deviceId'] = '';
      updateFields['deviceName'] = '';
      updateFields['deviceModel'] = '';
    }

    if (platform == 'windows' || platform == 'all') {
      updateFields['windowsDeviceId'] = '';
      updateFields['windowsDeviceName'] = '';
      updateFields['windowsDeviceModel'] = '';
    }

    if (platform == 'all') {
      updateFields['platform'] = '';
    }

    await _subsCollection.doc(email).update(updateFields);
  }

  /// Update admin notes (admin)
  Future<void> updateNotes(String email, String notes) async {
    await _subsCollection.doc(email).update({'notes': notes});
  }

  /// Delete a subscription record (admin)
  Future<void> deleteSubscription(String email) async {
    await _subsCollection.doc(email).delete();
  }

  /// Update expiry date (admin)
  Future<void> updateExpiry(String email, DateTime newExpiry) async {
    await _subsCollection.doc(email).update({
      'expiryDate': Timestamp.fromDate(newExpiry),
    });
  }
}
