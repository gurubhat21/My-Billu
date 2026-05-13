import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../models/item.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import '../models/purchase.dart';

const _backupFileName = 'my_billu_backup.json';

class GoogleDriveSync {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  static GoogleSignInAccount? _currentUser;
  static bool get isSignedIn => _currentUser != null;
  static String? get userEmail => _currentUser?.email;
  static String? get userDisplayName => _currentUser?.displayName;
  static String? get userPhotoUrl => _currentUser?.photoUrl;

  /// Sign in to Google
  static Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser != null;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return false;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Check if already signed in (silent)
  static Future<bool> silentSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Get Drive API client
  static Future<drive.DriveApi?> _getDriveApi() async {
    if (_currentUser == null) return null;
    try {
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return null;
      return drive.DriveApi(httpClient);
    } catch (e) {
      debugPrint('Drive API error: $e');
      return null;
    }
  }

  /// Upload backup data to Google Drive
  static Future<bool> uploadBackup({
    required List<Item> items,
    required List<Customer> customers,
    required List<Bill> bills,
    required List<Purchase> purchases,
    required Map<String, String> settings,
  }) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return false;

    try {
      // Build backup JSON
      final backup = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'device': kIsWeb ? 'web' : 'native',
        'items': items.map((i) => i.toMap()).toList(),
        'customers': customers.map((c) => c.toMap()).toList(),
        'bills': bills.map((b) => b.toMap()).toList(),
        'purchases': purchases.map((p) => p.toMap()).toList(),
        'settings': settings,
      };

      final jsonStr = jsonEncode(backup);
      final bytes = utf8.encode(jsonStr);
      final media = drive.Media(Stream.value(bytes), bytes.length);

      // Check if file already exists
      final existingFileId = await _findBackupFileId(driveApi);

      if (existingFileId != null) {
        // Update existing file
        await driveApi.files.update(
          drive.File()..name = _backupFileName,
          existingFileId,
          uploadMedia: media,
        );
      } else {
        // Create new file in appDataFolder
        final driveFile = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media);
      }
      return true;
    } catch (e) {
      debugPrint('Upload backup error: $e');
      return false;
    }
  }

  /// Download backup data from Google Drive
  static Future<Map<String, dynamic>?> downloadBackup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return null;

    try {
      final fileId = await _findBackupFileId(driveApi);
      if (fileId == null) return null;

      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }

      final jsonStr = utf8.decode(bytes);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Download backup error: $e');
      return null;
    }
  }

  /// Get last backup timestamp from Drive
  static Future<DateTime?> getLastBackupTime() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return null;

    try {
      final fileId = await _findBackupFileId(driveApi);
      if (fileId == null) return null;

      final file = await driveApi.files.get(fileId, $fields: 'modifiedTime') as drive.File;
      return file.modifiedTime;
    } catch (_) {
      return null;
    }
  }

  /// Find the backup file ID in appDataFolder
  static Future<String?> _findBackupFileId(drive.DriveApi driveApi) async {
    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(id, name)',
      );
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
    } catch (e) {
      debugPrint('Find backup file error: $e');
    }
    return null;
  }
}


