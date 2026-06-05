import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'device_id_service.dart';

/// Firestore REST API service for Windows (avoids C++ SDK crash).
/// Uses Firestore REST API directly instead of cloud_firestore plugin.
class WindowsFirestoreService {
  static const _projectId = 'my-billu';
  static const _baseUrl =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';
  static const _apiKey = 'AIzaSyA-YWmr8E_D-s1khuNGzs9IXl4Ie6jey-c';

  static const _emailKey = 'sub_registered_email';
  static const _statusKey = 'sub_cached_status';
  static const _expiryKey = 'sub_cached_expiry';
  static const _displayNameKey = 'sub_cached_display_name';

  /// Get cached email
  static Future<String?> getCachedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  /// Save email locally
  static Future<void> _cacheEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  /// Get cached display name
  static Future<String?> getCachedDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }

  /// Cache subscription result
  static Future<void> _cacheResult(String status, String? expiry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusKey, status);
    if (expiry != null) await prefs.setString(_expiryKey, expiry);
  }

  /// Get cached status for offline use
  static Future<Map<String, String?>> getCachedResult() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'status': prefs.getString(_statusKey),
      'expiry': prefs.getString(_expiryKey),
      'email': prefs.getString(_emailKey),
    };
  }

  /// Register device with email via REST API
  static Future<Map<String, dynamic>> registerDevice(String email, String displayName) async {
    final deviceService = DeviceIdService();

    try {
      // Check device ID uniqueness — same device can't register to another Gmail
      final existingEmail = await _findEmailByWindowsDeviceId(deviceService.deviceId ?? '');
      if (existingEmail != null && existingEmail != email) {
        return {
          'status': 'error',
          'message': 'This device is already registered to another account ($existingEmail). Contact admin for migration.',
        };
      }

      // Check if document exists
      final getUrl = '$_baseUrl/subscriptions/$email?key=$_apiKey';
      final getResp = await http.get(Uri.parse(getUrl));

      if (getResp.statusCode == 200) {
        // Document exists — check Windows device
        final data = jsonDecode(getResp.body);
        final fields = data['fields'] as Map<String, dynamic>? ?? {};

        // Check platform-specific device ID (Windows)
        String existingWindowsId = _getString(fields, 'windowsDeviceId');
        // Backward compat: if windowsDeviceId is empty, check old deviceId
        if (existingWindowsId.isEmpty) {
          final oldDeviceId = _getString(fields, 'deviceId');
          if (oldDeviceId.startsWith('win_')) {
            existingWindowsId = oldDeviceId;
          }
        }

        if (existingWindowsId.isNotEmpty &&
            existingWindowsId != (deviceService.deviceId ?? '')) {
          return {
            'status': 'deviceMismatch',
            'message': 'This email is registered to another Windows device. Contact admin for migration.',
          };
        }

        // Same device — update with both legacy + platform-specific fields
        final updateFields = {
          'deviceId': deviceService.deviceId ?? '',
          'deviceName': deviceService.deviceName ?? 'Windows',
          'deviceModel': deviceService.deviceModel ?? 'Desktop',
          'windowsDeviceId': deviceService.deviceId ?? '',
          'windowsDeviceName': deviceService.deviceName ?? 'Windows',
          'windowsDeviceModel': deviceService.deviceModel ?? 'Desktop',
          'platform': 'windows',
          'displayName': displayName,
          'appVersion': '6.0.0',
        };

        // If windowsStatus is empty, set it (e.g. migrated legacy doc)
        final existingWindowsStatus = _getString(fields, 'windowsStatus');
        if (existingWindowsStatus.isEmpty) {
          final legacyStatus = _getString(fields, 'subscriptionStatus');
          updateFields['windowsStatus'] = legacyStatus.isNotEmpty ? legacyStatus : 'trial';
        }

        await _patchDocument(email, updateFields);
      } else if (getResp.statusCode == 404) {
        // New registration — create with 7-day trial
        final trialExpiry = DateTime.now().add(const Duration(days: 7));
        await _createDocument(email, {
          'email': email,
          'displayName': displayName,
          'deviceId': deviceService.deviceId ?? '',
          'deviceName': deviceService.deviceName ?? 'Windows',
          'deviceModel': deviceService.deviceModel ?? 'Desktop',
          'windowsDeviceId': deviceService.deviceId ?? '',
          'windowsDeviceName': deviceService.deviceName ?? 'Windows',
          'windowsDeviceModel': deviceService.deviceModel ?? 'Desktop',
          'platform': 'windows',
          'status': 'trial',
          'subscriptionStatus': 'trial',
          'expiryDate': trialExpiry.toIso8601String(),
          'windowsExpiryDate': trialExpiry.toIso8601String(),
          'windowsStatus': 'trial',
          'registeredAt': DateTime.now().toUtc().toIso8601String(),
          'lastOnlineAt': DateTime.now().toUtc().toIso8601String(),
          'windowsLastOnlineAt': DateTime.now().toUtc().toIso8601String(),
          'cloudSyncEnabled': 'false',
          'appVersion': '6.0.0',
          'notes': '',
        });
      } else {
        return {'status': 'error', 'message': 'Server error: ${getResp.statusCode}'};
      }

      await _cacheEmail(email);
      // Cache display name
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_displayNameKey, displayName);

      // Check subscription
      return await checkSubscription(email);
    } catch (e) {
      debugPrint('Windows registration error: $e');
      return {'status': 'error', 'message': 'Registration failed: $e'};
    }
  }

  /// Check subscription status via REST API
  static Future<Map<String, dynamic>> checkSubscription(String email) async {
    try {
      final url = '$_baseUrl/subscriptions/$email?key=$_apiKey';
      final resp = await http.get(Uri.parse(url));

      if (resp.statusCode == 404) {
        return {'status': 'unregistered', 'message': 'No subscription found'};
      }

      if (resp.statusCode != 200) {
        return {'status': 'error', 'message': 'Server error: ${resp.statusCode}'};
      }

      final data = jsonDecode(resp.body);
      final fields = data['fields'] as Map<String, dynamic>? ?? {};

      // Read windowsStatus first, fall back to legacy subscriptionStatus
      final windowsStatus = _getString(fields, 'windowsStatus');
      final status = windowsStatus.isNotEmpty
          ? windowsStatus
          : _getString(fields, 'subscriptionStatus');

      // Read windowsExpiryDate first, fall back to legacy expiryDate
      final windowsExpiryStr = _getString(fields, 'windowsExpiryDate');
      final expiryStr = windowsExpiryStr.isNotEmpty
          ? windowsExpiryStr
          : _getString(fields, 'expiryDate');
      final expiryDate = DateTime.tryParse(expiryStr);

      // Check revoked
      if (status == 'revoked') {
        await _cacheResult('revoked', expiryStr);
        return {'status': 'revoked', 'message': 'Subscription revoked by admin.'};
      }

      // Check expired
      if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
        await _cacheResult('expired', expiryStr);
        return {
          'status': 'expired',
          'expiryDate': expiryStr,
          'daysLeft': 0,
          'message': 'Subscription expired',
        };
      }

      // Active or trial
      final daysLeft = expiryDate != null
          ? expiryDate.difference(DateTime.now()).inDays
          : 999;

      await _cacheResult(status.isEmpty ? 'trial' : status, expiryStr);

      // Cache cloud sync flags from Firestore (platform-specific first, fallback to legacy)
      final prefs = await SharedPreferences.getInstance();
      final winSyncEnabled = _getString(fields, 'windowsCloudSyncEnabled');
      final legacySyncEnabled = _getString(fields, 'cloudSyncEnabled');
      final winSyncRequested = _getString(fields, 'windowsCloudSyncRequested');
      final legacySyncRequested = _getString(fields, 'cloudSyncRequested');
      await prefs.setBool('sub_cloud_sync_enabled',
          winSyncEnabled == 'true' || (winSyncEnabled.isEmpty && legacySyncEnabled == 'true'));
      await prefs.setBool('sub_cloud_sync_requested',
          winSyncRequested == 'true' || (winSyncRequested.isEmpty && legacySyncRequested == 'true'));

      // Update lastOnline with platform-specific fields
      final deviceService = DeviceIdService();
      final now = DateTime.now().toUtc().toIso8601String();
      await _patchDocument(email, {
        'windowsDeviceId': deviceService.deviceId ?? '',
        'windowsDeviceName': deviceService.deviceName ?? 'Windows',
        'windowsDeviceModel': deviceService.deviceModel ?? 'Desktop',
        'windowsLastOnlineAt': now,
        'lastOnlineAt': now,
        'platform': 'windows',
        'appVersion': '6.0.0',
      });

      // Log app open
      _logAppOpen(email);

      return {
        'status': status.isEmpty ? 'trial' : status,
        'expiryDate': expiryStr,
        'daysLeft': daysLeft,
      };
    } catch (e) {
      debugPrint('Windows subscription check error: $e');
      // Try cached result
      final cached = await getCachedResult();
      if (cached['status'] != null) {
        return {'status': cached['status']!, 'expiryDate': cached['expiry']};
      }
      return {'status': 'error', 'message': 'Check failed: $e'};
    }
  }

  /// Log app open to activity_log subcollection
  static Future<void> _logAppOpen(String email) async {
    try {
      final deviceService = DeviceIdService();
      final logUrl =
          '$_baseUrl/subscriptions/$email/activity_log?key=$_apiKey';
      await http.post(
        Uri.parse(logUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fields': {
            'type': {'stringValue': 'app_open'},
            'platform': {'stringValue': 'windows'},
            'timestamp': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
            'deviceId': {'stringValue': deviceService.deviceId ?? ''},
            'deviceName': {'stringValue': deviceService.deviceName ?? 'Windows'},
          }
        }),
      );
    } catch (_) {}
  }

  /// Create a new Firestore document
  static Future<void> _createDocument(
      String docId, Map<String, String> data) async {
    final url =
        '$_baseUrl/subscriptions?documentId=$docId&key=$_apiKey';
    final fields = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.key == 'expiryDate') {
        fields[entry.key] = {'timestampValue': DateTime.parse(entry.value).toUtc().toIso8601String()};
      } else {
        fields[entry.key] = {'stringValue': entry.value};
      }
    }
    await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields}),
    );
  }

  /// Patch (update) fields in a Firestore document
  static Future<void> _patchDocument(
      String docId, Map<String, String> data) async {
    final updateMask = data.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
    final url =
        '$_baseUrl/subscriptions/$docId?$updateMask&key=$_apiKey';
    final fields = <String, dynamic>{};
    for (final entry in data.entries) {
      fields[entry.key] = {'stringValue': entry.value};
    }
    await http.patch(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields}),
    );
  }

  /// Extract string value from Firestore REST response fields
  static String _getString(Map<String, dynamic> fields, String key) {
    final field = fields[key] as Map<String, dynamic>?;
    if (field == null) return '';
    return (field['stringValue'] ?? field['timestampValue'] ?? '').toString();
  }

  /// Find if a Windows device ID is already registered to another email
  static Future<String?> _findEmailByWindowsDeviceId(String deviceId) async {
    if (deviceId.isEmpty) return null;
    try {
      final url = '$_baseUrl:runQuery?key=$_apiKey';
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'structuredQuery': {
            'from': [{'collectionId': 'subscriptions'}],
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': 'windowsDeviceId'},
                'op': 'EQUAL',
                'value': {'stringValue': deviceId},
              }
            },
            'limit': 1,
          }
        }),
      );
      if (resp.statusCode == 200) {
        final results = jsonDecode(resp.body) as List;
        for (final result in results) {
          final doc = result['document'];
          if (doc != null) {
            final docName = doc['name'] as String;
            return docName.split('/').last;
          }
        }
      }
    } catch (e) {
      debugPrint('Device ID check error: $e');
    }
    return null;
  }

  /// Request device migration from admin
  static Future<void> requestMigration(String email, String platform) async {
    await _patchDocument(email, {
      'migrationRequested': 'true',
      'migrationPlatform': platform,
    });
  }

  /// Request cloud sync from admin via REST API
  static Future<void> requestCloudSync(String email) async {
    await _patchDocument(email, {
      'windowsCloudSyncRequested': 'true',
    });
  }
}
