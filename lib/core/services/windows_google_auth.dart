import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Handles Google OAuth on Windows via browser + local HTTP server.
/// Flow: Open browser → User signs in → Redirect to localhost → Get auth code → Exchange for tokens
class WindowsGoogleAuth {
  static const String _webClientId =
      '348057118012-dpdk6o8smrjg15k1vl3h0hfc21qiq7dj.apps.googleusercontent.com';

  /// Sign in with Google via browser-based OAuth.
  /// Returns a map with 'idToken' and 'accessToken', or null if cancelled.
  static Future<Map<String, String>?> signIn() async {
    HttpServer? server;
    try {
      // Try binding to a local port (try multiple in case one is busy)
      const ports = [43210, 43211, 43212];
      for (final tryPort in ports) {
        try {
          server = await HttpServer.bind(InternetAddress.loopbackIPv4, tryPort);
          break;
        } catch (_) {
          debugPrint('Port $tryPort busy, trying next...');
        }
      }
      if (server == null) {
        debugPrint('All ports busy, cannot start OAuth server');
        return null;
      }
      final port = server.port;
      final redirectUri = 'http://localhost:$port';

      // Generate state for CSRF protection
      final state = _generateRandomString(32);

      // Build Google OAuth URL — use implicit flow (token only, no id_token)
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _webClientId,
        'redirect_uri': redirectUri,
        'response_type': 'token',
        'scope': 'openid email profile',
        'state': state,
        'include_granted_scopes': 'true',
      });

      // Open browser
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open browser for Google Sign-In');
      }

      // Wait for the redirect
      final completer = Completer<Map<String, String>?>();

      // Timeout after 5 minutes
      final timer = Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted) {
          completer.complete(null);
          server?.close(force: true);
        }
      });

      server.listen((HttpRequest request) async {
        final requestUri = request.uri;

        if (requestUri.path == '/') {
          // Check if we have email from the JS userinfo fetch
          final email = requestUri.queryParameters['email'];
          final name = requestUri.queryParameters['name'];
          final returnedState = requestUri.queryParameters['state'];

          if (email != null && email.isNotEmpty) {
            // Verify state
            if (returnedState != state) {
              request.response
                ..statusCode = 403
                ..headers.contentType = ContentType.html
                ..write(_errorHtml('Security error: state mismatch'))
                ..close();
              return;
            }

            // Send success response to browser
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.html
              ..write(_successHtml())
              ..close();

            if (!completer.isCompleted) {
              completer.complete({
                'email': email,
                'displayName': name ?? '',
              });
            }
          } else {
            // First request — serve HTML that extracts token and fetches user info
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.html
              ..write(_extractorHtml(state))
              ..close();
          }
        } else if (requestUri.path == '/cancel') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(_errorHtml('Sign-in cancelled'))
            ..close();
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        } else {
          request.response
            ..statusCode = 404
            ..close();
        }
      });

      final result = await completer.future;
      timer.cancel();
      return result;
    } catch (e) {
      debugPrint('Windows Google Auth error: $e');
      return null;
    } finally {
      server?.close(force: true);
    }
  }

  /// Sign in and return just the email + display name.
  /// Now directly returns from the OAuth flow (no JWT decoding needed).
  static Future<Map<String, String>?> signInAndGetEmail() async {
    return await signIn();
  }

  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// HTML page that extracts access_token, fetches email via Google API, sends to server
  static String _extractorHtml(String expectedState) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <title>My Billu - Sign In</title>
  <style>
    body {
      font-family: 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #0A0E1A 0%, #1A1040 50%, #0A0E1A 100%);
      color: white;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
    }
    .card {
      background: rgba(255,255,255,0.05);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 20px;
      padding: 40px;
      text-align: center;
      max-width: 400px;
      backdrop-filter: blur(10px);
    }
    .spinner {
      width: 40px; height: 40px;
      border: 3px solid rgba(124,77,255,0.3);
      border-top: 3px solid #7C4DFF;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 0 auto 20px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    h2 { color: #7C4DFF; margin: 0 0 10px; }
    p { color: rgba(255,255,255,0.6); font-size: 14px; }
    .error { color: #F44336; }
  </style>
</head>
<body>
  <div class="card">
    <div class="spinner" id="spinner"></div>
    <h2 id="title">Signing you in...</h2>
    <p id="message">Processing authentication, please wait.</p>
  </div>
  <script>
    (function() {
      function showError(msg) {
        document.getElementById('title').innerText = 'Error';
        document.getElementById('message').innerText = msg;
        document.getElementById('message').className = 'error';
        document.getElementById('spinner').style.display = 'none';
      }
      try {
        var hash = window.location.hash.substring(1);
        if (!hash) { showError('No authentication data received.'); return; }

        var params = new URLSearchParams(hash);
        var accessToken = params.get('access_token');
        var state = params.get('state');

        if (!accessToken) {
          var error = params.get('error') || 'No access token received';
          showError(error);
          return;
        }

        document.getElementById('message').innerText = 'Getting your account info...';

        // Fetch email from Google userinfo API
        fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
          headers: { 'Authorization': 'Bearer ' + accessToken }
        })
        .then(function(resp) { return resp.json(); })
        .then(function(info) {
          if (info.email) {
            // Redirect to our server with email + name (short URL!)
            window.location.href = '/?email=' + encodeURIComponent(info.email)
              + '&name=' + encodeURIComponent(info.name || '')
              + '&state=' + encodeURIComponent(state || '');
          } else {
            showError('Could not get email from Google account.');
          }
        })
        .catch(function(err) {
          showError('Failed to fetch account info: ' + err.message);
        });
      } catch(e) {
        showError(e.message);
      }
    })();
  </script>
</body>
</html>
''';
  }

  static String _successHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <title>My Billu - Signed In</title>
  <style>
    body {
      font-family: 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #0A0E1A 0%, #1A1040 50%, #0A0E1A 100%);
      color: white;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
    }
    .card {
      background: rgba(255,255,255,0.05);
      border: 1px solid rgba(76,175,80,0.3);
      border-radius: 20px;
      padding: 40px;
      text-align: center;
      max-width: 400px;
    }
    .check { font-size: 60px; margin-bottom: 16px; }
    h2 { color: #4CAF50; margin: 0 0 10px; }
    p { color: rgba(255,255,255,0.6); font-size: 14px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="check">✅</div>
    <h2>Signed In Successfully!</h2>
    <p>You can close this tab and return to My Billu.</p>
  </div>
  <script>setTimeout(function(){ window.close(); }, 3000);</script>
</body>
</html>
''';
  }

  static String _errorHtml(String message) {
    return '''
<!DOCTYPE html>
<html>
<head><title>My Billu - Error</title>
<style>
  body { font-family: 'Segoe UI', sans-serif; background: #0A0E1A; color: white;
    display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
  .card { background: rgba(255,255,255,0.05); border: 1px solid rgba(244,67,54,0.3);
    border-radius: 20px; padding: 40px; text-align: center; max-width: 400px; }
  h2 { color: #F44336; }
  p { color: rgba(255,255,255,0.6); }
</style></head>
<body><div class="card"><h2>❌ Error</h2><p>$message</p></div></body>
</html>
''';
  }
}
