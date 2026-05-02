import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/item.dart';
import '../../core/models/customer.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/web_helper.dart' as web_helper;
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
              Center(child: Container(
                width: 100, height: 100,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/sumukha_logo.png', fit: BoxFit.contain),
                ),
              )),
              _aboutRow('Created By', 'Sumukha Tech Solutions'),
              _aboutRow('Mobile', '9449831316'),
              _aboutRow('Email', 'sumukhatech21@gmail.com'),
            ])),
          const SizedBox(height: 20),
          // Account (Username & Password)
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.admin_panel_settings, size: 22, color: AppColors.error)),
                const SizedBox(width: 12),
                Text('Account', style: Theme.of(context).textTheme.titleLarge),
              ]),
              const SizedBox(height: 16),
              // Current username display
              FutureBuilder<String?>(
                future: context.read<AppState>().getSetting('loginUsername'),
                builder: (ctx, snap) {
                  final username = snap.data ?? 'admin';
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                    child: Row(children: [
                      const Icon(Icons.person, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      const Text('Username: ', style: TextStyle(fontSize: 13)),
                      Text(username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                    ]));
                }),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _showChangeUsername(context),
                  icon: const Icon(Icons.person_outline, size: 20),
                  label: const Text('Change Username'),
                )),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _showChangePassword(context),
                  icon: const Icon(Icons.key, size: 20),
                  label: const Text('Change Password'),
                )),
              ]),
            ])),
          const SizedBox(height: 20),
          // Backup & Restore
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.backup, size: 22, color: AppColors.warning)),
                const SizedBox(width: 12),
                Text('Backup & Restore', style: Theme.of(context).textTheme.titleLarge),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _backupData(context),
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text('Backup Data'),
                )),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _restoreData(context),
                  icon: const Icon(Icons.upload, size: 20),
                  label: const Text('Restore Data'),
                )),
              ]),
              const SizedBox(height: 8),
              Text('Backup saves all items, customers, bills & purchases as a JSON file.',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
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
  void _showChangeUsername(BuildContext context) {
    final currentPassCtrl = TextEditingController();
    final newUsernameCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.person, color: AppColors.primary), SizedBox(width: 10), Text('Change Username')]),
      content: SizedBox(width: 350, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: currentPassCtrl, obscureText: true,
          decoration: const InputDecoration(labelText: 'Current Password', prefixIcon: Icon(Icons.lock_outline))),
        const SizedBox(height: 12),
        TextField(controller: newUsernameCtrl,
          decoration: const InputDecoration(labelText: 'New Username', prefixIcon: Icon(Icons.person_outline))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final appState = context.read<AppState>();
          final savedPassword = await appState.getSetting('loginPassword') ?? '12345';

          if (currentPassCtrl.text != savedPassword) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password is incorrect'), backgroundColor: AppColors.error));
            return;
          }
          if (newUsernameCtrl.text.trim().isEmpty || newUsernameCtrl.text.trim().length < 3) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Username must be at least 3 characters'), backgroundColor: AppColors.error));
            return;
          }

          await appState.saveSetting('loginUsername', newUsernameCtrl.text.trim());
          if (mounted) {
            Navigator.pop(ctx);
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
                Text('Username changed to "${newUsernameCtrl.text.trim()}"')]),
              backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
          }
        }, child: const Text('Change Username')),
      ],
    ));
  }

  void _showChangePassword(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.lock, color: AppColors.primary), SizedBox(width: 10), Text('Change Password')]),
      content: SizedBox(width: 350, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: currentCtrl, obscureText: true,
          decoration: const InputDecoration(labelText: 'Current Password', prefixIcon: Icon(Icons.lock_outline))),
        const SizedBox(height: 12),
        TextField(controller: newCtrl, obscureText: true,
          decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_reset))),
        const SizedBox(height: 12),
        TextField(controller: confirmCtrl, obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm New Password', prefixIcon: Icon(Icons.lock_reset))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final appState = context.read<AppState>();
          final savedPassword = await appState.getSetting('loginPassword') ?? '12345';

          if (currentCtrl.text != savedPassword) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Current password is incorrect'), backgroundColor: AppColors.error));
            return;
          }
          if (newCtrl.text.isEmpty || newCtrl.text.length < 4) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('New password must be at least 4 characters'), backgroundColor: AppColors.error));
            return;
          }
          if (newCtrl.text != confirmCtrl.text) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppColors.error));
            return;
          }

          await appState.saveSetting('loginPassword', newCtrl.text);
          if (mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
                Text('Password changed successfully!')]),
              backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
          }
        }, child: const Text('Change Password')),
      ],
    ));
  }

  Future<void> _backupData(BuildContext context) async {
    try {
      final appState = context.read<AppState>();
      final backup = {
        'version': '1.0.0',
        'timestamp': DateTime.now().toIso8601String(),
        'items': appState.items.map((i) => i.toMap()).toList(),
        'customers': appState.customers.map((c) => c.toMap()).toList(),
        'bills': appState.bills.map((b) => b.toMap()).toList(),
        'purchases': appState.purchases.map((p) => p.toMap()).toList(),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      web_helper.downloadJson(jsonStr, 'mybillu_backup_${DateTime.now().millisecondsSinceEpoch}.json');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
            Text('Backup downloaded successfully!')]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    try {
      final jsonStr = await web_helper.triggerFileUpload();
      if (jsonStr == null) return;

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This will ADD the backup data to your current data.', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Items: ${(data['items'] as List?)?.length ?? 0}'),
          Text('Customers: ${(data['customers'] as List?)?.length ?? 0}'),
          Text('Bills: ${(data['bills'] as List?)?.length ?? 0}'),
          Text('Purchases: ${(data['purchases'] as List?)?.length ?? 0}'),
          if (data['timestamp'] != null) ...[
            const SizedBox(height: 8),
            Text('Backup date: ${data['timestamp']}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ));

      if (confirm != true || !mounted) return;

      final appState = context.read<AppState>();
      if (data['items'] != null) {
        for (final m in data['items']) {
          try { await appState.addItem(Item.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      if (data['customers'] != null) {
        for (final m in data['customers']) {
          try { await appState.addCustomer(Customer.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
            Text('Data restored successfully!')]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}
