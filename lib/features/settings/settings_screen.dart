import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/item.dart';
import '../../core/models/customer.dart';
import '../../core/models/bill.dart';
import '../../core/models/purchase.dart';
import '../../core/models/quotation.dart';
import '../../core/models/expense.dart';
import '../../core/models/credit_note.dart';
import '../../core/models/purchase_return.dart';
import '../../core/models/supplier.dart';
import '../../core/models/recurring_bill.dart';
import '../../core/models/cash_book.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/web_helper.dart' as web_helper;
import '../../core/database/full_backup_exporter.dart';
import '../../core/utils/app_strings.dart';
import '../../core/utils/excel_importer.dart';
import 'package:printing/printing.dart';

import '../../widgets/common_widgets.dart';
import '../../core/utils/validators.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../../core/services/lan_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'keyboard_shortcuts_screen.dart';
import 'import_export_screen.dart';
import 'package:local_auth/local_auth.dart';

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
  final _barcodeCtrl = TextEditingController();
  bool _loaded = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

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
      _lanIpCtrl.text = settings['lan_sync_ip'] ?? '';
      _biometricEnabled = settings['biometric_enabled'] == 'true';
      _loaded = true;
    });
    // Check biometric availability
    _checkBiometricAvailability();
  }

  Future<void> _save() async {
    // Validate GSTIN before saving
    final gstinError = Validators.validateGstin(_bizGstinCtrl.text);
    if (gstinError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(gstinError), backgroundColor: AppColors.error));
      return;
    }
    final appState = context.read<AppState>();
    await appState.saveSetting('businessName', _bizNameCtrl.text.trim());
    await appState.saveSetting('businessAddress', _bizAddressCtrl.text.trim());
    await appState.saveSetting('businessPhone', _bizPhoneCtrl.text.trim());
    await appState.saveSetting('businessGstin', _bizGstinCtrl.text.trim().toUpperCase());
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

  void _doBarcodeLookup(BuildContext context) {
    final val = _barcodeCtrl.text.trim();
    if (val.isEmpty) return;
    final appState = context.read<AppState>();
    final query = val.toLowerCase();
    final matches = appState.items.where((i) =>
      (i.barcode ?? '').toLowerCase() == query ||
      (i.hsnCode ?? '').toLowerCase() == query ||
      (i.barcode ?? '').toLowerCase().contains(query) ||
      (i.hsnCode ?? '').toLowerCase().contains(query) ||
      i.name.toLowerCase().contains(query)).toList();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Results for "$val" (${matches.length} found)'),
      content: SizedBox(width: 400, height: matches.isEmpty ? 60 : null,
        child: matches.isEmpty
          ? const Center(child: Text('No items found with this code'))
          : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
            children: matches.take(20).map((item) => ListTile(dense: true,
              leading: const Icon(Icons.inventory_2, color: AppColors.primary),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Barcode: ${item.barcode ?? "—"} • HSN: ${item.hsnCode ?? "—"}\n₹${item.price.toStringAsFixed(2)} • Stock: ${item.stockQuantity} ${item.unit}'),
              isThreeLine: true,
            )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
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

          // Cloud Sync Section
          _buildCloudSyncCard(context),
          const SizedBox(height: 20),

          // LAN Sync Section
          _buildLanSyncCard(context),
          const SizedBox(height: 20),

          // Import & Export
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)]),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.import_export, size: 22, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Import & Export', style: Theme.of(context).textTheme.titleLarge),
                  Text('JSON, Excel, CSV — bulk import & export all data',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                ])),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ImportExportScreen())),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open Import & Export'),
              )),
            ])),
          const SizedBox(height: 20),




          // Language Selection
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.language, size: 22, color: AppColors.warning)),
                const SizedBox(width: 12),
                Text('Language / ಭಾಷೆ', style: Theme.of(context).textTheme.titleLarge),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _langChip(context, 'English', 'en'),
                const SizedBox(width: 12),
                _langChip(context, 'ಕನ್ನಡ', 'kn'),
              ]),
            ])),
          const SizedBox(height: 20),

          // Barcode / HSN Lookup
          GlassCard(padding: const EdgeInsets.all(20), child: StatefulBuilder(
            builder: (ctx, setLocalState) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.qr_code_scanner, size: 22, color: Color(0xFF8B5CF6))),
                  const SizedBox(width: 12),
                  Text('Barcode / HSN Lookup', style: Theme.of(context).textTheme.titleLarge),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _barcodeCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter barcode or HSN code...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    onSubmitted: (_) => _doBarcodeLookup(context),
                  )),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => _doBarcodeLookup(context),
                    child: const Icon(Icons.search, color: Colors.white)),
                ]),
                const SizedBox(height: 8),
                Text('Type barcode, HSN code or item name → press Search or Enter',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
              ]);
            })),
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

          // Biometric Authentication Toggle (Android/iOS only)
          if (!kIsWeb) _buildBiometricCard(context),
          if (!kIsWeb) const SizedBox(height: 20),

          // Keyboard Shortcuts - Editable
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.keyboard, size: 22, color: AppColors.warning)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Keyboard Shortcuts', style: Theme.of(context).textTheme.titleLarge),
                  Text('Customize navigation shortcuts', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                ])),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const KeyboardShortcutsScreen())),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Keyboard Shortcuts'),
              )),
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
                width: 80, height: 80,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/ganesh_logo.png', fit: BoxFit.contain)),
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

  bool _syncing = false;

  Widget _buildCloudSyncCard(BuildContext context) {
    return GlassCard(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.sync, size: 22, color: Colors.white)),
          const SizedBox(width: 12),
          Text('Sync Across Devices', style: Theme.of(context).textTheme.titleLarge),
        ]),
        const SizedBox(height: 12),
        Text('Transfer your data between Android, Windows & Web',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 16),

        // Step 1: Share Backup
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.15))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Text('1', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.success))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Share Backup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('Send via WhatsApp, Email, Bluetooth, Drive', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
            ])),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onPressed: _syncing ? null : () => _shareBackup(context),
              icon: _syncing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.share, size: 16),
              label: const Text('Share', style: TextStyle(fontSize: 12)),
            ),
          ])),

        const SizedBox(height: 10),

        // Step 2: Import Backup
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Text('2', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Import Backup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('Open received backup file on other device', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
            ])),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onPressed: _syncing ? null : () => _restoreData(context),
              icon: const Icon(Icons.file_open, size: 16),
              label: const Text('Import', style: TextStyle(fontSize: 12)),
            ),
          ])),

        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.info_outline, size: 16, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Share backup from Device A → Open the file on Device B → All data synced!',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35)))),
          ])),
      ]));
  }

  Future<void> _shareBackup(BuildContext context) async {
    setState(() => _syncing = true);
    try {
      final appState = context.read<AppState>();
      final settings = await appState.getAllSettings();
      final backup = {
        'version': '2.0.0',
        'timestamp': DateTime.now().toIso8601String(),
        'app': 'My Billu - Full Backup',
        'items': appState.items.map((i) => i.toMap()).toList(),
        'customers': appState.customers.map((c) => c.toMap()).toList(),
        'bills': appState.bills.map((b) => b.toMap()).toList(),
        'purchases': appState.purchases.map((p) => p.toMap()).toList(),
        'quotations': appState.quotations.map((q) => q.toMap()).toList(),
        'expenses': appState.expenses.map((e) => e.toMap()).toList(),
        'creditNotes': appState.creditNotes.map((c) => c.toMap()).toList(),
        'purchaseReturns': appState.purchaseReturns.map((p) => p.toMap()).toList(),
        'suppliers': appState.suppliers.map((s) => s.toMap()).toList(),
        'recurringBills': appState.recurringBills.map((r) => r.toMap()).toList(),
        'cashBookEntries': appState.cashBookEntries.map((e) => e.toMap()).toList(),
        'bankAccounts': appState.bankAccounts.map((a) => a.toMap()).toList(),
        'settings': settings,
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      final bytes = utf8.encode(jsonStr);

      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'My_Billu_Sync_${DateTime.now().day.toString().padLeft(2, '0')}_${DateTime.now().month.toString().padLeft(2, '0')}_${DateTime.now().year}.json',
        mimeType: 'application/json',
      );
      await Share.shareXFiles([xFile],
        subject: 'My Billu Backup',
        text: 'My Billu data backup - Open this file in My Billu app to sync.');

      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
            Text('Backup shared successfully!')]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Share error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  // ===== LAN SYNC =====
  final _lanIpCtrl = TextEditingController();
  bool _lanSharing = false;
  bool _lanSyncing = false;
  String? _myIp;

  Widget _buildLanSyncCard(BuildContext context) {
    if (kIsWeb) {
      return GlassCard(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.wifi, size: 22, color: Colors.white)),
            const SizedBox(width: 12),
            Text('LAN Sync', style: Theme.of(context).textTheme.titleLarge),
          ]),
          const SizedBox(height: 12),
          Text('LAN Sync is available on Android & Windows only.',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        ]));
    }

    return GlassCard(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.wifi, size: 22, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LAN Sync', style: Theme.of(context).textTheme.titleLarge),
            Text('Sync over WiFi without internet', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          ])),
          if (_lanSharing)
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 8, color: AppColors.success), SizedBox(width: 4),
                Text('Sharing', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
              ])),
        ]),
        const SizedBox(height: 16),

        // This Device section
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.smartphone, size: 16, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 8),
              const Text('This Device', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              if (_myIp != null)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
                  child: Text('IP: $_myIp', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _lanSharing ? AppColors.error : const Color(0xFFFF6B6B),
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => _lanSharing ? _stopSharing() : _startSharing(context),
              icon: Icon(_lanSharing ? Icons.stop : Icons.wifi_tethering, size: 18),
              label: Text(_lanSharing ? 'Stop Sharing' : 'Start Sharing (other device can sync from this)'),
            )),
          ])),

        const SizedBox(height: 12),

        // Connect to other device
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFF8E53).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF8E53).withValues(alpha: 0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.sync, size: 16, color: Color(0xFFFF8E53)),
              SizedBox(width: 8),
              Text('Sync from Another Device', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _lanIpCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Enter IP Address',
                hintText: '192.168.1.100',
                prefixIcon: const Icon(Icons.language, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save, size: 18),
                  tooltip: 'Save IP',
                  onPressed: () async {
                    final appState = context.read<AppState>();
                    await appState.saveSetting('lan_sync_ip', _lanIpCtrl.text.trim());
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('IP address saved!'),
                      backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                  }),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8E53),
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _lanSyncing ? null : () => _syncFromLan(context),
              icon: _lanSyncing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync, size: 18),
              label: Text(_lanSyncing ? 'Syncing...' : 'Sync Now'),
            )),
          ])),

        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(8)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Both devices must be on same WiFi.\n1. Start Sharing on Device A\n2. Enter Device A\'s IP on Device B\n3. Tap Sync Now',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35), height: 1.5))),
          ])),
      ]));
  }

  Future<void> _startSharing(BuildContext context) async {
    final ip = await LanSyncService.getLocalIp();
    if (ip == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not find WiFi IP address. Make sure you\'re connected to WiFi.'),
        backgroundColor: AppColors.error));
      return;
    }

    final appState = context.read<AppState>();
    final settings = await appState.getAllSettings();
    final backup = {
      'version': '2.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'app': 'My Billu - LAN Sync',
      'items': appState.items.map((i) => i.toMap()).toList(),
      'customers': appState.customers.map((c) => c.toMap()).toList(),
      'bills': appState.bills.map((b) => b.toMap()).toList(),
      'purchases': appState.purchases.map((p) => p.toMap()).toList(),
      'quotations': appState.quotations.map((q) => q.toMap()).toList(),
      'expenses': appState.expenses.map((e) => e.toMap()).toList(),
      'creditNotes': appState.creditNotes.map((c) => c.toMap()).toList(),
      'purchaseReturns': appState.purchaseReturns.map((p) => p.toMap()).toList(),
      'suppliers': appState.suppliers.map((s) => s.toMap()).toList(),
      'recurringBills': appState.recurringBills.map((r) => r.toMap()).toList(),
      'cashBookEntries': appState.cashBookEntries.map((e) => e.toMap()).toList(),
      'bankAccounts': appState.bankAccounts.map((a) => a.toMap()).toList(),
      'settings': settings,
    };

    final ok = await LanSyncService.startServer(backup);
    setState(() { _lanSharing = ok; _myIp = ip; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '📡 Sharing on $ip — Enter this IP on the other device' : '❌ Failed to start sharing'),
      backgroundColor: ok ? AppColors.success : AppColors.error));
  }

  void _stopSharing() {
    LanSyncService.stopServer();
    setState(() => _lanSharing = false);
  }

  Future<void> _syncFromLan(BuildContext context) async {
    final ip = _lanIpCtrl.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter the IP address of the other device'),
        backgroundColor: AppColors.error));
      return;
    }

    setState(() => _lanSyncing = true);

    // Ping first
    final reachable = await LanSyncService.ping(ip);
    if (!reachable) {
      setState(() => _lanSyncing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cannot reach $ip — Make sure both devices are on same WiFi and sharing is started'),
        backgroundColor: AppColors.error));
      return;
    }

    // Download backup
    final data = await LanSyncService.downloadFrom(ip);
    setState(() => _lanSyncing = false);
    if (data == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to download backup'), backgroundColor: AppColors.error));
      return;
    }

    if (!mounted) return;

    // Confirm
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.sync, color: Color(0xFFFF8E53)), SizedBox(width: 10), Text('Restore LAN Backup?')]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('From: $ip', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Items: ${(data['items'] as List?)?.length ?? 0}'),
        Text('Customers: ${(data['customers'] as List?)?.length ?? 0}'),
        Text('Bills: ${(data['bills'] as List?)?.length ?? 0}'),
        Text('Settings: ${(data['settings'] as Map?)?.length ?? 0} keys'),
        if (data['timestamp'] != null) ...[
          const SizedBox(height: 8),
          Text('Backup time: ${data['timestamp']}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8E53)),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Sync Now')),
      ],
    ));
    if (confirm != true || !mounted) return;

    // Restore all data
    final appState = context.read<AppState>();
    if (data['items'] != null) { for (final m in data['items']) { try { await appState.addItem(Item.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['customers'] != null) { for (final m in data['customers']) { try { await appState.addCustomer(Customer.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['bills'] != null) { for (final m in data['bills']) { try { await appState.createBill(Bill.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['purchases'] != null) { for (final m in data['purchases']) { try { await appState.createPurchase(Purchase.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['quotations'] != null) { for (final m in data['quotations']) { try { await appState.addQuotation(Quotation.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['expenses'] != null) { for (final m in data['expenses']) { try { await appState.addExpense(Expense.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['creditNotes'] != null) { for (final m in data['creditNotes']) { try { await appState.addCreditNote(CreditNote.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['purchaseReturns'] != null) { for (final m in data['purchaseReturns']) { try { await appState.addPurchaseReturn(PurchaseReturn.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['suppliers'] != null) { for (final m in data['suppliers']) { try { await appState.addSupplier(Supplier.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['cashBookEntries'] != null) { for (final m in data['cashBookEntries']) { try { await appState.addCashBookEntry(CashBookEntry.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['bankAccounts'] != null) { for (final m in data['bankAccounts']) { try { await appState.addBankAccount(BankAccount.fromMap(Map<String, dynamic>.from(m))); } catch (_) {} } }
    if (data['settings'] != null) {
      final settings = (data['settings'] as Map<String, dynamic>);
      for (final entry in settings.entries) { await appState.saveSetting(entry.key, entry.value.toString()); }
    }
    await appState.loadAll();

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
        Text('LAN Sync complete! All data restored.')]),
      backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  // ===== BIOMETRIC AUTH =====
  Future<void> _checkBiometricAvailability() async {
    if (kIsWeb) return;
    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();
      if (mounted) setState(() => _biometricAvailable = canCheck || isSupported);
    } catch (_) {
      if (mounted) setState(() => _biometricAvailable = false);
    }
  }

  Widget _buildBiometricCard(BuildContext context) {
    if (!_biometricAvailable) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.fingerprint, size: 22, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Biometric Login', style: Theme.of(context).textTheme.titleLarge),
            Text('Use fingerprint or face to login', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
          ])),
          Switch(
            value: _biometricEnabled,
            activeColor: AppColors.success,
            onChanged: (value) => value ? _enableBiometric() : _disableBiometric(),
          ),
        ]),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _biometricEnabled
                ? AppColors.success.withValues(alpha: 0.08)
                : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(_biometricEnabled ? Icons.check_circle : Icons.info_outline, size: 18,
              color: _biometricEnabled ? AppColors.success : (isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(width: 10),
            Expanded(child: Text(
              _biometricEnabled
                  ? 'Biometric login is enabled. You can use fingerprint or face to login.'
                  : 'Enable biometric to skip password entry on supported devices.',
              style: TextStyle(fontSize: 12,
                color: _biometricEnabled ? AppColors.success : (isDark ? Colors.white38 : Colors.black38)))),
          ])),
      ]));
  }

  Future<void> _enableBiometric() async {
    try {
      final localAuth = LocalAuthentication();
      // Verify biometric first
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Verify your identity to enable biometric login',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (authenticated) {
        final appState = context.read<AppState>();
        await appState.saveSetting('biometric_enabled', 'true');
        setState(() => _biometricEnabled = true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.fingerprint, color: Colors.white), SizedBox(width: 10),
            Text('Biometric login enabled! 🔐')]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Biometric setup failed: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _disableBiometric() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.fingerprint, color: AppColors.warning), SizedBox(width: 10),
        Text('Disable Biometric?')]),
      content: const Text('You will need to enter your password every time you login.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Disable')),
      ],
    ));
    if (confirm == true) {
      final appState = context.read<AppState>();
      await appState.saveSetting('biometric_enabled', 'false');
      setState(() => _biometricEnabled = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Biometric login disabled'),
        backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  Widget _aboutRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]));
  }

  Widget _shortcutRow(String keys, String action) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
          child: Text(keys, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFamily: 'monospace', color: AppColors.primary)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(action, style: const TextStyle(fontSize: 13))),
      ]));
  }

  @override
  void dispose() {
    _bizNameCtrl.dispose();
    _bizAddressCtrl.dispose();
    _bizPhoneCtrl.dispose();
    _bizGstinCtrl.dispose();
    _bizLogoCtrl.dispose();
    _lanIpCtrl.dispose();
    LanSyncService.stopServer();
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
      final settings = await appState.getAllSettings();
      final backup = {
        'version': '2.0.0',
        'timestamp': DateTime.now().toIso8601String(),
        'app': 'My Billu - Full Backup',
        'items': appState.items.map((i) => i.toMap()).toList(),
        'customers': appState.customers.map((c) => c.toMap()).toList(),
        'bills': appState.bills.map((b) => b.toMap()).toList(),
        'purchases': appState.purchases.map((p) => p.toMap()).toList(),
        'quotations': appState.quotations.map((q) => q.toMap()).toList(),
        'expenses': appState.expenses.map((e) => e.toMap()).toList(),
        'creditNotes': appState.creditNotes.map((c) => c.toMap()).toList(),
        'purchaseReturns': appState.purchaseReturns.map((p) => p.toMap()).toList(),
        'suppliers': appState.suppliers.map((s) => s.toMap()).toList(),
        'recurringBills': appState.recurringBills.map((r) => r.toMap()).toList(),
        'cashBookEntries': appState.cashBookEntries.map((e) => e.toMap()).toList(),
        'bankAccounts': appState.bankAccounts.map((a) => a.toMap()).toList(),
        'settings': settings,
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      web_helper.downloadJson(jsonStr, 'My_Billu_Backup_${DateTime.now().day.toString().padLeft(2, '0')}_${DateTime.now().month.toString().padLeft(2, '0')}_${DateTime.now().year}.json');

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
          Text('Quotations: ${(data['quotations'] as List?)?.length ?? 0}'),
          Text('Expenses: ${(data['expenses'] as List?)?.length ?? 0}'),
          Text('Suppliers: ${(data['suppliers'] as List?)?.length ?? 0}'),
          Text('Settings: ${(data['settings'] as Map?)?.length ?? 0} keys'),
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

      // Restore items
      if (data['items'] != null) {
        for (final m in data['items']) {
          try { await appState.addItem(Item.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore customers
      if (data['customers'] != null) {
        for (final m in data['customers']) {
          try { await appState.addCustomer(Customer.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore bills
      if (data['bills'] != null) {
        for (final m in data['bills']) {
          try { await appState.createBill(Bill.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore purchases
      if (data['purchases'] != null) {
        for (final m in data['purchases']) {
          try { await appState.createPurchase(Purchase.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore quotations
      if (data['quotations'] != null) {
        for (final m in data['quotations']) {
          try { await appState.addQuotation(Quotation.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore expenses
      if (data['expenses'] != null) {
        for (final m in data['expenses']) {
          try { await appState.addExpense(Expense.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore credit notes
      if (data['creditNotes'] != null) {
        for (final m in data['creditNotes']) {
          try { await appState.addCreditNote(CreditNote.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore purchase returns
      if (data['purchaseReturns'] != null) {
        for (final m in data['purchaseReturns']) {
          try { await appState.addPurchaseReturn(PurchaseReturn.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore suppliers
      if (data['suppliers'] != null) {
        for (final m in data['suppliers']) {
          try { await appState.addSupplier(Supplier.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore cash book entries
      if (data['cashBookEntries'] != null) {
        for (final m in data['cashBookEntries']) {
          try { await appState.addCashBookEntry(CashBookEntry.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore bank accounts
      if (data['bankAccounts'] != null) {
        for (final m in data['bankAccounts']) {
          try { await appState.addBankAccount(BankAccount.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }
      // Restore settings (company name, GSTIN, logo, etc.)
      if (data['settings'] != null) {
        final settings = (data['settings'] as Map<String, dynamic>);
        for (final entry in settings.entries) {
          await appState.saveSetting(entry.key, entry.value.toString());
        }
      }

      await appState.loadAll();

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

  Widget _langChip(BuildContext context, String label, String code) {
    final isSelected = AppStrings.currentLanguage == code;
    return GestureDetector(
      onTap: () async {
        AppStrings.setLanguage(code);
        await context.read<AppState>().saveSetting('app_language', code);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          border: Border.all(color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6))),
      ),
    );
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

  Widget _importButton(BuildContext context, IconData icon, String label, String hint, VoidCallback onTap) {
    return SizedBox(
      width: 200,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          ]),
          const SizedBox(height: 4),
          Text(hint, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.35)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  void _showImportResult(BuildContext context, String type, int added, int total) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 10),
        Text('Imported $added / $total $type successfully'),
      ]),
      backgroundColor: added > 0 ? AppColors.success : AppColors.warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }
}
