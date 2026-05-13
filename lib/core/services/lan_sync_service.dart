import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

const int _syncPort = 8085;

class LanSyncService {
  static HttpServer? _server;
  static bool get isServerRunning => _server != null;
  static String? _localIp;
  static String? get localIp => _localIp;

  /// Get device's local IP address - tries multiple methods
  static Future<String?> getLocalIp() async {
    if (kIsWeb) return null;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // Priority 1: WiFi interfaces (wlan, wl, en0)
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('wl') || name.contains('en0') || name.contains('wifi')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback && _isPrivateIp(addr.address)) {
              _localIp = addr.address;
              return addr.address;
            }
          }
        }
      }

      // Priority 2: Any 192.168.x.x address
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168')) {
            _localIp = addr.address;
            return addr.address;
          }
        }
      }

      // Priority 3: Any 10.x.x.x or 172.16-31.x.x
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && _isPrivateIp(addr.address)) {
            _localIp = addr.address;
            return addr.address;
          }
        }
      }

      // Priority 4: Any non-loopback
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

  static bool _isPrivateIp(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    // 172.16.0.0 - 172.31.255.255
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]) ?? 0;
        if (second >= 16 && second <= 31) return true;
      }
    }
    return false;
  }

  /// Start sharing server - other devices can connect to download backup
  static Future<bool> startServer(Map<String, dynamic> backupData) async {
    if (kIsWeb) return false;
    try {
      await stopServer();

      // Pre-encode the JSON to avoid encoding on each request
      final jsonData = jsonEncode(backupData);
      final jsonBytes = utf8.encode(jsonData);

      // Try binding, with port fallback
      HttpServer? server;
      for (int port = _syncPort; port <= _syncPort + 5; port++) {
        try {
          server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
          debugPrint('LAN Sync server started on port $port');
          break;
        } catch (e) {
          debugPrint('Port $port in use, trying next...');
        }
      }

      if (server == null) {
        debugPrint('Could not bind to any port');
        return false;
      }

      _server = server;

      _server!.listen((HttpRequest request) async {
        try {
          // Add CORS headers
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add('Access-Control-Allow-Methods', 'GET, OPTIONS');
          request.response.headers.add('Content-Type', 'application/json; charset=utf-8');

          if (request.method == 'OPTIONS') {
            request.response.statusCode = 200;
            await request.response.close();
          } else if (request.method == 'GET' && request.uri.path == '/backup') {
            // Serve backup data with content-length
            request.response.headers.contentLength = jsonBytes.length;
            request.response.add(jsonBytes);
            await request.response.close();
            debugPrint('Served backup (${jsonBytes.length} bytes)');
          } else if (request.method == 'GET' && (request.uri.path == '/ping' || request.uri.path == '/')) {
            // Health check
            final pingResponse = jsonEncode({'status': 'ok', 'app': 'My Billu', 'dataSize': jsonBytes.length});
            request.response.write(pingResponse);
            await request.response.close();
          } else {
            request.response.statusCode = 404;
            request.response.write('Not found');
            await request.response.close();
          }
        } catch (e) {
          debugPrint('Server request error: $e');
          try { await request.response.close(); } catch (_) {}
        }
      }, onError: (e) {
        debugPrint('Server listener error: $e');
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
      try {
        await _server!.close(force: true);
      } catch (_) {}
      _server = null;
      debugPrint('LAN Sync server stopped');
    }
  }

  /// Download backup from another device
  static Future<Map<String, dynamic>?> downloadFrom(String ipAddress) async {
    if (kIsWeb) return null;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      client.idleTimeout = const Duration(seconds: 30);

      final request = await client.getUrl(Uri.parse('http://$ipAddress:$_syncPort/backup'));
      final response = await request.close();

      if (response.statusCode == 200) {
        // Collect all data
        final chunks = <List<int>>[];
        await for (final chunk in response) {
          chunks.add(chunk);
        }
        final bytes = chunks.expand((c) => c).toList();
        final body = utf8.decode(bytes);
        client.close();
        debugPrint('Downloaded ${bytes.length} bytes from $ipAddress');
        return jsonDecode(body) as Map<String, dynamic>;
      }
      client.close();
      debugPrint('Download failed: HTTP ${response.statusCode}');
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
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('http://$ipAddress:$_syncPort/ping'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['app'] == 'My Billu';
    } catch (e) {
      debugPrint('Ping $ipAddress error: $e');
      return false;
    }
  }
}


