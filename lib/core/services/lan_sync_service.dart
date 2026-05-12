import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

const int _syncPort = 8085;

class LanSyncService {
  static HttpServer? _server;
  static bool get isServerRunning => _server != null;
  static String? _localIp;
  static String? get localIp => _localIp;

  /// Get device's local IP address
  static Future<String?> getLocalIp() async {
    if (kIsWeb) return null;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168')) {
            _localIp = addr.address;
            return addr.address;
          }
        }
      }
      // Fallback: try any non-loopback address
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            _localIp = addr.address;
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Get IP error: $e');
    }
    return null;
  }

  /// Start sharing server - other devices can connect to download backup
  static Future<bool> startServer(Map<String, dynamic> backupData) async {
    if (kIsWeb) return false;
    try {
      await stopServer();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _syncPort);
      debugPrint('LAN Sync server started on port $_syncPort');

      _server!.listen((HttpRequest request) async {
        // Add CORS headers
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add('Content-Type', 'application/json');

        if (request.method == 'GET' && request.uri.path == '/backup') {
          // Serve backup data
          request.response.write(jsonEncode(backupData));
          await request.response.close();
        } else if (request.method == 'GET' && request.uri.path == '/ping') {
          // Health check
          request.response.write(jsonEncode({'status': 'ok', 'app': 'My Billu'}));
          await request.response.close();
        } else {
          request.response.statusCode = 404;
          request.response.write('Not found');
          await request.response.close();
        }
      });
      return true;
    } catch (e) {
      debugPrint('Start server error: $e');
      return false;
    }
  }

  /// Stop the sharing server
  static Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      debugPrint('LAN Sync server stopped');
    }
  }

  /// Download backup from another device
  static Future<Map<String, dynamic>?> downloadFrom(String ipAddress) async {
    if (kIsWeb) return null;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('http://$ipAddress:$_syncPort/backup'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        client.close();
        return jsonDecode(body) as Map<String, dynamic>;
      }
      client.close();
      return null;
    } catch (e) {
      debugPrint('Download from $ipAddress error: $e');
      return null;
    }
  }

  /// Ping another device to check if it's sharing
  static Future<bool> ping(String ipAddress) async {
    if (kIsWeb) return false;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(Uri.parse('http://$ipAddress:$_syncPort/ping'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['app'] == 'My Billu';
    } catch (_) {
      return false;
    }
  }
}
