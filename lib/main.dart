import 'dart:io' show exit, Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_state.dart';
import 'core/database/database_helper.dart';
import 'core/database/data_path_native.dart' if (dart.library.js_interop) 'core/database/data_path_web.dart'
    as data_path;
import 'core/utils/app_constants.dart';
import 'core/models/bill.dart';
import 'features/login/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/billing/billing_screen.dart';
import 'features/items/items_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/purchase/purchase_screen.dart';
import 'features/stock/stock_screen.dart';
import 'features/history/history_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/quotation/quotation_screen.dart';
import 'features/expenses/expense_screen.dart';
import 'features/credit_notes/credit_note_screen.dart';
import 'features/purchase_returns/purchase_return_screen.dart';
import 'features/customer_ledger/customer_ledger_screen.dart';
import 'features/suppliers/supplier_screen.dart';
import 'features/recurring/recurring_bill_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/audit/audit_trail_screen.dart';
import 'features/cash_book/cash_book_screen.dart';
import 'features/settings/keyboard_shortcuts_screen.dart';
import 'features/serial_tracker/serial_tracker_screen.dart';
import 'features/supplier_payments/supplier_payment_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'features/fake_quote/fake_quote_screen.dart';
import 'features/qr_generator/qr_generator_screen.dart';
import 'core/services/device_id_service.dart';
import 'core/services/subscription_service.dart';
import 'core/services/windows_firestore_service.dart';
import 'core/services/windows_google_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for Windows/Linux desktop only
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Load saved data path for Windows
    await data_path.loadDataPathConfig();
  }

  // Initialize Firebase (skip on Windows — C++ SDK crashes, use REST API instead)
  if (!(!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)) {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }
  }

  // Initialize Device ID service
  try {
    await DeviceIdService().init();
  } catch (e) {
    debugPrint('DeviceId init error: $e');
  }
  // Override default error widget to prevent grey/red screens
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Something went wrong',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13))),
          ]),
          const SizedBox(height: 4),
          Text(details.exceptionAsString(),
            style: const TextStyle(color: Colors.grey, fontSize: 10),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  };

  // Load saved theme before running app
  await MyBilluApp.loadSavedTheme();

  runApp(const MyBilluApp());
}

class MyBilluApp extends StatelessWidget {
  const MyBilluApp({super.key});

  static final ValueNotifier<String> themeNotifier = ValueNotifier('default_purple');

