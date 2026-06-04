import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service to generate, persist, and retrieve a unique device ID + device info
class DeviceIdService {
  static final DeviceIdService _instance = DeviceIdService._();
  factory DeviceIdService() => _instance;
  DeviceIdService._();

  static const _deviceIdKey = 'billu_device_id';
  static const _deviceNameKey = 'billu_device_name';
  static const _deviceModelKey = 'billu_device_model';

  String? _deviceId;
  String? _deviceName;
  String? _deviceModel;

  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  String? get deviceModel => _deviceModel;

  String get platform {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    return 'unknown';
  }

  /// Initialize device ID — call once during app startup
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey);
    _deviceName = prefs.getString(_deviceNameKey);
    _deviceModel = prefs.getString(_deviceModelKey);

    if (_deviceId == null) {
      await _generateAndPersist(prefs);
    }
  }

  Future<void> _generateAndPersist(SharedPreferences prefs) async {
    final deviceInfo = DeviceInfoPlugin();

    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      _deviceId = 'web_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
      _deviceName = webInfo.browserName.name;
      _deviceModel = webInfo.userAgent ?? 'Web Browser';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      // Use Android ID (survives app reinstall, unique per device+user)
      _deviceId = 'and_${androidInfo.id}_${androidInfo.serialNumber}';
      _deviceName = '${androidInfo.brand} ${androidInfo.model}';
      _deviceModel = androidInfo.model;
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      _deviceId = 'win_${windowsInfo.deviceId.replaceAll(RegExp(r'[{}]'), '')}';
      _deviceName = windowsInfo.computerName;
      _deviceModel = windowsInfo.productName;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceId = 'ios_${iosInfo.identifierForVendor ?? const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
      _deviceName = iosInfo.name;
      _deviceModel = iosInfo.model;
    } else {
      // Fallback
      _deviceId = 'unk_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
      _deviceName = 'Unknown Device';
      _deviceModel = 'Unknown';
    }

    // Persist
    await prefs.setString(_deviceIdKey, _deviceId!);
    await prefs.setString(_deviceNameKey, _deviceName ?? 'Unknown');
    await prefs.setString(_deviceModelKey, _deviceModel ?? 'Unknown');
  }

  /// Get all device info as a map (for Firestore) — legacy fields
  Map<String, String> toMap() => {
    'deviceId': _deviceId ?? 'unknown',
    'deviceName': _deviceName ?? 'Unknown',
    'deviceModel': _deviceModel ?? 'Unknown',
    'platform': platform,
  };

  /// Get platform-specific device info map (e.g. androidDeviceId, windowsDeviceName)
  Map<String, String> toPlatformMap() {
    final prefix = platform; // 'android', 'windows', etc.
    return {
      '${prefix}DeviceId': _deviceId ?? 'unknown',
      '${prefix}DeviceName': _deviceName ?? 'Unknown',
      '${prefix}DeviceModel': _deviceModel ?? 'Unknown',
      'platform': platform,
    };
  }

  /// Get both legacy + platform-specific fields (for backward compatibility)
  Map<String, String> toBackwardCompatMap() => {
    ...toMap(),
    ...toPlatformMap(),
  };
}
