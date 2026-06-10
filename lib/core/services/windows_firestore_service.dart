import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
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
      final winSyncEnabled = _getBool(fields, 'windowsCloudSyncEnabled');
      final legacySyncEnabled = _getBool(fields, 'cloudSyncEnabled');
      final winSyncRequested = _getBool(fields, 'windowsCloudSyncRequested');
      final legacySyncRequested = _getBool(fields, 'cloudSyncRequested');
      await prefs.setBool('sub_cloud_sync_enabled',
          winSyncEnabled ?? legacySyncEnabled ?? false);
      await prefs.setBool('sub_cloud_sync_requested',
          winSyncRequested ?? legacySyncRequested ?? false);

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
    return (field['stringValue'] ?? field['timestampValue'] ?? field['booleanValue']?.toString() ?? '').toString();
  }

  /// Read a boolean field from Firestore REST API format
  /// Handles: booleanValue (true/false), stringValue ("true"/"false")
  static bool? _getBool(Map<String, dynamic> fields, String key) {
    final field = fields[key] as Map<String, dynamic>?;
    if (field == null) return null;
    // Direct boolean value
    if (field.containsKey('booleanValue')) return field['booleanValue'] == true;
    // String "true"/"false"
    if (field.containsKey('stringValue')) return field['stringValue'] == 'true';
    return null;
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

  /// Activate subscription via REST API (updates Firestore + local cache)
  static Future<void> activateSubscription(String email, DateTime expiryDate) async {
    final expiryStr = expiryDate.toUtc().toIso8601String();
    await _patchDocument(email, {
      'subscriptionStatus': 'active',
      'expiryDate': expiryStr,
      'windowsStatus': 'active',
      'windowsExpiryDate': expiryStr,
      'lastActivatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    // Cache locally
    await _cacheResult('active', expiryStr);
  }
  /// Refresh cloud sync status from Firestore (call before showing settings)
  static Future<Map<String, bool>> refreshCloudSyncStatus(String email) async {
    try {
      final url = '$_baseUrl/subscriptions/$email?key=$_apiKey';
      final resp = await http.get(Uri.parse(url));

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body);
      final fields = data['fields'] as Map<String, dynamic>? ?? {};

      final winSyncEnabled = _getBool(fields, 'windowsCloudSyncEnabled');
      final legacySyncEnabled = _getBool(fields, 'cloudSyncEnabled');
      final winSyncRequested = _getBool(fields, 'windowsCloudSyncRequested');
      final legacySyncRequested = _getBool(fields, 'cloudSyncRequested');

      final enabled = winSyncEnabled ?? legacySyncEnabled ?? false;
      final requested = winSyncRequested ?? legacySyncRequested ?? false;

      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sub_cloud_sync_enabled', enabled);
      await prefs.setBool('sub_cloud_sync_requested', requested);

      return {'enabled': enabled, 'requested': requested};
    } catch (e) {
      debugPrint('Failed to refresh cloud sync status: $e');
      // Fall back to local cache
      final prefs = await SharedPreferences.getInstance();
      return {
        'enabled': prefs.getBool('sub_cloud_sync_enabled') ?? false,
        'requested': prefs.getBool('sub_cloud_sync_requested') ?? false,
      };
    }
  }

  // ====== CLOUD SYNC (Auth + Data) ======

  static const _authUrl = 'https://identitytoolkit.googleapis.com/v1/accounts';
  static const _googleClientId = '348057118012-dpdk6o8smrjg15k1vl3h0hfc21qiq7dj.apps.googleusercontent.com';
  static const _syncUidKey = 'win_sync_uid';
  static const _syncEmailKey = 'win_sync_email';
  static const _syncIdTokenKey = 'win_sync_id_token';
  static const _syncRefreshTokenKey = 'win_sync_refresh_token';
  static const _syncLastSyncKey = 'win_sync_last_sync';

  /// Sign in with email/password via Firebase Auth REST API
  static Future<Map<String, String>> signInWithEmail(String email, String password) async {
    // Try sign in first
    var resp = await http.post(
      Uri.parse('$_authUrl:signInWithPassword?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}),
    );

    if (resp.statusCode == 400) {
      final err = jsonDecode(resp.body);
      final errMsg = err['error']?['message'] ?? '';
      if (errMsg == 'EMAIL_NOT_FOUND') {
        // Create new account
        resp = await http.post(
          Uri.parse('$_authUrl:signUp?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}),
        );
        if (resp.statusCode != 200) {
          final e = jsonDecode(resp.body);
          throw Exception(e['error']?['message'] ?? 'Sign up failed');
        }
      } else {
        throw Exception(errMsg.replaceAll('_', ' ').toLowerCase());
      }
    } else if (resp.statusCode != 200) {
      throw Exception('Auth failed: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body);
    final uid = data['localId'] as String;
    final idToken = data['idToken'] as String;
    final refreshToken = data['refreshToken'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncUidKey, uid);
    await prefs.setString(_syncEmailKey, email);
    await prefs.setString(_syncIdTokenKey, idToken);
    await prefs.setString(_syncRefreshTokenKey, refreshToken);

    return {'uid': uid, 'email': email, 'idToken': idToken};
  }

  /// Sign in with Google via browser OAuth (loopback server)
  static Future<void> signInWithGoogle() async {
    // 1. Start a local HTTP server to receive the OAuth callback
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final redirectUri = 'http://localhost:$port';

    // 2. Build the Google OAuth URL
    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _googleClientId,
      'redirect_uri': redirectUri,
      'response_type': 'token',
      'scope': 'email profile',
      'prompt': 'select_account',
    });

    // 3. Open browser
    await launchUrl(authUri, mode: LaunchMode.externalApplication);

    // 4. Listen for callbacks using a Completer
    final completer = Completer<String>();
    late final StreamSubscription<HttpRequest> subscription;

    subscription = server.listen((request) async {
      final token = request.uri.queryParameters['access_token'];

      if (token != null && token.isNotEmpty) {
        // Got the token (from JavaScript redirect)
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('<html><body><h2>✅ Signed in! You can close this tab.</h2></body></html>');
        await request.response.close();
        if (!completer.isCompleted) completer.complete(token);
      } else {
        // First request: serve page that extracts token from URL fragment
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('''<!DOCTYPE html><html><body>
<h2>Signing in...</h2>
<script>
  var hash = window.location.hash.substring(1);
  var params = new URLSearchParams(hash);
  var token = params.get('access_token');
  if (token) {
    fetch('/callback?access_token=' + token).then(function() {
      document.body.innerHTML = '<h2>✅ Signed in! You can close this tab.</h2>';
    });
  } else {
    document.body.innerHTML = '<h2>❌ Sign in failed. Please try again.</h2>';
  }
</script></body></html>''');
        await request.response.close();
      }
    });

    try {
      final accessToken = await completer.future.timeout(const Duration(minutes: 2));
      await subscription.cancel();
      await server.close();
      await _firebaseSignInWithGoogleToken(accessToken);
    } catch (e) {
      await subscription.cancel();
      await server.close();
      rethrow;
    }
  }

  /// Exchange Google access token for Firebase Auth via signInWithIdp
  static Future<void> _firebaseSignInWithGoogleToken(String accessToken) async {
    final resp = await http.post(
      Uri.parse('$_authUrl:signInWithIdp?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'postBody': 'access_token=$accessToken&providerId=google.com',
        'requestUri': 'http://localhost',
        'returnIdpCredential': true,
        'returnSecureToken': true,
      }),
    );

    if (resp.statusCode != 200) {
      final err = jsonDecode(resp.body);
      throw Exception(err['error']?['message'] ?? 'Firebase sign-in failed');
    }

    final data = jsonDecode(resp.body);
    final uid = data['localId'] as String;
    final email = data['email'] as String? ?? '';
    final idToken = data['idToken'] as String;
    final refreshToken = data['refreshToken'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncUidKey, uid);
    await prefs.setString(_syncEmailKey, email);
    await prefs.setString(_syncIdTokenKey, idToken);
    await prefs.setString(_syncRefreshTokenKey, refreshToken);
  }

  /// Get cached sync user info
  static Future<Map<String, String?>> getSyncUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'uid': prefs.getString(_syncUidKey),
      'email': prefs.getString(_syncEmailKey),
    };
  }

  /// Sign out (clear sync tokens)
  static Future<void> syncSignOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncUidKey);
    await prefs.remove(_syncEmailKey);
    await prefs.remove(_syncIdTokenKey);
    await prefs.remove(_syncRefreshTokenKey);
  }

  /// Get a fresh ID token (refresh if needed)
  static Future<String?> _getFreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_syncRefreshTokenKey);
    if (refreshToken == null) return null;

    final resp = await http.post(
      Uri.parse('https://securetoken.googleapis.com/v1/token?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'grant_type': 'refresh_token', 'refresh_token': refreshToken}),
    );

    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body);
    final newToken = data['id_token'] as String;
    final newRefresh = data['refresh_token'] as String;
    await prefs.setString(_syncIdTokenKey, newToken);
    await prefs.setString(_syncRefreshTokenKey, newRefresh);
    return newToken;
  }

  /// Upload data to Firestore (users/{uid}/data/...)
  static Future<void> uploadSyncData(Map<String, dynamic> backup) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_syncUidKey);
    if (uid == null) throw Exception('Not signed in');

    final token = await _getFreshToken();
    if (token == null) throw Exception('Auth expired. Sign in again.');

    final userDocUrl = '$_baseUrl/users/$uid?key=$_apiKey';

    // Set user metadata
    await http.patch(
      Uri.parse('$userDocUrl'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'fields': {
        'email': {'stringValue': prefs.getString(_syncEmailKey) ?? ''},
        'lastSyncAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
        'deviceName': {'stringValue': 'Windows'},
        'version': {'stringValue': '6.0.0'},
      }}),
    );

    // Upload each collection as a sub-document
    for (final key in backup.keys) {
      if (key == 'version' || key == 'timestamp') continue;
      final jsonStr = jsonEncode(backup[key]);
      final dataDocUrl = '$_baseUrl/users/$uid/data/$key?key=$_apiKey';

      if (jsonStr.length <= 900000) {
        await http.patch(
          Uri.parse(dataDocUrl),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'fields': {
            'json': {'stringValue': jsonStr},
            'chunks': {'integerValue': '1'},
            'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
          }}),
        );
      } else {
        // Chunked write
        final chunks = <String>[];
        for (var i = 0; i < jsonStr.length; i += 900000) {
          final end = (i + 900000 > jsonStr.length) ? jsonStr.length : i + 900000;
          chunks.add(jsonStr.substring(i, end));
        }
        await http.patch(
          Uri.parse(dataDocUrl),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'fields': {
            'chunks': {'integerValue': '${chunks.length}'},
            'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
          }}),
        );
        for (var i = 0; i < chunks.length; i++) {
          final chunkUrl = '$_baseUrl/users/$uid/data/${key}_$i?key=$_apiKey';
          await http.patch(
            Uri.parse(chunkUrl),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'fields': {
              'json': {'stringValue': chunks[i]},
              'index': {'integerValue': '$i'},
            }}),
          );
        }
      }
    }

    await prefs.setString(_syncLastSyncKey, DateTime.now().toIso8601String());
  }

  /// Download data from Firestore
  static Future<Map<String, dynamic>?> downloadSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_syncUidKey);
    if (uid == null) return null;

    final token = await _getFreshToken();
    if (token == null) throw Exception('Auth expired. Sign in again.');

    // Check user doc exists
    final userUrl = '$_baseUrl/users/$uid?key=$_apiKey';
    final userResp = await http.get(
      Uri.parse(userUrl),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (userResp.statusCode != 200) return null;

    final backup = <String, dynamic>{'version': '6.0.0'};

    final collections = ['items', 'customers', 'bills', 'purchases', 'quotations',
      'expenses', 'creditNotes', 'purchaseReturns', 'suppliers', 'recurringBills',
      'cashBookEntries', 'bankAccounts', 'settings'];

    for (final key in collections) {
      final json = await _readSyncChunked(uid, token, key);
      if (json != null) {
        if (key == 'settings') {
          backup[key] = Map<String, dynamic>.from(jsonDecode(json));
        } else {
          backup[key] = List<Map<String, dynamic>>.from(
            (jsonDecode(json) as List).map((e) => Map<String, dynamic>.from(e)));
        }
      }
    }

    return backup;
  }

  /// Read a possibly chunked document
  static Future<String?> _readSyncChunked(String uid, String token, String key) async {
    try {
      final url = '$_baseUrl/users/$uid/data/$key?key=$_apiKey';
      final resp = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body);
      final fields = data['fields'] as Map<String, dynamic>? ?? {};

      final numChunks = int.tryParse(
          (fields['chunks']?['integerValue'] ?? '1').toString()) ?? 1;

      if (numChunks <= 1 && fields['json']?['stringValue'] != null) {
        return fields['json']['stringValue'] as String;
      } else if (numChunks > 1) {
        final parts = <String>[];
        for (var i = 0; i < numChunks; i++) {
          final chunkUrl = '$_baseUrl/users/$uid/data/${key}_$i?key=$_apiKey';
          final chunkResp = await http.get(Uri.parse(chunkUrl), headers: {'Authorization': 'Bearer $token'});
          if (chunkResp.statusCode == 200) {
            final chunkData = jsonDecode(chunkResp.body);
            final chunkFields = chunkData['fields'] as Map<String, dynamic>? ?? {};
            if (chunkFields['json']?['stringValue'] != null) {
              parts.add(chunkFields['json']['stringValue'] as String);
            }
          }
        }
        return parts.join();
      }
    } catch (e) {
      debugPrint('Error reading sync data $key: $e');
    }
    return null;
  }

  /// Get last sync time (local cache)
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_syncLastSyncKey);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// Get cloud's last sync timestamp from Firestore (to detect if another device synced)
  static Future<DateTime?> getCloudLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(_syncUidKey);
      if (uid == null) return null;

      final token = await _getFreshToken();
      if (token == null) return null;

      final url = '$_baseUrl/users/$uid?key=$_apiKey';
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body);
      final fields = data['fields'] as Map<String, dynamic>? ?? {};
      final lastSyncAt = fields['lastSyncAt']?['timestampValue'];
      if (lastSyncAt != null) {
        return DateTime.tryParse(lastSyncAt.toString());
      }
    } catch (e) {
      debugPrint('getCloudLastSyncTime error: $e');
    }
    return null;
  }

  /// Delete all cloud sync data for the current user
  static Future<void> deleteAllSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_syncUidKey);
    if (uid == null) return;

    final token = await _getFreshToken();
    if (token == null) return;

    final collections = ['items', 'customers', 'bills', 'purchases', 'quotations',
      'expenses', 'creditNotes', 'purchaseReturns', 'suppliers', 'recurringBills',
      'cashBookEntries', 'bankAccounts', 'settings'];

    for (final key in collections) {
      // Delete main doc
      final url = '$_baseUrl/users/$uid/data/$key?key=$_apiKey';
      try {
        await http.delete(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      } catch (_) {}
      // Delete chunks
      for (var i = 0; i < 20; i++) {
        try {
          final chunkUrl = '$_baseUrl/users/$uid/data/${key}_$i?key=$_apiKey';
          await http.delete(Uri.parse(chunkUrl), headers: {'Authorization': 'Bearer $token'});
        } catch (_) {}
      }
    }
    debugPrint('Windows: All cloud data deleted for user $uid');
  }
}