  static Future<void> loadSavedTheme() async {
    try {
      final db = DatabaseHelper.instance;
      final settings = await db.getAllSettings();
      final saved = settings['app_theme'] ?? 'default_purple';
      themeNotifier.value = saved;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..loadAll(),
      child: ValueListenableBuilder<String>(
        valueListenable: themeNotifier,
        builder: (_, themeId, __) {
          final palette = AppTheme.getPalette(themeId);
          final theme = AppTheme.buildTheme(palette);
          return MaterialApp(
            title: 'My Billu',
            debugShowCheckedModeBanner: false,
            theme: theme,
            darkTheme: theme,
            themeMode: ThemeMode.dark, // Always use our custom theme
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

/// Gate that shows Gmail Registration → Subscription Check → Onboarding → Login → MainShell
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loggedIn = false;
  bool? _onboardingDone; // null = loading, true/false = checked
  bool _expired = false;
  String _expiryDateStr = '';
  int _trialDaysLeft = -1; // -1 = not trial, 0+ = days remaining

  // Subscription state
  bool _subChecking = true;
  bool _needsGmailRegistration = false;
  SubscriptionResult? _subResult;
  bool _signingIn = false;
  final _windowsEmailController = TextEditingController();
  String? _windowsEmailError;

  final _subService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    setState(() => _subChecking = true);

    // Skip subscription check on web
    if (kIsWeb) {
      setState(() {
        _subChecking = false;
        _needsGmailRegistration = false;
      });
      _checkOnboarding();
      return;
    }

    // Windows: Google login required only on first launch (no cached email)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final prefs = await SharedPreferences.getInstance();
      final cachedEmail = prefs.getString('sub_registered_email');
      if (cachedEmail == null || cachedEmail.isEmpty) {
        setState(() { _subChecking = false; _needsGmailRegistration = true; });
      } else {
        setState(() { _subChecking = false; _needsGmailRegistration = false; });
        _checkOnboarding();
        _windowsBackgroundCheck(cachedEmail);
      }
      return;
    }

    try {
      final cachedEmail = await _subService.getCachedEmail();

      if (cachedEmail == null || cachedEmail.isEmpty) {
        // Not registered yet — show Gmail sign-in (this blocks)
        setState(() {
          _subChecking = false;
          _needsGmailRegistration = true;
        });
        return;
      }

      // Returning user — let them in immediately, check in background
      setState(() {
        _subChecking = false;
        _needsGmailRegistration = false;
      });
      _checkOnboarding();

      // Background subscription check (non-blocking)
      _backgroundSubscriptionCheck(cachedEmail);
    } catch (e) {
      debugPrint('Subscription check error: $e');
      // On any error, let user into the app
      setState(() {
        _subChecking = false;
        _needsGmailRegistration = false;
      });
      _checkOnboarding();
    }
  }

  /// Open WhatsApp with pre-filled customer details
  Future<void> _openWhatsApp() async {
    final deviceService = DeviceIdService();
    String customerName = '';
    String email = '';

    // Get cached details
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      email = (await WindowsFirestoreService.getCachedEmail()) ?? '';
    } else {
      email = (await _subService.getCachedEmail()) ?? '';
    }

    try {
      final appState = context.read<AppState>();
      customerName = (await appState.getSetting('businessName')) ?? '';
    } catch (_) {}

    final message = 'Hi Guruprasad, I want to buy this billing software.\n\n'
        'Customer Name: ${customerName.isNotEmpty ? customerName : "N/A"}\n'
        'Gmail Address: ${email.isNotEmpty ? email : "N/A"}\n'
        'Device ID: ${deviceService.deviceId ?? "N/A"}';

    final uri = Uri.parse('https://wa.me/919449831316?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Checks subscription in background without blocking the app.
  /// If revoked/expired, shows appropriate screen.
  Future<void> _backgroundSubscriptionCheck(String email) async {
    try {
      final result = await _subService.checkSubscription(email);
      if (!mounted) return;
      _subResult = result;

      switch (result.status) {
        case SubscriptionStatus.active:
        case SubscriptionStatus.trial:
        case SubscriptionStatus.grace:
          // Good — update trial info silently
          _expiryDateStr = result.expiryDate?.toIso8601String().split('T').first ?? '';
          if (result.daysLeft != null && result.daysLeft! <= 7) {
            setState(() => _trialDaysLeft = result.daysLeft!);
          }
          break;

        case SubscriptionStatus.expired:
          _expiryDateStr = result.expiryDate?.toIso8601String().split('T').first ?? '';
          setState(() => _expired = true);
          break;

        case SubscriptionStatus.revoked:
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Row(children: [
                  Icon(Icons.block, color: AppColors.error),
                  SizedBox(width: 8),
                  Expanded(child: Text('Access Revoked')),
                ]),
                content: const Text(
                  'Your access has been revoked by admin. Contact support.',
                  style: TextStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      SystemNavigator.pop();
                      exit(0);
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          break;

        case SubscriptionStatus.deviceMismatch:
          setState(() => _expired = true);
          break;

        case SubscriptionStatus.unregistered:
          setState(() => _needsGmailRegistration = true);
          break;

        case SubscriptionStatus.error:
          // Network error — already inside app, do nothing (offline mode)
          break;
      }
    } catch (e) {
      // Offline or error — do nothing, let user continue
      debugPrint('Background subscription check failed: $e');
    }
  }

  Future<void> _signInWithGmail() async {
    setState(() => _signingIn = true);
    try {
      User? user;
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        final result = await FirebaseAuth.instance.signInWithPopup(provider);
        user = result.user;
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        // Windows: browser-based OAuth
        final tokens = await WindowsGoogleAuth.signIn();
        if (tokens == null) {
          setState(() => _signingIn = false);
          return;
        }
        final credential = GoogleAuthProvider.credential(
          accessToken: tokens['accessToken'],
          idToken: tokens['idToken'],
        );
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        user = userCredential.user;
      } else {
        // Android/iOS: native Google Sign-In
        final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
        if (googleUser == null) {
          setState(() => _signingIn = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        user = userCredential.user;
      }

      if (user == null || user.email == null) {
        setState(() => _signingIn = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to get email from Google'),
            backgroundColor: AppColors.error));
        }
        return;
      }

      // Register device with this email
      final result = await _subService.registerDevice(
        user.email!,
        user.displayName ?? user.email!,
      );

      if (result.status == SubscriptionStatus.deviceMismatch) {
        setState(() => _signingIn = false);
        if (mounted) {
          showDialog(context: context, builder: (ctx) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.warning, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(child: Text('Device Already Registered')),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('This Gmail (${user!.email}) is already linked to another device.',
                style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Column(children: [
                  Text('Contact admin for device migration:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.phone, size: 16, color: Color(0xFF25D366)),
                    SizedBox(width: 8),
                    Text('9449831316 - Guruprasad Bhat',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF25D366))),
                  ]),
                ]),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ));
        }
        return;
      }

      if (result.status == SubscriptionStatus.error) {
        setState(() => _signingIn = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Registration failed: ${result.message}'),
            backgroundColor: AppColors.error));
        }
        return;
      }

      // Success — re-check subscription
      setState(() => _signingIn = false);
      _checkSubscription();
    } catch (e) {
      setState(() => _signingIn = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sign-in error: $e'),
          backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _checkOnboarding() async {
    final appState = context.read<AppState>();
    final result = await appState.getSetting('onboarding_complete');
    setState(() => _onboardingDone = result == 'true');
  }

  void _onExpiryExtended() {
    setState(() {
      _expired = false;
      _trialDaysLeft = -1;
    });
    _checkSubscription();
  }

  void _showTrialPopup() {
    if (_trialDaysLeft < 0 || !mounted) return;
    // Show after a small delay so the main screen renders first
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle),
            child: const Icon(Icons.timer, color: AppColors.warning, size: 28)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Trial Period', style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.warning.withValues(alpha: 0.1),
                AppColors.error.withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
            child: Column(children: [
              Text('$_trialDaysLeft', style: const TextStyle(
                fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.warning)),
              Text(_trialDaysLeft == 1 ? 'Day Remaining' : 'Days Remaining',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7))),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Your trial expires on $_expiryDateStr.\nContact us to purchase a full license.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.phone, size: 16, color: Color(0xFF25D366)),
              const SizedBox(width: 8),
              const Text('9449831316 - Guruprasad Bhat',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF25D366))),
            ]),
          ),
          const SizedBox(height: 16),
          // WhatsApp Contact button
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              _openWhatsApp();
            },
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('Contact Us on WhatsApp'),
          )),
        ]),
        actions: [
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
        ],
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Loading / checking subscription
    if (_subChecking) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
            ),
          ),
          child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Checking subscription...', style: TextStyle(color: Colors.white54)),
          ])),
        ),
      );
    }

    // Gmail registration screen
    if (_needsGmailRegistration) {
      return _buildGmailRegistrationScreen();
    }

    // Expired / Revoked / Device Mismatch
    if (_expired) {
      return ExpiredScreen(
        expiryDate: _expiryDateStr,
        subResult: _subResult,
        onExtended: _onExpiryExtended,
      );
    }

    // Loading onboarding check
    if (_onboardingDone == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Show onboarding for first-time users
    if (!_onboardingDone!) {
      return OnboardingScreen(onComplete: () => setState(() => _onboardingDone = true));
    }
    // Show login
    if (!_loggedIn) {
      return LoginScreen(onLogin: () {
        setState(() => _loggedIn = true);
        _showTrialPopup();
      });
    }
    return MainShell(onLogout: () => setState(() => _loggedIn = false));
  }

  /// Windows: Sign in with Google via browser OAuth, then register via REST API
  Future<void> _signInWithGoogleWindows() async {
    setState(() { _signingIn = true; _windowsEmailError = null; });
    try {
      final userInfo = await WindowsGoogleAuth.signInAndGetEmail();
      if (userInfo == null) {
        setState(() { _signingIn = false; _windowsEmailError = 'Sign-in was cancelled or failed'; });
        return;
      }

      final email = userInfo['email']!.toLowerCase();
      final displayName = userInfo['displayName'] ?? email.split('@').first;

      final result = await WindowsFirestoreService.registerDevice(email, displayName);
      if (result['status'] == 'deviceMismatch') {
        setState(() => _signingIn = false);
        if (mounted) {
          showDialog(context: context, builder: (ctx) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.devices_other, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(child: Text('Device Mismatch')),
            ]),
            content: Text(result['message'] ?? 'This email is registered to another device.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ));
        }
        return;
      }
      if (result['status'] == 'error') {
        setState(() { _signingIn = false; _windowsEmailError = result['message'] ?? 'Failed'; });
        return;
      }
      setState(() { _signingIn = false; _needsGmailRegistration = false; });
      _checkOnboarding();
      // Run background subscription check
      final cachedEmail = await WindowsFirestoreService.getCachedEmail();
      if (cachedEmail != null) _windowsBackgroundCheck(cachedEmail);
    } catch (e) {
      setState(() { _signingIn = false; _windowsEmailError = 'Sign-in failed: $e'; });
    }
  }

  /// Windows fallback: register with typed email via REST API
  Future<void> _signInWithEmailWindows() async {
    final email = _windowsEmailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _windowsEmailError = 'Enter a valid Gmail address');
      return;
    }
    setState(() { _signingIn = true; _windowsEmailError = null; });
    try {
      final result = await WindowsFirestoreService.registerDevice(email, email.split('@').first);
      if (result['status'] == 'deviceMismatch') {
        setState(() => _signingIn = false);
        if (mounted) {
          showDialog(context: context, builder: (ctx) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.devices_other, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(child: Text('Device Mismatch')),
            ]),
            content: Text(result['message'] ?? 'This email is registered to another device.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ));
        }
        return;
      }
      if (result['status'] == 'error') {
        setState(() { _signingIn = false; _windowsEmailError = result['message'] ?? 'Failed'; });
        return;
      }
      setState(() { _signingIn = false; _needsGmailRegistration = false; });
      _checkOnboarding();
      // Run background subscription check
      _windowsBackgroundCheck(email);
    } catch (e) {
      setState(() { _signingIn = false; _windowsEmailError = 'Registration failed. Check internet.'; });
    }
  }

  /// Windows background subscription check via REST API
  Future<void> _windowsBackgroundCheck(String email) async {
    try {
      final result = await WindowsFirestoreService.checkSubscription(email);
      if (!mounted) return;
      final status = result['status'] ?? '';

      switch (status) {
        case 'active':
        case 'trial':
          // Update trial/expiry info
          final expiryStr = result['expiryDate'] ?? '';
          final daysLeft = result['daysLeft'] ?? 999;
          _expiryDateStr = expiryStr;
          if (daysLeft <= 7) {
            setState(() => _trialDaysLeft = daysLeft);
          }
          break;

        case 'expired':
          _expiryDateStr = result['expiryDate'] ?? '';
          setState(() => _expired = true);
          break;

        case 'revoked':
          await showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.block, color: AppColors.error), SizedBox(width: 8),
              Expanded(child: Text('Access Revoked')),
            ]),
            content: const Text('Your access has been revoked by admin.'),
            actions: [
              TextButton(onPressed: () { Navigator.pop(ctx); SystemNavigator.pop(); exit(0); }, child: const Text('OK')),
            ],
          ));
          break;

        case 'unregistered':
          // Admin deleted subscription — just show expired, don't clear login
          setState(() => _expired = true);
          break;

        case 'deviceMismatch':
          setState(() => _expired = true);
          break;
      }
    } catch (e) {
      debugPrint('Windows background check error: $e');
    }
  }

  Widget _buildGmailRegistrationScreen() {
    final deviceService = DeviceIdService();
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
            width: 420, padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.app_registration, size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text('Welcome to My Billu', style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const SizedBox(height: 8),
              Text('Register your device to get started',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
              const SizedBox(height: 32),

              if (isWindows) ...[
                // Google Sign-In button for Windows (browser-based OAuth)
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: _signingIn ? null : _signInWithGoogleWindows,
                  icon: _signingIn
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.mail, color: Colors.red, size: 22),
                  label: Text(_signingIn ? 'Signing in...' : 'Sign in with Google',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                )),

                // Error message
                if (_windowsEmailError != null) ...[
                  const SizedBox(height: 12),
                  Text(_windowsEmailError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],

                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12))),
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                ]),
                const SizedBox(height: 16),

                // Manual email fallback
                TextField(
                  controller: _windowsEmailController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter Gmail manually',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
                    prefixIcon: Icon(Icons.mail_outline, color: Colors.white.withValues(alpha: 0.3), size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.03),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5))),
                  ),
                  onSubmitted: (_) => _signInWithEmailWindows(),
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: TextButton(
                  onPressed: _signingIn ? null : _signInWithEmailWindows,
                  child: Text('Register with email',
                    style: TextStyle(color: AppColors.primary.withValues(alpha: 0.7), fontSize: 13)),
                )),
              ] else ...[
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: _signingIn ? null : _signInWithGmail,
                  icon: _signingIn
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.mail, color: Colors.red, size: 22),
                  label: Text(_signingIn ? 'Signing in...' : 'Sign in with Gmail',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                )),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(children: [
                  Row(children: [
                    Icon(isWindows ? Icons.computer : Icons.phone_android, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      'Device: ${deviceService.deviceName ?? "Unknown"}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.fingerprint, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      'ID: ${deviceService.deviceId ?? "Generating..."}',
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3)))),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              Text(isWindows ? 'Use the same Gmail as your Android device' : 'One Gmail = One Device',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
              Text('7-day free trial included',
                style: TextStyle(fontSize: 11, color: AppColors.success.withValues(alpha: 0.6))),
            ]),
          ),
          ),
        ),
      ),
    );
  }
}

