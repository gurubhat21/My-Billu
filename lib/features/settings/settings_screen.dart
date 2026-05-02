import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _bizNameCtrl = TextEditingController();
  final _bizAddressCtrl = TextEditingController();
  final _bizPhoneCtrl = TextEditingController();
  final _bizGstinCtrl = TextEditingController();
  final _bizLogoCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final appState = context.read<AppState>();
    final settings = await appState.getAllSettings();
    setState(() {
      _bizNameCtrl.text = settings['businessName'] ?? '';
      _bizAddressCtrl.text = settings['businessAddress'] ?? '';
      _bizPhoneCtrl.text = settings['businessPhone'] ?? '';
      _bizGstinCtrl.text = settings['businessGstin'] ?? '';
      _bizLogoCtrl.text = settings['businessLogo'] ?? '';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final appState = context.read<AppState>();
    await appState.saveSetting('businessName', _bizNameCtrl.text.trim());
    await appState.saveSetting('businessAddress', _bizAddressCtrl.text.trim());
    await appState.saveSetting('businessPhone', _bizPhoneCtrl.text.trim());
    await appState.saveSetting('businessGstin', _bizGstinCtrl.text.trim());
    await appState.saveSetting('businessLogo', _bizLogoCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
          Text('Settings saved!')]),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 700;
      return SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 24 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 24),
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.business, size: 22, color: AppColors.primary)),
                const SizedBox(width: 12),
                Text('Business Profile', style: Theme.of(context).textTheme.titleLarge),
              ]),
              const SizedBox(height: 20),
              if (!_loaded) const Center(child: CircularProgressIndicator())
              else ...[
                TextField(controller: _bizNameCtrl,
                  decoration: const InputDecoration(labelText: 'Business Name', prefixIcon: Icon(Icons.store))),
                const SizedBox(height: 14),
                TextField(controller: _bizAddressCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined))),
                const SizedBox(height: 14),
                TextField(controller: _bizPhoneCtrl, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 14),
                TextField(controller: _bizGstinCtrl,
                  decoration: const InputDecoration(labelText: 'GSTIN', prefixIcon: Icon(Icons.badge_outlined))),
                const SizedBox(height: 20),

                // Logo section
                Row(children: [
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.image, size: 22, color: AppColors.accent)),
                  const SizedBox(width: 12),
                  Text('Business Logo', style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 12),
                if (_bizLogoCtrl.text.isNotEmpty)
                  Center(child: Container(
                    width: 80, height: 80, margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                      image: DecorationImage(image: NetworkImage(_bizLogoCtrl.text), fit: BoxFit.cover),
                    ),
                  )),
                TextField(controller: _bizLogoCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Logo URL (paste image link)',
                    prefixIcon: Icon(Icons.link),
                    hintText: 'https://example.com/logo.png',
                  )),
                const SizedBox(height: 20),

                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(onPressed: _save,
                    icon: const Icon(Icons.save, size: 20), label: const Text('Save Settings'))),
              ],
            ])),
          const SizedBox(height: 20),
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.info_outline, size: 22, color: AppColors.accent)),
                const SizedBox(width: 12),
                Text('About', style: Theme.of(context).textTheme.titleLarge),
              ]),
              const SizedBox(height: 16),
              _aboutRow('App Name', 'My Billu'),
              _aboutRow('Version', '1.0.0'),
              _aboutRow('Tax System', 'GST (India)'),
              _aboutRow('Currency', '₹ INR'),
              const Divider(height: 24),
              _aboutRow('Created By', 'Sumukha Tech Solutions'),
              _aboutRow('Mobile', '9449831316'),
              _aboutRow('Email', 'sumukhatech21@gmail.com'),
            ])),
        ]),
      );
    });
  }

  Widget _aboutRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]));
  }

  @override
  void dispose() {
    _bizNameCtrl.dispose();
    _bizAddressCtrl.dispose();
    _bizPhoneCtrl.dispose();
    _bizGstinCtrl.dispose();
    _bizLogoCtrl.dispose();
    super.dispose();
  }
}
