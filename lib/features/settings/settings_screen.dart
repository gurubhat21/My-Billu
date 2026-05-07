import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/item.dart';
import '../../core/models/customer.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/web_helper.dart' as web_helper;
import '../../core/database/full_backup_exporter.dart';
import 'package:printing/printing.dart';

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

          // Data Export Section
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.backup, size: 22, color: AppColors.success)),
                const SizedBox(width: 12),
                Text('Data Backup', style: Theme.of(context).textTheme.titleLarge),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    final appState = context.read<AppState>();
                    try {
                      final bytes = await FullBackupExporter.exportAll(
                        items: appState.items, customers: appState.customers,
                        bills: appState.bills, purchases: appState.purchases,
                        expenses: appState.expenses, suppliers: appState.suppliers);
                      await Printing.sharePdf(bytes: bytes, filename: 'MyBillu_Backup_${DateTime.now().millisecondsSinceEpoch}.xlsx');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('✅ Backup exported!'), backgroundColor: AppColors.success));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Export failed: $e'), backgroundColor: AppColors.error));
                      }
                    }
                  },
                  icon: const Icon(Icons.download, size: 18), label: const Text('Export Full Backup (Excel)'))),
              ]),
            ])),
          const SizedBox(height: 20),

          // Staff Management
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.people, size: 22, color: AppColors.accent)),
                const SizedBox(width: 12),
                Text('Staff / Multi-User', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  onPressed: () => _showStaffDialog(context),
                  icon: const Icon(Icons.person_add, size: 16), label: const Text('Add Staff', style: TextStyle(fontSize: 12))),
              ]),
              const SizedBox(height: 12),
              FutureBuilder<String?>(
                future: context.read<AppState>().getSetting('staff_list'),
                builder: (ctx, snap) {
                  if (!snap.hasData || snap.data == null || snap.data!.isEmpty) {
                    return Text('No staff accounts. Admin login: admin / 12345',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)));
                  }
                  final staffList = (jsonDecode(snap.data!) as List).cast<Map<String, dynamic>>();
                  return Column(children: staffList.map((s) => ListTile(
                    dense: true,
                    leading: CircleAvatar(radius: 16, backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                      child: Text((s['name'] as String)[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))),
                    title: Text(s['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('Role: ${s['role']} • User: ${s['username']}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                    trailing: IconButton(icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                      onPressed: () async {
                        staffList.removeWhere((x) => x['username'] == s['username']);
                        await context.read<AppState>().saveSetting('staff_list', jsonEncode(staffList));
                        setState(() {});
                      }),
                  )).toList());
                }),
            ])),
          const SizedBox(height: 20),
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
                // Show current logo
                FutureBuilder<String?>(
                  future: context.read<AppState>().getSetting('businessLogoData'),
                  builder: (ctx, snap) {
                    final logoData = snap.data;
                    final logoUrl = _bizLogoCtrl.text;
                    return Column(children: [
                      if (logoData != null && logoData.isNotEmpty)
                        Center(child: Container(
                          width: 80, height: 80, margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2)),
                          child: ClipRRect(borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              Uri.parse(logoData).data!.contentAsBytes(),
                              fit: BoxFit.cover)),
                        ))
                      else if (logoUrl.isNotEmpty)
                        Center(child: Container(
                          width: 80, height: 80, margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                            image: DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)),
                        )),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () async {
                            final dataUrl = await web_helper.triggerImageUpload();
                            if (dataUrl != null) {
                              final appState = context.read<AppState>();
                              await appState.saveSetting('businessLogoData', dataUrl);
                              setState(() {});
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Row(children: [
                                  Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
                                  Text('Logo uploaded successfully!')]),
                                backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 20),
                          label: const Text('Upload Logo (PNG/JPEG)'),
                        )),
                        if (logoData != null && logoData.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Remove Logo',
                            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                            onPressed: () async {
                              await context.read<AppState>().saveSetting('businessLogoData', '');
                              setState(() {});
                            }),
                        ],
                      ]),
                    ]);
                  }),
                const SizedBox(height: 8),
                TextField(controller: _bizLogoCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Or paste Logo URL',
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
              Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 80, height: 80,
                  margin: const EdgeInsets.only(bottom: 12, right: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/ganesh_logo.png', fit: BoxFit.contain))),
                Container(
                  width: 80, height: 80,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/sumukha_logo.png', fit: BoxFit.contain))),
              ])),
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

  void _showStaffDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'staff';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      return AlertDialog(
        title: const Text('Add Staff Account'),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username *', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password *', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
            value: role,
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Admin (Full Access)')),
              DropdownMenuItem(value: 'staff', child: Text('Staff (Billing + Stock)')),
              DropdownMenuItem(value: 'viewer', child: Text('Viewer (Read Only)')),
            ],
            onChanged: (v) => setDialogState(() => role = v!)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
            final appState = context.read<AppState>();
            final existing = await appState.getSetting('staff_list');
            final staffList = existing != null && existing.isNotEmpty
                ? (jsonDecode(existing) as List).cast<Map<String, dynamic>>()
                : <Map<String, dynamic>>[];
            staffList.add({'name': nameCtrl.text.trim(), 'username': userCtrl.text.trim(),
              'password': passCtrl.text.trim(), 'role': role});
            await appState.saveSetting('staff_list', jsonEncode(staffList));
            if (ctx.mounted) Navigator.pop(ctx);
            setState(() {});
          }, child: const Text('Add')),
        ],
      );
    }));
  }
}