/// Blocking screen shown when the app license has expired
class ExpiredScreen extends StatelessWidget {
  final String expiryDate;
  final SubscriptionResult? subResult;
  final VoidCallback onExtended;
  const ExpiredScreen({super.key, required this.expiryDate, this.subResult, required this.onExtended});

  String get _title {
    switch (subResult?.status) {
      case SubscriptionStatus.revoked:
        return 'Access Revoked';
      case SubscriptionStatus.deviceMismatch:
        return 'Device Mismatch';
      default:
        return 'License Expired';
    }
  }

  String get _subtitle {
    switch (subResult?.status) {
      case SubscriptionStatus.revoked:
        return 'Your subscription has been revoked by admin.';
      case SubscriptionStatus.deviceMismatch:
        return 'This account is registered to a different device.\nContact admin for device migration.';
      default:
        return expiryDate.isNotEmpty
          ? 'Your app license expired on $expiryDate.'
          : 'Your subscription has expired.';
    }
  }

  IconData get _icon {
    switch (subResult?.status) {
      case SubscriptionStatus.revoked:
        return Icons.block;
      case SubscriptionStatus.deviceMismatch:
        return Icons.devices;
      default:
        return Icons.lock_clock;
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceService = DeviceIdService();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 420, padding: const EdgeInsets.all(40),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, size: 64, color: AppColors.error),
                ),
                const SizedBox(height: 24),
                Text(_title, style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.error)),
                const SizedBox(height: 12),
                Text(_subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                Text('Please contact the developer to renew.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4))),

                // Subscription details
                if (subResult?.email != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Icon(Icons.email, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'Email: ${subResult!.email}',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)))),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.phone_android, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'Device: ${deviceService.deviceName ?? "Unknown"}',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)))),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.fingerprint, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'ID: ${deviceService.deviceId ?? "Unknown"}',
                          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3)))),
                      ]),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.phone, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('9449831316', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ]),
                const SizedBox(height: 8),
                const Text('Sumukha Tech Solutions',
                  style: TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _openWhatsApp(),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('WhatsApp Us'),
                )),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _showMasterPasswordDialog(context),
                  icon: const Icon(Icons.key, size: 18),
                  label: const Text('Enter Activation Code'),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showMasterPasswordDialog(BuildContext context) {
    final pwdCtrl = TextEditingController();
    showDialog(context: context, builder: (dCtx) => AlertDialog(
      title: const Text('Enter Master Password'),
      content: TextField(
        controller: pwdCtrl,
        obscureText: true,
        decoration: InputDecoration(
          hintText: 'Master password',
          prefixIcon: const Icon(Icons.lock),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (pwdCtrl.text == AppConstants.masterPassword) {
              Navigator.pop(dCtx);
              // Activate subscription in Firestore if email available
              if (subResult?.email != null) {
                await _showDatePickerAndActivate(context);
              } else {
                _showLocalDatePicker(context);
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Invalid password'), backgroundColor: AppColors.error));
            }
          },
          child: const Text('Verify'),
        ),
      ],
    ));
  }

  Future<void> _showDatePickerAndActivate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
      helpText: 'SET NEW EXPIRY DATE',
    );
    if (picked != null && context.mounted) {
      try {
        await SubscriptionService().activateSubscription(subResult!.email!, picked);
        onExtended();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Activation error: $e'), backgroundColor: AppColors.error));
        }
      }
    }
  }

  void _showLocalDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
      helpText: 'SET NEW EXPIRY DATE',
    );
    if (picked != null && context.mounted) {
      final newExpiry = picked.toIso8601String().split('T').first;
      final appState = context.read<AppState>();
      await appState.saveSetting('app_expiry_date', newExpiry);
      onExtended();
    }
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onLogout;
  const MainShell({super.key, required this.onLogout});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<ShortcutBinding> _customShortcuts = [];
  bool _shortcutsLoaded = false;
  bool _fakeQuoteEnabled = false;

  // All screens indexed
  static const _allScreens = [
    DashboardScreen(),          // 0
    BillingScreen(),            // 1 - Sales
    PurchaseScreen(),           // 2 - Purchase
    HistoryScreen(),            // 3 - Payments
    ItemsScreen(),              // 4
    StockScreen(),              // 5
    CustomersScreen(),          // 6
    QuotationScreen(),          // 7
    ExpenseScreen(),            // 8
    ReportsScreen(),            // 9
    CreditNoteScreen(),         // 10
    PurchaseReturnScreen(),     // 11
    CustomerLedgerScreen(),     // 12
    SupplierScreen(),           // 13
    RecurringBillScreen(),      // 14
    SettingsScreen(),           // 15
    AuditTrailScreen(),         // 16
    CashBookScreen(),           // 17
    SerialTrackerScreen(),      // 18
    SupplierPaymentScreen(),    // 19
    FakeQuoteScreen(),           // 20
    QrGeneratorScreen(),          // 21
  ];

  static const _bottomBarMapping = [0, 1, 2, 3];

  int get _bottomBarIndex {
    final idx = _bottomBarMapping.indexOf(_currentIndex);
    return idx >= 0 ? idx : -1;
  }

  static const _drawerItems = [
    _DrawerItem(icon: Icons.dashboard, label: 'Dashboard', index: 0),
    _DrawerItem(icon: Icons.add_circle, label: 'New Bill / Sales', index: 1),
    _DrawerItem(icon: Icons.shopping_bag, label: 'Purchase', index: 2),
    _DrawerItem(icon: Icons.receipt_long, label: 'Payments / History', index: 3),
    _DrawerItem(icon: Icons.inventory_2, label: 'Items', index: 4),
    _DrawerItem(icon: Icons.warehouse, label: 'Stock', index: 5),
    _DrawerItem(icon: Icons.people, label: 'Customers', index: 6),
    _DrawerItem(icon: Icons.local_shipping, label: 'Suppliers', index: 13),
    _DrawerItem(icon: Icons.payment, label: 'Supplier Payments', index: 19),
    _DrawerItem(icon: Icons.description, label: 'Quotations', index: 7),
    _DrawerItem(icon: Icons.money_off, label: 'Expenses', index: 8),
    _DrawerItem(icon: Icons.account_balance_wallet, label: 'Cash & Bank Book', index: 17),
    _DrawerItem(icon: Icons.repeat, label: 'Recurring Bills', index: 14),
    _DrawerItem(icon: Icons.assignment_return, label: 'Credit Notes', index: 10),
    _DrawerItem(icon: Icons.keyboard_return, label: 'Purchase Returns', index: 11),
    _DrawerItem(icon: Icons.account_balance_wallet, label: 'Customer Ledger', index: 12),
    _DrawerItem(icon: Icons.bar_chart, label: 'Reports', index: 9),
    _DrawerItem(icon: Icons.history, label: 'Audit Trail', index: 16),
    _DrawerItem(icon: Icons.qr_code_scanner, label: 'Serial Tracker', index: 18),
    _DrawerItem(icon: Icons.description_outlined, label: 'Fake Quote', index: 20),
    _DrawerItem(icon: Icons.qr_code_2, label: 'QR Generator', index: 21),
    _DrawerItem(icon: Icons.settings, label: 'Settings', index: 15),
  ];

  void _goTo(int index) {
    setState(() => _currentIndex = index);
  }

  void _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.logout, color: AppColors.error), SizedBox(width: 10),
          Text('Logout')]),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onLogout();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shortcutsLoaded) {
      _shortcutsLoaded = true;
      _loadCustomShortcuts();
    }
  }

  Future<void> _loadCustomShortcuts() async {
    final appState = context.read<AppState>();
    final shortcuts = await loadShortcuts(appState);
    if (mounted) setState(() => _customShortcuts = shortcuts);
  }

  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings() {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final sc in _customShortcuts) {
      bindings[sc.toActivator()] = () => _goTo(sc.screenIndex);
    }
    // Always keep the help shortcut
    bindings[const SingleActivator(LogicalKeyboardKey.slash, control: true, shift: true)] = () => _showShortcutsHelp();
    return bindings;
  }

  void _showShortcutsHelp() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.keyboard, color: AppColors.primary), SizedBox(width: 10), Text('Keyboard Shortcuts')]),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _shortcutSection('Navigation', [
          ..._customShortcuts.map((sc) => _shortcutRow(sc.displayString, sc.label)),
        ]),
        _shortcutSection('Actions', [
          _shortcutRow('Ctrl + F', 'Global Search'),
          _shortcutRow('Ctrl + Shift + /', 'Show this help'),
        ]),
      ]))),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Widget _shortcutSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary))),
      ...children,
      const Divider(height: 16),
    ]);
  }

  Widget _shortcutRow(String keys, String action) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
          child: Text(keys, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFamily: 'monospace', color: AppColors.primary))),
        const SizedBox(width: 14),
        Expanded(child: Text(action, style: const TextStyle(fontSize: 13))),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // On back press at root, show exit dialog
        if (_currentIndex != 0) {
          // If not on dashboard, go to dashboard first
          setState(() => _currentIndex = 0);
          return;
        }
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.exit_to_app, color: AppColors.error), SizedBox(width: 10),
              Text('Exit My Billu?')]),
            content: const Text('Are you sure you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Exit')),
            ],
          ),
        );
        if (shouldExit == true) {
          if (!kIsWeb && (Platform.isAndroid || Platform.isWindows)) {
            exit(0);
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: CallbackShortcuts(
        bindings: _buildShortcutBindings(),
        child: Focus(
          autofocus: true,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;

      // Load fake quote enabled setting
      final appState = context.watch<AppState>();
      appState.getSetting('fake_quote_enabled').then((v) {
        final enabled = v == 'true';
        if (enabled != _fakeQuoteEnabled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _fakeQuoteEnabled = enabled);
          });
        }
      });

      if (isWide) {
        // Desktop / Web wide layout - custom scrollable sidebar
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          body: Row(children: [
            Container(
              width: 220,
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              child: Column(children: [
                // Logo header
                InkWell(
                  onTap: () => _showFYPicker(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text('My Billu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
                    ]),
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                // Scrollable menu items
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(children: _drawerItems.where((item) => item.index != 20 || _fakeQuoteEnabled).map((item) {
                      final isSelected = _currentIndex == item.index;
                      // Compute badges
                      int badge = 0;
                      if (item.index == 5) badge = appState.items.where((i) => i.stockQuantity < 10).length;
                      else if (item.index == 3) badge = appState.bills.where((b) => b.status == BillStatus.unpaid || b.status == BillStatus.partial).length;
                      else if (item.index == 14) badge = appState.recurringBills.where((rb) => rb.isActive && DateTime.now().isAfter(rb.nextDueDate)).length;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -2),
                          leading: Icon(item.icon, size: 20,
                            color: isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54)),
                          title: Text(item.label, style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                            color: isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87),
                          )),
                          trailing: badge > 0 ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                            child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ) : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onTap: () => _goTo(item.index),
                        ),
                      );
                    }).toList()),
                  ),
                ),
                // Footer with Logout
                Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Logout', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Text('Sumukha Tech Solutions', style: TextStyle(
                    fontSize: 10, color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black26, fontWeight: FontWeight.w500)),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: () => _openWhatsApp(),
                    icon: const Icon(Icons.chat, size: 14, color: Color(0xFF25D366)),
                    label: const Text('Contact Us', style: TextStyle(fontSize: 10, color: Color(0xFF25D366))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )),
                ),
              ]),
            ),
            VerticalDivider(width: 1, color: isDark
                ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
            Expanded(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(key: ValueKey(_currentIndex), child: _allScreens[_currentIndex]),
            )),
          ]),
        );
      }

      // Mobile / narrow layout - drawer + bottom bar
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu, size: 26),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF00F5A0), Color(0xFF00D9F5), Color(0xFFA855F7)],
            ).createShader(bounds),
            child: const Text('My Billu', style: TextStyle(
              fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, letterSpacing: -0.5)),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.search, size: 22),
              tooltip: 'Global Search',
              onPressed: () {
                final appState = context.read<AppState>();
                showSearch(context: context, delegate: _GlobalSearchDelegate(appState, _goTo));
              }),
            IconButton(
              icon: Icon(
                AppTheme.getPalette(MyBilluApp.themeNotifier.value).isDark
                    ? Icons.light_mode
                    : Icons.dark_mode,
                size: 22),
              tooltip: 'Next Theme',
              onPressed: () {
                final themes = AppTheme.allThemes;
                final currentIdx = themes.indexWhere((t) => t.id == MyBilluApp.themeNotifier.value);
                final nextIdx = (currentIdx + 1) % themes.length;
                MyBilluApp.themeNotifier.value = themes[nextIdx].id;
                context.read<AppState>().saveSetting('app_theme', themes[nextIdx].id);
                setState(() {});
              }),
          ],
        ),
        drawer: _buildDrawer(context),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(key: ValueKey(_currentIndex), child: _allScreens[_currentIndex]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _bottomBarIndex >= 0 ? _bottomBarIndex : 0,
          onDestinationSelected: (i) => _goTo(_bottomBarMapping[i]),
          height: 70,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'New Bill',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag),
              label: 'Purchase',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Payments',
            ),
          ],
        ),
      );
    });
  }

  void _showFYPicker(BuildContext context) {
    final appState = context.read<AppState>();
    final now = DateTime.now();
    final currentFYStart = now.month >= 4 ? now.year : now.year - 1;
    final fyOptions = List.generate(8, (i) {
      final y = currentFYStart - 5 + i;
      return '$y-${(y + 1).toString().substring(2)}';
    });

    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.date_range, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          const Text('Select Financial Year'),
        ]),
        content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Choose the financial year (April - March) you want to work with.',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          ...fyOptions.map((fy) {
            final isCurrent = fy == '$currentFYStart-${(currentFYStart + 1).toString().substring(2)}';
            return Padding(padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  await appState.saveSetting('financial_year', fy);
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
                        Text('Financial Year set to FY $fy'),
                      ]),
                      backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isCurrent ? AppColors.primary : Colors.grey.withValues(alpha: 0.2))),
                  child: Row(children: [
                    Icon(Icons.calendar_month, size: 18, color: isCurrent ? AppColors.primary : Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(child: Text('FY $fy', style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? AppColors.primary : null, fontSize: 14))),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary))),
                  ]),
                ),
              ));
          }),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      );
    });
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark
          ? const Color(0xFF0F0F23) : Colors.white,
      child: Column(children: [
        // Drawer Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A3E), Color(0xFF0F0F23)],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showFYPicker(context);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 14),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00F5A0), Color(0xFF00D9F5), Color(0xFFA855F7)],
              ).createShader(bounds),
              child: const Text('My Billu', style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
            ),
            const SizedBox(height: 4),
            Text('Smart Billing Software', style: TextStyle(
              fontSize: 12, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
          ]),
        ),

        // Menu Items
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
          ..._drawerItems.where((item) => item.index != 20 || _fakeQuoteEnabled).map((item) {
            final isSelected = _currentIndex == item.index;
            final appState = context.watch<AppState>();
            // Compute badges
            int badge = 0;
            if (item.index == 5) { // Stock
              badge = appState.items.where((i) => i.stockQuantity < 10).length;
            } else if (item.index == 3) { // Payments
              badge = appState.bills.where((b) => b.status == BillStatus.unpaid || b.status == BillStatus.partial).length;
            } else if (item.index == 14) { // Recurring Bills
              badge = appState.recurringBills.where((rb) => rb.isActive && DateTime.now().isAfter(rb.nextDueDate)).length;
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(item.icon, size: 22,
                  color: isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54)),
                title: Text(item.label, style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                  color: isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87),
                )),
                trailing: badge > 0 ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  _goTo(item.index);
                  Navigator.pop(context); // Close drawer
                },
              ),
            );
          }),
        ])),

        // Footer with Logout
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _confirmLogout(context);
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text('Sumukha Tech Solutions', style: TextStyle(
            fontSize: 11, color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black38, fontWeight: FontWeight.w500)),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openWhatsApp();
            },
            icon: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
            label: const Text('Contact Us', style: TextStyle(fontSize: 11, color: Color(0xFF25D366))),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )),
        ),
      ]),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String label;
  final int index;
  const _DrawerItem({required this.icon, required this.label, required this.index});
}

