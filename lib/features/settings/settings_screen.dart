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
import '../../core/database/database_helper.dart';
import '../../core/database/data_path_native.dart' if (dart.library.js_interop) '../../core/database/data_path_web.dart'
    as data_path;
import 'package:path/path.dart' as path_pkg;
import '../../core/utils/app_strings.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/excel_importer.dart';
import '../../core/utils/invoice_generator.dart';
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
import 'package:file_picker/file_picker.dart';
import '../../core/services/firebase_sync_service.dart';

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
  final _bizBankNameCtrl = TextEditingController();
  final _bizBankAccountCtrl = TextEditingController();
  final _bizBankIfscCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _thankYouMsgCtrl = TextEditingController();
  final _termsConditionsCtrl = TextEditingController();
  final _pdfSavePathCtrl = TextEditingController();
  bool _loaded = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _showItemDescription = false;
  bool _showSerialNumber = false;
  bool _featuresExpanded = false;
  bool _businessProfileExpanded = false;
  bool _templateExpanded = false;
  final _invPrefixCtrl = TextEditingController(text: 'INV');
  final _invPatternCtrl = TextEditingController();
  final _invStartCtrl = TextEditingController(text: '1');

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
      _bizBankNameCtrl.text = settings['businessBankName'] ?? '';
      _bizBankAccountCtrl.text = settings['businessBankAccount'] ?? '';
      _bizBankIfscCtrl.text = settings['businessBankIfsc'] ?? '';
      _lanIpCtrl.text = settings['lan_sync_ip'] ?? '';
      _biometricEnabled = settings['biometric_enabled'] == 'true';
      _showItemDescription = settings['billing_show_description'] == 'true';
      _showSerialNumber = settings['billing_show_serial_number'] == 'true';
      _thankYouMsgCtrl.text = settings['pdf_thank_you_message'] ?? '';
      _termsConditionsCtrl.text = settings['pdf_terms_conditions'] ?? '';
    _pdfSavePathCtrl.text = settings['pdf_save_path'] ?? '';
      _invPrefixCtrl.text = settings['invoice_prefix'] ?? 'INV';
      _invPatternCtrl.text = settings['invoice_pattern'] ?? '';
      _invStartCtrl.text = settings['invoice_start_number'] ?? '1';
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
    await appState.saveSetting('businessBankName', _bizBankNameCtrl.text.trim());
    await appState.saveSetting('businessBankAccount', _bizBankAccountCtrl.text.trim());
    await appState.saveSetting('businessBankIfsc', _bizBankIfscCtrl.text.trim().toUpperCase());
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

          // ═══════════════════════════════════════════════════
          // FEATURES SECTION (collapsible)
          // ═══════════════════════════════════════════════════
          _buildCollapsibleSection(
            context,
            icon: Icons.widgets,
            title: 'Features',
            color: const Color(0xFF7C3AED),
            isExpanded: _featuresExpanded,
            onToggle: () => setState(() => _featuresExpanded = !_featuresExpanded),
            children: [
              // Cloud Sync Section
              _buildCloudSyncCard(context),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

              // Data Storage Path (Windows only)
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
                _buildDataPathCard(context),
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
                const SizedBox(height: 16),

              // Language Selection
              GlassCard(padding: const EdgeInsets.all(20), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.language, size: 22, color: AppColors.warning)),
                    const SizedBox(width: 12),
                    Text('Language / \u0c95\u0ca8\u0ccd\u0ca8\u0ca1', style: Theme.of(context).textTheme.titleLarge),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _langChip(context, 'English', 'en'),
                    const SizedBox(width: 12),
                    _langChip(context, '\u0c95\u0ca8\u0ccd\u0ca8\u0ca1', 'kn'),
                  ]),
                ])),
              const SizedBox(height: 16),

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
                    Text('Type barcode, HSN code or item name \u2192 press Search or Enter',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                  ]);
                })),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

              // Billing & Quotation Column Settings
              _buildBillingColumnsCard(context),
              const SizedBox(height: 16),

              // Invoice Number Pattern
              _buildInvoicePatternCard(context),
            ],
          ),
          const SizedBox(height: 32),

          // ═══════════════════════════════════════════════════
          // SETTINGS SECTION
          // ═══════════════════════════════════════════════════
          _sectionHeader(context, Icons.settings, 'Settings', AppColors.primary),
          const SizedBox(height: 16),

          // LAN Sync Section
          _buildLanSyncCard(context),
          const SizedBox(height: 16),

          _buildCollapsibleSection(
            context,
            icon: Icons.storefront,
            title: 'Business Profile',
            color: AppColors.primary,
            isExpanded: _businessProfileExpanded,
            onToggle: () => setState(() => _businessProfileExpanded = !_businessProfileExpanded),
            children: [
              GlassCard(padding: const EdgeInsets.all(20), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
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

                    // Bank Details section
                    Row(children: [
                      Container(padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.account_balance, size: 22, color: Color(0xFF10B981))),
                      const SizedBox(width: 12),
                      Text('Bank Details (for invoices)', style: Theme.of(context).textTheme.titleMedium),
                    ]),
                    const SizedBox(height: 12),
                    TextField(controller: _bizBankNameCtrl,
                      decoration: const InputDecoration(labelText: 'Bank Name', prefixIcon: Icon(Icons.account_balance_outlined),
                        hintText: 'e.g. AXIS BANK, Branch: YELLAPUR')),
                    const SizedBox(height: 14),
                    TextField(controller: _bizBankAccountCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Account Number', prefixIcon: Icon(Icons.credit_card_outlined),
                        hintText: 'e.g. 925020007361962')),
                    const SizedBox(height: 14),
                    TextField(controller: _bizBankIfscCtrl, textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'IFSC Code', prefixIcon: Icon(Icons.pin_outlined),
                        hintText: 'e.g. UTIB0006083')),
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
            ],
          ),
          const SizedBox(height: 20),

          // Financial Year
          _buildFinancialYearCard(context),
          const SizedBox(height: 20),

          // PDF Template & Paper Size
          _buildCollapsibleSection(
            context,
            icon: Icons.palette,
            title: 'Template Style',
            color: const Color(0xFF6366F1),
            isExpanded: _templateExpanded,
            onToggle: () => setState(() => _templateExpanded = !_templateExpanded),
            children: [
              _buildPdfTemplateCard(context),
            ],
          ),
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
          const SizedBox(height: 20),
          // About
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
              _aboutRow('Version', '6.0.0'),
              _aboutRow('Tax System', 'GST (India)'),
              _aboutRow('Currency', '\u20b9 INR'),
              if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.android))
                FutureBuilder<String?>(
                  future: context.read<AppState>().getSetting('app_expiry_date'),
                  builder: (ctx, snap) {
                    final expiryStr = snap.data ?? 'Not set';
                    final expiryDate = DateTime.tryParse(expiryStr);
                    final isNearExpiry = expiryDate != null &&
                        expiryDate.difference(DateTime.now()).inDays < 30;
                    final isExpired = expiryDate != null &&
                        DateTime.now().isAfter(expiryDate);
                    return InkWell(
                      onTap: () => _showExpiryChangeDialog(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            Icon(Icons.schedule,
                              size: 16,
                              color: isExpired ? AppColors.error : isNearExpiry ? AppColors.warning : AppColors.primary),
                            const SizedBox(width: 8),
                            const Text('License Expiry', style: TextStyle(fontWeight: FontWeight.w500)),
                          ]),
                          Row(children: [
                            Text(expiryStr,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isExpired ? AppColors.error : isNearExpiry ? AppColors.warning : AppColors.success)),
                            const SizedBox(width: 4),
                            Icon(Icons.edit, size: 14,
                              color: Colors.white.withValues(alpha: 0.3)),
                          ]),
                        ]),
                      ),
                    );
                  }),
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
        ]),
      );
    });
  }

  bool _syncing = false;
  bool _autoSyncEnabled = false;
  bool _showSyncPassword = false;
  final _syncService = FirebaseSyncService();
  final _syncEmailCtrl = TextEditingController();
  final _syncPasswordCtrl = TextEditingController();
  late final Stream _authStream = _syncService.authStateChanges;

  Future<void> _emailSignIn(BuildContext context) async {
    final email = _syncEmailCtrl.text.trim();
    final password = _syncPasswordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter email and password'), backgroundColor: AppColors.warning));
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password must be at least 6 characters'), backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _syncing = true);
    try {
      final user = await _syncService.signInWithEmail(email, password);
      setState(() => _syncing = false);
      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 8),
            Text('Signed in as ${user.email}'),
          ]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      setState(() => _syncing = false);
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('wrong-password')) msg = 'Wrong password. Try again.';
        if (msg.contains('invalid-email')) msg = 'Invalid email address.';
        if (msg.contains('too-many-requests')) msg = 'Too many attempts. Try later.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5)));
      }
    }
  }

  Widget _buildCloudSyncCard(BuildContext context) {
    try {
      return StreamBuilder(
        stream: _authStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return GlassCard(padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.cloud_sync, color: Colors.white, size: 22)),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Firebase Cloud Sync', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ])),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
              ]));
          }
          if (snapshot.hasError) {
            return GlassCard(padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.cloud_off, color: Colors.white, size: 22)),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Firebase Cloud Sync', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Setup required - check Firebase configuration', style: TextStyle(fontSize: 12, color: Colors.orange)),
                  ])),
                ]),
              ]));
          }
        final user = _syncService.currentUser;
        final isSignedIn = user != null;

        return GlassCard(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.cloud_sync, size: 22, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Firebase Cloud Sync', style: Theme.of(context).textTheme.titleLarge),
                Text('Sync data across all your devices via Google',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
              ])),
            ]),
            const SizedBox(height: 16),

            if (!isSignedIn) ...[
              // Email + Password sign-in (works on all platforms)
              TextField(
                key: const ValueKey('sync_email_field'),
                controller: _syncEmailCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'your@email.com',
                  prefixIcon: const Icon(Icons.email, size: 18),
                  filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('sync_password_field'),
                controller: _syncPasswordCtrl,
                obscureText: !_showSyncPassword,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _syncing ? null : _emailSignIn(context),
                decoration: InputDecoration(
                  labelText: 'Password (min 6 chars)',
                  prefixIcon: const Icon(Icons.lock, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_showSyncPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _showSyncPassword = !_showSyncPassword),
                  ),
                  filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _syncing ? null : () => _emailSignIn(context),
                icon: _syncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login, size: 20),
                label: Text(_syncing ? 'Signing in...' : 'Sign In / Create Account'),
              )),
              const SizedBox(height: 8),
              Text('Use same email & password on all devices to sync',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
            ] else ...[
              // Signed-in user info
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2))),
                child: Row(children: [
                  CircleAvatar(radius: 18,
                    backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: user.photoURL == null ? Text(
                      (user.displayName ?? user.email ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)) : null),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.displayName ?? 'User', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(user.email ?? '', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                  ])),
                  IconButton(
                    tooltip: 'Sign Out',
                    icon: const Icon(Icons.logout, size: 20, color: AppColors.error),
                    onPressed: () async {
                      await _syncService.signOut();
                      setState(() => _autoSyncEnabled = false);
                    }),
                ])),
              const SizedBox(height: 14),

              // Last sync time
              FutureBuilder<DateTime?>(
                future: _syncService.getLastSyncTime(),
                builder: (ctx, snap) {
                  final lastSync = snap.data;
                  return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.schedule, size: 16, color: Colors.white.withValues(alpha: 0.4)),
                      const SizedBox(width: 8),
                      Text('Last sync: ', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                      Text(lastSync != null
                          ? DateFormat('dd MMM yyyy, hh:mm a').format(lastSync.toLocal())
                          : 'Never',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: lastSync != null ? AppColors.success : Colors.white.withValues(alpha: 0.4))),
                    ]));
                }),
              const SizedBox(height: 14),

              // Sync Now button + Auto-sync toggle
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _syncing ? null : () => _firebaseSyncNow(context),
                  icon: _syncing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync, size: 20),
                  label: Text(_syncing ? 'Syncing...' : 'Sync Now'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34A853),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _syncing ? null : () => _firebaseDownload(context),
                  icon: const Icon(Icons.cloud_download, size: 20),
                  label: const Text('Download'),
                )),
              ]),
              const SizedBox(height: 12),

              // Auto-sync toggle
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.autorenew, size: 18, color: _syncService.isAutoSyncActive ? AppColors.success : Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Auto-Sync', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Upload every 5 minutes', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35))),
                  ])),
                  Switch(
                    value: _syncService.isAutoSyncActive,
                    activeColor: AppColors.success,
                    onChanged: (v) {
                      final appState = context.read<AppState>();
                      if (v) {
                        _syncService.startAutoSync(appState);
                      } else {
                        _syncService.stopAutoSync();
                      }
                      setState(() {});
                    }),
                ])),
            ],
          ]));
      });
    } catch (e) {
      return GlassCard(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.cloud_off, color: Colors.white, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Firebase Cloud Sync', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text('Error: $e', style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ])),
          ]),
        ]));
    }
  }

  Future<void> _firebaseSyncNow(BuildContext context) async {
    setState(() => _syncing = true);
    try {
      final appState = context.read<AppState>();
      await _syncService.uploadData(appState);
      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.cloud_done, color: Colors.white, size: 18), SizedBox(width: 8),
            Text('Data uploaded to cloud successfully!')]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sync error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _firebaseDownload(BuildContext context) async {
    setState(() => _syncing = true);
    try {
      final data = await _syncService.downloadData();
      setState(() => _syncing = false);
      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No cloud data found. Upload first!'), backgroundColor: AppColors.warning));
        }
        return;
      }

      if (!mounted) return;
      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.cloud_download, color: AppColors.primary), SizedBox(width: 10), Text('Download Cloud Data?')]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This will ADD cloud data to your local data.', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Items: ${(data['items'] as List?)?.length ?? 0}'),
          Text('Customers: ${(data['customers'] as List?)?.length ?? 0}'),
          Text('Bills: ${(data['bills'] as List?)?.length ?? 0}'),
          Text('Purchases: ${(data['purchases'] as List?)?.length ?? 0}'),
          Text('Quotations: ${(data['quotations'] as List?)?.length ?? 0}'),
          Text('Expenses: ${(data['expenses'] as List?)?.length ?? 0}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Download & Restore')),
        ],
      ));

      if (confirm != true || !mounted) return;

      final appState = context.read<AppState>();
      // Reuse the same restore logic
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
        for (final entry in settings.entries) {
          try {
            await appState.saveSetting(entry.key, entry.value.toString());
          } catch (e) {
            debugPrint('Failed to restore setting ${entry.key}: $e');
          }
        }
        debugPrint('Restored ${settings.length} settings including: ${settings.keys.where((k) => k == "loginPassword" || k == "app_expiry_date" || k == "loginUsername").join(", ")}');
      }
      await appState.loadAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8),
            Text('Cloud data restored successfully!')]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download error: $e'), backgroundColor: AppColors.error));
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

  // ===== INVOICE NUMBER PATTERN =====
  Widget _buildInvoicePatternCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    // Generate preview
    String preview;
    final prefix = _invPrefixCtrl.text.isEmpty ? 'INV' : _invPrefixCtrl.text;
    final startNum = int.tryParse(_invStartCtrl.text) ?? 1;
    final pattern = _invPatternCtrl.text;
    if (pattern.isEmpty) {
      preview = '$prefix${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}-${startNum.toString().padLeft(4, '0')}';
    } else {
      preview = pattern
        .replaceAll('{PREFIX}', prefix)
        .replaceAll('{YYYY}', now.year.toString())
        .replaceAll('{YY}', now.year.toString().substring(2))
        .replaceAll('{MM}', now.month.toString().padLeft(2, '0'))
        .replaceAll('{DD}', now.day.toString().padLeft(2, '0'))
        .replaceAll('{NUM5}', startNum.toString().padLeft(5, '0'))
        .replaceAll('{NUM4}', startNum.toString().padLeft(4, '0'))
        .replaceAll('{NUM3}', startNum.toString().padLeft(3, '0'))
        .replaceAll('{NUM}', startNum.toString());
    }

    return GlassCard(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.numbers, size: 22, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Invoice Number Pattern', style: Theme.of(context).textTheme.titleLarge),
            Text('Customize your invoice numbering format',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black54)),
          ])),
        ]),
        const SizedBox(height: 16),
        // Preview
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient.scale(0.3),
            borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('PREVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.white60, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text(preview, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 16),
        // Prefix
        TextField(
          controller: _invPrefixCtrl,
          decoration: const InputDecoration(
            labelText: 'Prefix',
            hintText: 'e.g. INV, BILL, GST',
            prefixIcon: Icon(Icons.text_fields, size: 20)),
          onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        // Start number
        TextField(
          controller: _invStartCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Start Number',
            hintText: 'e.g. 1, 100, 1000',
            prefixIcon: Icon(Icons.pin, size: 20)),
          onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        // Custom pattern
        TextField(
          controller: _invPatternCtrl,
          decoration: InputDecoration(
            labelText: 'Custom Pattern (optional)',
            hintText: 'e.g. {PREFIX}/{YYYY}-{MM}/{NUM4}',
            prefixIcon: const Icon(Icons.pattern, size: 20),
            helperText: 'Leave empty for default: PREFIX + YYMM-NNNN',
            helperStyle: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26)),
          onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        // Preset patterns
        Text('Quick Patterns:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: isDark ? Colors.white54 : Colors.black54)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _patternChip('{PREFIX}{YY}{MM}-{NUM4}', 'INV2605-0001', isDark),
          _patternChip('{PREFIX}-{NUM4}', 'INV-0001', isDark),
          _patternChip('{PREFIX}/{YYYY}/{NUM5}', 'INV/2026/00001', isDark),
          _patternChip('{PREFIX}-{YYYY}{MM}{DD}-{NUM3}', 'INV-20260513-001', isDark),
          _patternChip('{PREFIX}/{MM}-{YY}/{NUM4}', 'INV/05-26/0001', isDark),
        ]),
        const SizedBox(height: 16),
        // Available tokens
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Available Tokens', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54)),
          children: [
            _tokenRow('{PREFIX}', 'Your invoice prefix', isDark),
            _tokenRow('{YYYY}', 'Full year (2026)', isDark),
            _tokenRow('{YY}', 'Short year (26)', isDark),
            _tokenRow('{MM}', 'Month (01-12)', isDark),
            _tokenRow('{DD}', 'Day (01-31)', isDark),
            _tokenRow('{NUM}', 'Number (no padding)', isDark),
            _tokenRow('{NUM3}', 'Number 3-digit (001)', isDark),
            _tokenRow('{NUM4}', 'Number 4-digit (0001)', isDark),
            _tokenRow('{NUM5}', 'Number 5-digit (00001)', isDark),
          ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () async {
            final appState = context.read<AppState>();
            await appState.saveSetting('invoice_prefix', _invPrefixCtrl.text.trim());
            await appState.saveSetting('invoice_pattern', _invPatternCtrl.text.trim());
            await appState.saveSetting('invoice_start_number', _invStartCtrl.text.trim());
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Row(children: [
                  Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
                  Text('Invoice pattern saved!')]),
                backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
            }
          },
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save Invoice Pattern'),
        )),
      ]));
  }

  Widget _patternChip(String pattern, String example, bool isDark) {
    final isActive = _invPatternCtrl.text == pattern;
    return InkWell(
      onTap: () => setState(() => _invPatternCtrl.text = pattern),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.15) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.primary : Colors.transparent)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pattern, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: isActive ? AppColors.primary : (isDark ? Colors.white54 : Colors.black45))),
          Text(example, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: isActive ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54))),
        ]),
      ),
    );
  }

  Widget _tokenRow(String token, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4)),
          child: Text(token, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'monospace'))),
        const SizedBox(width: 10),
        Text(desc, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
      ]),
    );
  }

  // ===== BILLING COLUMN SETTINGS =====
  Widget _buildBillingColumnsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.view_column, size: 22, color: AppColors.accent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Billing & Quotation Columns', style: Theme.of(context).textTheme.titleLarge),
            Text('Show/hide optional columns in billing and quotation',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black54)),
          ])),
        ]),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _showItemDescription,
          onChanged: (v) async {
            setState(() => _showItemDescription = v);
            final appState = context.read<AppState>();
            await appState.saveSetting('billing_show_description', v.toString());
          },
          title: const Text('Item Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text('Add a description field for each item in bills & quotations',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
          secondary: Icon(Icons.description, color: _showItemDescription ? AppColors.primary : (isDark ? Colors.white38 : Colors.black38)),
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const Divider(height: 8),
        SwitchListTile(
          value: _showSerialNumber,
          onChanged: (v) async {
            setState(() => _showSerialNumber = v);
            final appState = context.read<AppState>();
            await appState.saveSetting('billing_show_serial_number', v.toString());
          },
          title: const Text('Serial Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text('Add a serial number field for each item in bills & quotations',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
          secondary: Icon(Icons.qr_code, color: _showSerialNumber ? AppColors.primary : (isDark ? Colors.white38 : Colors.black38)),
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const Divider(height: 24),
        // Thank You Message
        Row(children: [
          Icon(Icons.favorite, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Thank You Message', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('Custom message shown at the bottom of invoices & quotations',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
          ])),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _thankYouMsgCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. Thank you for your business!',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.edit_note, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
          onChanged: (v) async {
            final appState = context.read<AppState>();
            await appState.saveSetting('pdf_thank_you_message', v.trim());
          },
        ),
        const Divider(height: 24),
        // Terms & Conditions
        Row(children: [
          const Icon(Icons.gavel, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('Printed on invoices & quotations PDF',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
          ])),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _termsConditionsCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g. Goods once sold cannot be taken back.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 36), child: Icon(Icons.article_outlined, size: 20)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
          onChanged: (v) async {
            final appState = context.read<AppState>();
            await appState.saveSetting('pdf_terms_conditions', v.trim());
          },
        ),
        const Divider(height: 24),
        // PDF Save Path
        Row(children: [
          const Icon(Icons.folder_open, color: Color(0xFF8B5CF6), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PDF Save Folder', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('Where invoices & quotation PDFs are saved',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
          ])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(
            controller: _pdfSavePathCtrl,
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Default: Documents folder',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.folder, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
          )),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _pickPdfSavePath(context),
            icon: const Icon(Icons.drive_file_move, size: 18),
            label: const Text('Browse'),
          ),
          if (_pdfSavePathCtrl.text.isNotEmpty) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.clear, size: 18, color: AppColors.error),
              tooltip: 'Reset to default',
              onPressed: () async {
                final appState = context.read<AppState>();
                await appState.saveSetting('pdf_save_path', '');
                setState(() => _pdfSavePathCtrl.text = '');
              },
            ),
          ],
        ]),
      ]));
  }
  // ===== PDF SAVE PATH PICKER =====
  Future<void> _pickPdfSavePath(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Folder selection not available on web. PDFs will download automatically.')));
      return;
    }
    try {
      final selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select PDF Save Folder',
      );
      if (selectedDir != null && context.mounted) {
        final appState = context.read<AppState>();
        await appState.saveSetting('pdf_save_path', selectedDir);
        setState(() => _pdfSavePathCtrl.text = selectedDir);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 8),
              Expanded(child: Text('PDF save path: $selectedDir', overflow: TextOverflow.ellipsis)),
            ]),
            backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error picking folder: $e'), backgroundColor: AppColors.error));
      }
    }
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

  void _showExpiryChangeDialog(BuildContext context) {
    final pwdCtrl = TextEditingController();
    showDialog(context: context, builder: (dCtx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.lock, color: AppColors.warning, size: 22),
        SizedBox(width: 10),
        Text('Master Password Required'),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Enter master password to change expiry date.',
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
        const SizedBox(height: 16),
        TextField(
          controller: pwdCtrl,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Master password',
            prefixIcon: const Icon(Icons.key),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () async {
            if (pwdCtrl.text == AppConstants.masterPassword) {
              Navigator.pop(dCtx);
              // Show date picker
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2099),
                helpText: 'SET NEW EXPIRY DATE',
              );
              if (picked != null && context.mounted) {
                final newExpiry = picked.toIso8601String().split('T').first;
                await context.read<AppState>().saveSetting('app_expiry_date', newExpiry);
                if (context.mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 10),
                      Text('Expiry date updated to: $newExpiry'),
                    ]),
                    backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                }
              }
            } else {
              if (dCtx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Invalid master password!'),
                  backgroundColor: AppColors.error));
              }
            }
          },
          child: const Text('Verify & Change'),
        ),
      ],
    ));
  }

  Widget _aboutRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]));
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: Colors.white)),
        const SizedBox(width: 12),
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ]),
      const SizedBox(height: 8),
      Container(height: 3, width: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.2)]),
          borderRadius: BorderRadius.circular(2))),
    ]);
  }

  Widget _buildCollapsibleSection(BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Clickable header
      InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              Text(isExpanded ? 'Tap to collapse' : 'Tap to expand',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
            ])),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(Icons.keyboard_arrow_down, color: color, size: 28)),
          ]),
        ),
      ),
      // Animated content
      AnimatedCrossFade(
        firstChild: const SizedBox.shrink(),
        secondChild: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
        crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 300),
      ),
    ]);
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
    _bizBankNameCtrl.dispose();
    _bizBankAccountCtrl.dispose();
    _bizBankIfscCtrl.dispose();
    _thankYouMsgCtrl.dispose();
    _termsConditionsCtrl.dispose();
    _pdfSavePathCtrl.dispose();
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

  Widget _buildFinancialYearCard(BuildContext context) {
    return FutureBuilder<String?>(
      future: context.read<AppState>().getSetting('financial_year'),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final defaultFYStart = now.month >= 4 ? now.year : now.year - 1;
        final defaultFY = '$defaultFYStart-${(defaultFYStart + 1).toString().substring(2)}';
        final currentFY = snapshot.data ?? defaultFY;

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.date_range, color: Color(0xFFFBBF24), size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Financial Year', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Indian FY runs April to March', style: TextStyle(fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
              ])),
            ]),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFFBBF24).withValues(alpha: 0.1), const Color(0xFFF59E0B).withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.calendar_today, color: Color(0xFFFBBF24), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Current Financial Year', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('FY $currentFY', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFBBF24))),
                ])),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBBF24),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _showFYPickerDialog(context, currentFY),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Change', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  void _showFYPickerDialog(BuildContext context, String currentFY) {
    final appState = context.read<AppState>();
    final now = DateTime.now();
    final currentFYStart = now.month >= 4 ? now.year : now.year - 1;
    final fyOptions = List.generate(8, (i) {
      final y = currentFYStart - 5 + i;
      return '$y-${(y + 1).toString().substring(2)}';
    });

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.date_range, color: Color(0xFFFBBF24)),
        SizedBox(width: 10),
        Text('Change Financial Year'),
      ]),
      content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...fyOptions.map((fy) {
          final isSelected = fy == currentFY;
          final isCurrentReal = fy == '$currentFYStart-${(currentFYStart + 1).toString().substring(2)}';
          return Padding(padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                await appState.saveSetting('financial_year', fy);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Financial Year changed to FY $fy'),
                    backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFBBF24).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? const Color(0xFFFBBF24) : Colors.grey.withValues(alpha: 0.2))),
                child: Row(children: [
                  Icon(Icons.calendar_month, size: 18,
                    color: isSelected ? const Color(0xFFFBBF24) : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(child: Text('FY $fy', style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFFFBBF24) : null))),
                  if (isSelected)
                    const Icon(Icons.check_circle, size: 18, color: Color(0xFFFBBF24)),
                  if (isCurrentReal && !isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                      child: const Text('Current', style: TextStyle(fontSize: 9, color: Colors.grey))),
                ]),
              ),
            ));
        }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ],
    ));
  }

  Widget _buildPdfTemplateCard(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _loadPdfSettings(context),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final currentTemplate = data['pdf_template'] ?? 'modern';
        final currentSize = data['pdf_paper_size'] ?? 'a4';

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.picture_as_pdf, color: Color(0xFF6366F1), size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('PDF Invoice Template', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Choose template style and paper size for invoices',
                  style: TextStyle(fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
              ])),
            ]),
            const SizedBox(height: 20),

            // Paper Size Toggle
            Text('Paper Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 8),
            Row(children: [
              _paperSizeChip('a4', 'A4 (210×297mm)', Icons.description, currentSize, context),
              const SizedBox(width: 10),
              _paperSizeChip('a5', 'A5 (148×210mm)', Icons.note, currentSize, context),
            ]),
            const SizedBox(height: 20),

            // Template Selection
            Text('Template Style', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 10),

            // Template cards
            _templatePreviewCard(
              context: context,
              name: 'Modern',
              value: 'modern',
              selected: currentTemplate,
              icon: Icons.auto_awesome,
              color: const Color(0xFF6366F1),
              desc: 'Indigo accented, colored header badge, professional layout',
              features: ['Colored INVOICE badge', 'Modern table styling', 'Gradient accents'],
            ),
            const SizedBox(height: 10),
            _templatePreviewCard(
              context: context,
              name: 'Classic',
              value: 'classic',
              selected: currentTemplate,
              icon: Icons.account_balance,
              color: const Color(0xFF78716C),
              desc: 'Traditional bordered design with signature lines',
              features: ['Bordered header', 'Gold-toned totals', 'Signature lines'],
            ),
            const SizedBox(height: 10),
            _templatePreviewCard(
              context: context,
              name: 'Minimal',
              value: 'minimal',
              selected: currentTemplate,
              icon: Icons.remove_red_eye,
              color: const Color(0xFF3B82F6),
              desc: 'Clean and lightweight with blue accent line',
              features: ['Blue accent bar', 'Two-column layout', 'Spacious design'],
            ),
            const SizedBox(height: 10),
            _templatePreviewCard(
              context: context,
              name: 'GST Invoice',
              value: 'gstInvoice',
              selected: currentTemplate,
              icon: Icons.receipt,
              color: const Color(0xFFDC2626),
              desc: 'Traditional Indian GST Tax Invoice with full breakdown',
              features: ['GST split table', 'Amount in words', 'Signature & T&C'],
            ),
          ]),
        );
      },
    );
  }

  Future<Map<String, String?>> _loadPdfSettings(BuildContext context) async {
    final appState = context.read<AppState>();
    return {
      'pdf_template': await appState.getSetting('pdf_template'),
      'pdf_paper_size': await appState.getSetting('pdf_paper_size'),
    };
  }

  Widget _paperSizeChip(String value, String label, IconData icon, String selected, BuildContext context) {
    final isActive = selected == value;
    return Expanded(child: InkWell(
      onTap: () async {
        await context.read<AppState>().saveSetting('pdf_paper_size', value);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6366F1).withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF6366F1) : Colors.grey.withValues(alpha: 0.3),
            width: isActive ? 2 : 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: isActive ? const Color(0xFF6366F1) : Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFF6366F1) : null)),
          if (isActive) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle, size: 16, color: Color(0xFF6366F1)),
          ],
        ]),
      ),
    ));
  }

  Widget _templatePreviewCard({
    required BuildContext context,
    required String name,
    required String value,
    required String selected,
    required IconData icon,
    required Color color,
    required String desc,
    required List<String> features,
  }) {
    final isActive = selected == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () async {
        await context.read<AppState>().saveSetting('pdf_template', value);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Invoice template set to $name'),
            backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? color : Colors.grey.withValues(alpha: 0.2),
            width: isActive ? 2 : 1)),
        child: Row(children: [
          // Template icon
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isActive ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 14),
          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                color: isActive ? color : null)),
              if (isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text('Active', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))),
              ],
            ]),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: features.map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4)),
              child: Text(f, style: TextStyle(fontSize: 9,
                color: isDark ? Colors.white38 : Colors.black38)),
            )).toList()),
          ])),
          // Preview button
          IconButton(
            tooltip: 'Preview $name',
            onPressed: () => _previewTemplate(context, value),
            icon: Icon(Icons.visibility, size: 20, color: color),
          ),
          const SizedBox(width: 4),
          // Radio-style indicator
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isActive ? color : Colors.grey.withValues(alpha: 0.4), width: 2),
              color: isActive ? color : Colors.transparent),
            child: isActive ? const Icon(Icons.check, size: 14, color: Colors.white) : null),
        ]),
      ),
    );
  }

  void _previewTemplate(BuildContext context, String templateValue) async {
    final appState = context.read<AppState>();
    final settings = await appState.getAllSettings();
    final sizeStr = settings['pdf_paper_size'] ?? 'a4';
    final paperSize = sizeStr == 'a5' ? PaperSize.a5 : PaperSize.a4;

    InvoiceTemplate template;
    switch (templateValue) {
      case 'classic': template = InvoiceTemplate.classic; break;
      case 'minimal': template = InvoiceTemplate.minimal; break;
      case 'gstInvoice': template = InvoiceTemplate.gstInvoice; break;
      default: template = InvoiceTemplate.modern;
    }

    // Create a sample bill for preview
    final sampleBill = Bill(
      id: 'sample-preview',
      billNumber: settings['invoice_prefix'] != null ? '${settings['invoice_prefix']}-001' : 'INV-001',
      customerName: 'Rajesh Kumar',
      customerPhone: '9876543210',
      items: [
        BillItem(itemId: '1', itemName: 'Laptop HP Pavilion 15', unitPrice: 45000, quantity: 1, taxRate: 18, unit: 'pcs', description: '15.6" FHD, 8GB RAM, 512GB SSD', serialNumber: 'HP-2024-A7X91'),
        BillItem(itemId: '2', itemName: 'Wireless Mouse Logitech', unitPrice: 850, quantity: 2, taxRate: 18, unit: 'pcs', serialNumber: 'LG-M1001, LG-M1002'),
        BillItem(itemId: '3', itemName: 'USB-C Cable 1m', unitPrice: 250, quantity: 3, taxRate: 12, unit: 'pcs'),
      ],
      subtotal: 45000 + 1700 + 750,
      discount: 0,
      totalTax: (45000 * 0.18) + (1700 * 0.18) + (750 * 0.12),
      totalAmount: (45000 * 1.18) + (1700 * 1.18) + (750 * 1.12),
      paidAmount: 45000,
      paymentMethod: PaymentMethod.upi,
      status: BillStatus.partial,
      createdAt: DateTime.now(),
    );

    final logoBytes = InvoiceGenerator.parseLogoData(settings['businessLogoData']);
    final bytes = await InvoiceGenerator.generatePdfBytes(
      sampleBill,
      businessName: settings['businessName'] ?? 'My Billu',
      businessAddress: settings['businessAddress'] ?? 'Main Road, Yellapur 581359',
      businessPhone: settings['businessPhone'] ?? '9449831316',
      businessGstin: settings['businessGstin'] ?? '29ABCDE1234F1ZK',
      businessBankName: settings['businessBankName'] ?? 'AXIS BANK, Branch: YELLAPUR',
      businessBankAccount: settings['businessBankAccount'] ?? '925020007361962',
      businessBankIfsc: settings['businessBankIfsc'] ?? 'UTIB0006083',
      logoBytes: logoBytes,
      template: template,
      paperSize: paperSize,
    );

    if (!context.mounted) return;

    // Show in-app PDF preview dialog instead of system print dialog
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('Preview: ${templateValue[0].toUpperCase()}${templateValue.substring(1)} Template'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
            actions: [
              // Optional: allow printing from preview
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'Print',
                onPressed: () async {
                  await Printing.layoutPdf(
                    onLayout: (_) async => bytes,
                    name: 'Preview_${templateValue}_invoice',
                  );
                },
              ),
            ],
          ),
          body: PdfPreview(
            build: (_) => bytes,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            allowPrinting: false,
            allowSharing: false,
            pdfFileName: 'Preview_${templateValue}_invoice.pdf',
          ),
        ),
      ),
    );
  }

  Widget _buildDataPathCard(BuildContext context) {
    return StatefulBuilder(builder: (ctx, setCardState) {
      final currentPath = DatabaseHelper.dataPath ?? r'D:\My_billu\data';
      final pathCtrl = TextEditingController(text: currentPath);

      return GlassCard(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF047857)]),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.folder_open, size: 22, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Data Storage Path', style: Theme.of(context).textTheme.titleLarge),
              Text('Windows only — specify where database is stored',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
            ])),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: pathCtrl,
            decoration: InputDecoration(
              labelText: 'Data folder path',
              hintText: r'D:\My_billu\data',
              prefixIcon: const Icon(Icons.storage),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.folder, color: AppColors.primary),
                tooltip: 'Browse folder',
                onPressed: () async {
                  final selectedDir = await FilePicker.platform.getDirectoryPath(
                    dialogTitle: 'Select Data Storage Folder',
                    initialDirectory: pathCtrl.text.isNotEmpty ? pathCtrl.text : r'D:\',
                  );
                  if (selectedDir != null) {
                    pathCtrl.text = selectedDir;
                    setCardState(() {});
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Colors.amber),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'Current: $currentPath${data_path.pathSeparator}my_billu.db',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () async {
              final newPath = pathCtrl.text.trim();
              if (newPath.isEmpty) return;

              // Confirm change
              final confirmed = await showDialog<bool>(context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Change Data Path?'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.warning_amber, size: 48, color: Colors.amber),
                    const SizedBox(height: 12),
                    const Text('The app will restart database at the new location.\n\n'
                      'If you want to keep existing data, manually copy the database file to the new folder before changing.\n\n'
                      'New path:'),
                    const SizedBox(height: 8),
                    SelectableText(newPath, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                      onPressed: () => Navigator.pop(dCtx, true),
                      child: const Text('Change & Restart DB')),
                  ],
                ));

              if (confirmed != true || !context.mounted) return;

              try {
                // Save config, create dir, reinitialize DB
                await data_path.saveAndApplyDataPath(newPath);

                // Reload all data
                if (context.mounted) {
                  final appState = context.read<AppState>();
                  await appState.loadItems();
                  await appState.loadCustomers();
                  await appState.loadBills();
                  await appState.loadDashboardStats();

                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
                      Expanded(child: Text('Data path changed to: $newPath')),
                    ]),
                    backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                  setCardState(() {});
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save Data Path'),
          )),
        ]));
    });
  }
}


