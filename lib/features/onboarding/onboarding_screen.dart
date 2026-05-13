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

  // Form controllers
  final _businessNameCtrl = TextEditingController();
  final _businessAddressCtrl = TextEditingController();
  final _businessPhoneCtrl = TextEditingController();
  final _businessGstinCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  String _businessType = 'Retail';

  @override
  void dispose() {
    _pageController.dispose();
    _businessNameCtrl.dispose();
    _businessAddressCtrl.dispose();
    _businessPhoneCtrl.dispose();
    _businessGstinCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    final appState = context.read<AppState>();

    // Save business details
    if (_businessNameCtrl.text.trim().isNotEmpty) {
      await appState.saveSetting('businessName', _businessNameCtrl.text.trim());
    }
    if (_businessAddressCtrl.text.trim().isNotEmpty) {
      await appState.saveSetting('businessAddress', _businessAddressCtrl.text.trim());
    }
    if (_businessPhoneCtrl.text.trim().isNotEmpty) {
      await appState.saveSetting('businessPhone', _businessPhoneCtrl.text.trim());
    }
    if (_businessGstinCtrl.text.trim().isNotEmpty) {
      await appState.saveSetting('businessGstin', _businessGstinCtrl.text.trim());
    }
    await appState.saveSetting('businessType', _businessType);

    // Save password
    if (_passwordCtrl.text.isNotEmpty) {
      await appState.saveSetting('loginPassword', _passwordCtrl.text);
    }

    // Mark onboarding complete
    await appState.saveSetting('onboarding_complete', 'true');

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A3E), Color(0xFF0D0D2B)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(children: [
                Text('Step ${_currentPage + 1}/4', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                TextButton(onPressed: _finish,
                  child: Text('Skip', style: TextStyle(color: Colors.white.withValues(alpha: 0.4)))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(children: List.generate(4, (i) => Expanded(
                child: Container(
                  height: 4, margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i <= _currentPage ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ))),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildBusinessPage(),
                  _buildTaxPage(),
                  _buildSecurityPage(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(children: [
                if (_currentPage > 0)
                  OutlinedButton.icon(
                    onPressed: _prevPage,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _currentPage == 3 ? _finish : _nextPage,
                  icon: Icon(_currentPage == 3 ? Icons.check : Icons.arrow_forward, size: 18),
                  label: Text(_currentPage == 3 ? 'Get Started' : 'Next'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    backgroundColor: AppColors.primary),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ===== PAGE 1: WELCOME =====
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 12))],
          ),
          child: const Icon(Icons.receipt_long, color: Colors.white, size: 56),
        ),
        const SizedBox(height: 32),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00F5A0), Color(0xFF00D9F5), Color(0xFFA855F7)],
          ).createShader(bounds),
          child: const Text('Welcome to My Billu', style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
        ),
        const SizedBox(height: 12),
        Text('Smart Billing Software by Sumukha Tech Solutions', style: TextStyle(
          fontSize: 14, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
        const SizedBox(height: 32),
        _featureRow(Icons.receipt_long, 'GST Compliant Invoicing'),
        _featureRow(Icons.inventory_2, 'Inventory & Stock Management'),
        _featureRow(Icons.bar_chart, 'Financial Reports & Analytics'),
        _featureRow(Icons.people, 'Customer & Supplier Management'),
        _featureRow(Icons.cloud_download, 'Excel Import/Export & Backup'),
      ]),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.primary)),
        const SizedBox(width: 14),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ===== PAGE 2: BUSINESS DETAILS =====
  Widget _buildBusinessPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 24),
        const Text('🏢  Business Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Text('This info will appear on your invoices', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
        const SizedBox(height: 28),
        _styledField(_businessNameCtrl, 'Business Name *', Icons.store, 'e.g. Sri Ganesh Traders'),
        const SizedBox(height: 16),
        _styledField(_businessAddressCtrl, 'Address', Icons.location_on_outlined, 'e.g. MG Road, Bangalore', maxLines: 2),
        const SizedBox(height: 16),
        _styledField(_businessPhoneCtrl, 'Phone Number', Icons.phone_outlined, 'e.g. 9449831316', keyboard: TextInputType.phone),
        const SizedBox(height: 16),
        Text('Business Type', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 8, children: ['Retail', 'Wholesale', 'Services', 'Manufacturing', 'Other'].map((t) =>
          ChoiceChip(
            label: Text(t),
            selected: _businessType == t,
            onSelected: (_) => setState(() => _businessType = t),
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            labelStyle: TextStyle(color: _businessType == t ? Colors.white : Colors.white.withValues(alpha: 0.6)),
          )).toList()),
      ]),
    );
  }

  // ===== PAGE 3: TAX DETAILS =====
  Widget _buildTaxPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 24),
        const Text('🧾  Tax & GST Setup', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Text('Optional - you can add this later in Settings', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
        const SizedBox(height: 28),
        _styledField(_businessGstinCtrl, 'GSTIN Number', Icons.badge_outlined, 'e.g. 29ABCDE1234F1ZK'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info_outline, color: AppColors.primary.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 10),
              const Text('Default Tax Settings', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            _infoRow('Tax System', 'GST (India)'),
            _infoRow('Default GST Rate', '18%'),
            _infoRow('CGST + SGST', '9% + 9%'),
            _infoRow('Currency', '₹ INR'),
            const SizedBox(height: 8),
            Text('You can customize GST rates per item in the Items screen.',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      ]));
  }

  // ===== PAGE 4: SECURITY =====
  Widget _buildSecurityPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 24),
        const Text('🔒  Security Setup', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Text('Set a password to protect your data', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
        const SizedBox(height: 28),
        _styledField(_passwordCtrl, 'Set Password', Icons.lock_outline, 'Min 4 characters', obscure: true),
        const SizedBox(height: 16),
        _styledField(_confirmPasswordCtrl, 'Confirm Password', Icons.lock_outline, 'Re-enter password', obscure: true),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 20),
              SizedBox(width: 10),
              Text('You\'re all set!', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            Text('After setup, you can:\n• Add staff accounts with roles\n• Change password anytime in Settings\n• Enable multi-language (Kannada)',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.6)),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Default username: admin  |  Default password: 12345', style: TextStyle(
          fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
      ]),
    );
  }

  Widget _styledField(TextEditingController ctrl, String label, IconData icon, String hint,
      {TextInputType? keyboard, int maxLines = 1, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.4)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
      ),
    );
  }
}