// ===== GLOBAL SEARCH =====
class _GlobalSearchDelegate extends SearchDelegate<String> {
  final AppState appState;
  final void Function(int) goTo;

  _GlobalSearchDelegate(this.appState, this.goTo);

  @override
  String get searchFieldLabel => 'Search items, customers, bills...';

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _buildSuggestionList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestionList(context);

  Widget _buildSuggestionList(BuildContext context) {
    if (query.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('Type to search across items, customers, suppliers & bills',
          style: TextStyle(color: Colors.grey.withValues(alpha: 0.5))),
      ]));
    }

    final q = query.toLowerCase();
    final results = <_SearchResult>[];

    // Items
    for (final item in appState.items) {
      if (item.name.toLowerCase().contains(q) || (item.hsnCode ?? '').toLowerCase().contains(q)) {
        results.add(_SearchResult(Icons.inventory_2, item.name, 'Item • ₹${item.price.toStringAsFixed(2)} • Stock: ${item.stockQuantity}', 4));
      }
    }
    // Customers
    for (final c in appState.customers) {
      if (c.name.toLowerCase().contains(q) || (c.phone ?? '').contains(q)) {
        results.add(_SearchResult(Icons.person, c.name, 'Customer • ${c.phone ?? "No phone"}', 6));
      }
    }
    // Suppliers
    for (final s in appState.suppliers) {
      if (s.name.toLowerCase().contains(q) || (s.phone ?? '').contains(q)) {
        results.add(_SearchResult(Icons.local_shipping, s.name, 'Supplier • ${s.phone ?? "No phone"}', 13));
      }
    }
    // Bills
    for (final b in appState.bills) {
      if (b.billNumber.toLowerCase().contains(q) || (b.customerName ?? '').toLowerCase().contains(q)) {
        results.add(_SearchResult(Icons.receipt, b.billNumber, 'Bill • ${b.customerName ?? "Walk-in"} • ₹${b.totalAmount.toStringAsFixed(2)}', 3));
      }
    }

    if (results.isEmpty) {
      return Center(child: Text('No results for "$query"', style: TextStyle(color: Colors.grey.withValues(alpha: 0.5))));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final r = results[i];
        return ListTile(
          leading: Icon(r.icon, color: AppColors.primary),
          title: Text(r.title),
          subtitle: Text(r.subtitle, style: const TextStyle(fontSize: 12)),
          onTap: () { close(context, ''); goTo(r.screenIndex); },
        );
      },
    );
  }
}

class _SearchResult {
  final IconData icon;
  final String title;
  final String subtitle;
  final int screenIndex;
  _SearchResult(this.icon, this.title, this.subtitle, this.screenIndex);
}


