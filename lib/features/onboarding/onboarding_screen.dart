import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Step 2 controllers
  final _bizNameCtrl = TextEditingController();
  final _bizAddressCtrl = TextEditingController();
  final _bizPhoneCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();

  // Step 3 controllers
  final _usernameCtrl = TextEditingController(text: 'admin');
  final _passwordCtrl = TextEditingController(text: '12345');

  @override
  void dispose() {
    _pageController.dispose();
    _bizNameCtrl.dispose();
    _bizAddressCtrl.dispose();
    _bizPhoneCtrl.dispose();
    _gstinCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  void _prev() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    final appState = context.read<AppState>();
    // Save business info
    if (_bizNameCtrl.text.trim().isNotEmpty) {
      await appState.saveSetting('businessName', _bizNameCtrl.text.trim());
    }
    if (_bizAddressCtrl.text.trim().isNotEmpty) {
      await appState.saveSetting('businessAddress', _bizAddressCtrl.text.trim());
    }
    if (_bizPhoneCtrl.text.trim().isNotEmpty) {
      await appState.saveSetting('businessPhone', _bizPhoneCtrl.text.trim());
    }
    if (_gstinCtrl.text.trim().isNotEmpty) {
      await appState.saveSetting('businessGstin', _gstinCtrl.text.trim());
    }
    // Save login credentials
    await appState.saveSetting('loginUsername', _usernameCtrl.text.trim());
    await appState.saveSetting('loginPassword', _passwordCtrl.text.trim());
    // Mark onboarding as done
    await appState.saveSetting('onboarding_done', 'true');

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A3E), Color(0xFF0D0D2B)]),
        ),
        child: SafeArea(
          child: Column(children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(children: List.generate(4, (i) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i <= _currentPage
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.1)),
                ),
              ))),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(),
                  _buildBusinessPage(),
                  _buildSecurityPage(),
                  _buildReadyPage(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(children: [
                if (_currentPage > 0)
                  TextButton.icon(
                    onPressed: _prev,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back'))
                else
                  const SizedBox(width: 80),
                const Spacer(),
                if (_currentPage < 3)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _next,
                    icon: const Text('Next', style: TextStyle(fontWeight: FontWeight.w700)),
                    label: const Icon(Icons.arrow_forward, size: 18))
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _finish,
                    icon: const Text('Get Started!', style: TextStyle(fontWeight: FontWeight.w700)),
                    label: const Icon(Icons.rocket_launch, size: 18)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ===== PAGE 1: Welcome =====
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 40)]),
          child: const Icon(Icons.receipt_long, color: Colors.white, size: 64),
        ),
        const SizedBox(height: 36),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00F5A0), Color(0xFF00D9F5), Color(0xFFA855F7)],
          ).createShader(bounds),
          child: const Text('Welcome to My Billu', style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        const SizedBox(height: 16),
        Text('Your all-in-one smart billing & inventory management software.\nLet\'s set up your business in under a minute!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.6), height: 1.5)),
        const SizedBox(height: 32),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _featureChip(Icons.receipt, 'GST Billing'),
          const SizedBox(width: 10),
          _featureChip(Icons.inventory_2, 'Inventory'),
          const SizedBox(width: 10),
          _featureChip(Icons.analytics, 'Reports'),
        ]),
      ]),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]),
    );
  }

  // ===== PAGE 2: Business Setup =====
  Widget _buildBusinessPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 40),
        Row(children: [
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.business, size: 28, color: AppColors.accent)),
          const SizedBox(width: 14),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Business Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text('This info appears on your invoices', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ]),
        const SizedBox(height: 28),
        _inputField(_bizNameCtrl, 'Business Name *', Icons.storefront),
        const SizedBox(height: 14),
        _inputField(_bizAddressCtrl, 'Address', Icons.location_on, maxLines: 2),
        const SizedBox(height: 14),
        _inputField(_bizPhoneCtrl, 'Phone Number', Icons.phone),
        const SizedBox(height: 14),
        _inputField(_gstinCtrl, 'GSTIN (optional)', Icons.verified, hint: 'e.g. 29AABCU9603R1ZP'),
      ]),
    );
  }

  // ===== PAGE 3: Security =====
  Widget _buildSecurityPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 40),
        Row(children: [
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.shield, size: 28, color: AppColors.warning)),
          const SizedBox(width: 14),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Login Setup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text('Set your admin credentials', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ]),
        const SizedBox(height: 28),
        _inputField(_usernameCtrl, 'Username', Icons.person),
        const SizedBox(height: 14),
        _inputField(_passwordCtrl, 'Password', Icons.lock),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.2))),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text('Default: admin / 12345\nYou can change this later in Settings.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)))),
          ]),
        ),
      ]),
    );
  }

  // ===== PAGE 4: Ready =====
  Widget _buildReadyPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: AppColors.success, size: 72),
        ),
        const SizedBox(height: 28),
        const Text('You\'re All Set! 🎉', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Text('Your business is ready to roll. Start creating bills,\nmanaging inventory, and tracking payments.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6), height: 1.5)),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: Column(children: [
            _readyItem(Icons.receipt, 'Create GST-compliant invoices'),
            const SizedBox(height: 10),
            _readyItem(Icons.inventory_2, 'Track stock & low-stock alerts'),
            const SizedBox(height: 10),
            _readyItem(Icons.analytics, 'View profit & sales reports'),
            const SizedBox(height: 10),
            _readyItem(Icons.cloud_download, 'Export data as PDF & Excel'),
          ]),
        ),
      ]),
    );
  }

  Widget _readyItem(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.success),
      const SizedBox(width: 12),
      Text(text, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
    ]);
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {String? hint, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }
}
