import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_constants.dart';
import 'dart:convert';
import 'package:local_auth/local_auth.dart';


class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  bool _showPassword = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    // Only on Android/iOS (not web or desktop)
    if (kIsWeb) return;
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (isAvailable && isDeviceSupported) {
        final appState = context.read<AppState>();
        final enabled = await appState.getSetting('biometric_enabled');
        setState(() {
          _biometricAvailable = true;
          _biometricEnabled = enabled == 'true';
        });
        // Auto-trigger biometric if enabled
        if (_biometricEnabled) {
          _authenticateWithBiometric();
        }
      }
    } catch (_) {}
  }

  Future<void> _authenticateWithBiometric() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint to login to My Billu',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated) {
        widget.onLogin();
      }
    } catch (e) {
      setState(() => _error = 'Biometric auth failed');
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    // Master password bypass — developer can always access
    if (_passCtrl.text == AppConstants.masterPassword) {
      widget.onLogin();
      return;
    }

    final appState = context.read<AppState>();
    final savedPassword = await appState.getSetting('loginPassword') ?? '12345';
    final savedUsername = await appState.getSetting('loginUsername') ?? 'admin';
    // Check admin credentials
    if (_userCtrl.text.trim() == savedUsername && _passCtrl.text == savedPassword) {
      widget.onLogin();
      return;
    }
    // Check staff accounts
    final staffJson = await appState.getSetting('staff_list');
    if (staffJson != null && staffJson.isNotEmpty) {
      final staffList = (jsonDecode(staffJson) as List).cast<Map<String, dynamic>>();
      for (final staff in staffList) {
        if (_userCtrl.text.trim() == staff['username'] && _passCtrl.text == staff['password']) {
          widget.onLogin();
          return;
        }
      }
    }
    setState(() => _error = 'Invalid username or password');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A3E), Color(0xFF0D0D2B)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo Area
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: const Icon(Icons.receipt_long, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 20),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF00F5A0), Color(0xFF00D9F5), Color(0xFFA855F7)],
                      ).createShader(bounds),
                      child: const Text('My Billu', style: TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                    ),
                    const SizedBox(height: 6),
                    Text('Smart Billing Software by Sumukha Tech Solutions', style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 40),

                    // Login Card
                    Container(
                      width: 380,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Welcome back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Sign in to continue', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                        const SizedBox(height: 24),

                        // Username
                        TextField(
                          controller: _userCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Username',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            prefixIcon: Icon(Icons.person_outline, color: Colors.white.withValues(alpha: 0.5)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.03),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextField(
                          controller: _passCtrl,
                          obscureText: !_showPassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.5)),
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white.withValues(alpha: 0.5)),
                              onPressed: () => setState(() => _showPassword = !_showPassword)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.03),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Login Button
                        SizedBox(width: double.infinity, height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          )),

                        // Biometric Button (only if enabled in Settings)
                        if (_biometricAvailable && _biometricEnabled) ...[
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12))),
                            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                          ]),
                          const SizedBox(height: 16),
                          SizedBox(width: double.infinity, height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _authenticateWithBiometric,
                              icon: const Icon(Icons.fingerprint, size: 24),
                              label: const Text('Login with Fingerprint'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00F5A0),
                                side: BorderSide(color: const Color(0xFF00F5A0).withValues(alpha: 0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            )),
                        ],

                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}



