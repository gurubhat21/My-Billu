import 'dart:convert';
import '../../main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/input_formatters.dart';
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
import '../../core/services/merge_sync_service.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'keyboard_shortcuts_screen.dart';
import 'import_export_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/firebase_sync_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/services/windows_firestore_service.dart';
import '../admin/admin_panel_screen.dart';
import 'year_close_screen.dart';
import '../../core/services/fy_service.dart';
import '../../core/services/device_id_service.dart';
import '../../core/services/tombstone_service.dart';

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
  final _bizUpiIdCtrl = TextEditingController();
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
  bool _fakeQuoteExpanded = false;
  bool _lanSyncExpanded = false;
  bool _themeExpanded = false;
  bool _unitsExpanded = false;
  bool _fakeQuoteEnabled = false;
  List<Map<String, dynamic>> _customUnits = [];
  final _fq1NameCtrl = TextEditingController();
  final _fq1PhoneCtrl = TextEditingController();
  final _fq1AddressCtrl = TextEditingController();
  final _fq1GstinCtrl = TextEditingController();
  final _fq2NameCtrl = TextEditingController();
  final _fq2PhoneCtrl = TextEditingController();
  final _fq2AddressCtrl = TextEditingController();
  final _fq2GstinCtrl = TextEditingController();
  final _invPrefixCtrl = TextEditingController(text: 'INV');
  final _invPatternCtrl = TextEditingController();
  final _invStartCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Safely decode a data URL (data:image/...;base64,...) to bytes
  Uint8List _decodeDataUrl(String dataUrl) {
    try {
      if (dataUrl.startsWith('data:')) {
        final commaIdx = dataUrl.indexOf(',');
        if (commaIdx != -1) {
          return base64Decode(dataUrl.substring(commaIdx + 1));
        }
      }
      return Uint8List(0);
    } catch (_) {
      return Uint8List(0);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final appState = context.read<AppState>();
      final settings = await appState.getAllSettings();
      if (!mounted) return;
      setState(() {
        _bizNameCtrl.text = settings['businessName'] ?? '';
        _bizAddressCtrl.text = settings['businessAddress'] ?? '';
        _bizPhoneCtrl.text = settings['businessPhone'] ?? '';
        _bizGstinCtrl.text = settings['businessGstin'] ?? '';
        _bizLogoCtrl.text = settings['businessLogo'] ?? '';
        _bizBankNameCtrl.text = settings['businessBankName'] ?? '';
        _bizBankAccountCtrl.text = settings['businessBankAccount'] ?? '';
        _bizBankIfscCtrl.text = settings['businessBankIfsc'] ?? '';
        _bizUpiIdCtrl.text = settings['businessUpiId'] ?? '';
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
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
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
    await appState.saveSetting('businessUpiId', _bizUpiIdCtrl.text.trim());
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
              Builder(builder: (ctx) {
                try {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                child: Text(((s['name'] as String?)?.isNotEmpty == true ? (s['name'] as String)[0] : '?').toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))),
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
                  ]);
                } catch (e) {
                  return GlassCard(padding: const EdgeInsets.all(20), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                        SizedBox(width: 12),
                        Expanded(child: Text('Features could not load', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                      ]),
                      const SizedBox(height: 8),
                      Text('Error: $e', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                    ]));
                }
              }),
            ],
          ),
          const SizedBox(height: 32),



          // LAN Sync Section (Collapsible)
          _buildCollapsibleSection(
            context,
            icon: Icons.wifi,
            title: 'LAN Sync',
            color: const Color(0xFFFF6B6B),
            isExpanded: _lanSyncExpanded,
            onToggle: () => setState(() => _lanSyncExpanded = !_lanSyncExpanded),
            children: [
              _buildLanSyncCard(context),
            ],
          ),
          const SizedBox(height: 16),

          // App Theme Section
          _buildCollapsibleSection(
            context,
            icon: Icons.dark_mode,
            title: 'App Theme',
            color: const Color(0xFFF59E0B),
            isExpanded: _themeExpanded,
            onToggle: () => setState(() => _themeExpanded = !_themeExpanded),
            children: [
              _buildThemeCard(context),
            ],
          ),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
                    const SizedBox(height: 14),
                    TextField(controller: _bizGstinCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
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
                    const SizedBox(height: 14),
                    TextField(controller: _bizUpiIdCtrl,
                      decoration: const InputDecoration(labelText: 'UPI ID (for QR on invoice)', prefixIcon: Icon(Icons.qr_code),
                        hintText: 'e.g. business@upi')),
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
                          if (logoData != null && logoData.isNotEmpty && _decodeDataUrl(logoData).isNotEmpty)
                            Center(child: Container(
                              width: 80, height: 80, margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2)),
                              child: ClipRRect(borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _decodeDataUrl(logoData),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40))),
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

                    // Seal & Signature section
                    Row(children: [
                      Container(padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.draw, size: 22, color: AppColors.accent)),
                      const SizedBox(width: 12),
                      Text('Seal & Signature', style: Theme.of(context).textTheme.titleMedium),
                    ]),
                    const SizedBox(height: 8),
                    Text('This will appear on your invoices in the signature area', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                    const SizedBox(height: 12),
                    FutureBuilder<String?>(
                      future: context.read<AppState>().getSetting('businessSealData'),
                      builder: (ctx, snap) {
                        final sealData = snap.data;
                        return Column(children: [
                          if (sealData != null && sealData.isNotEmpty && _decodeDataUrl(sealData).isNotEmpty)
                            Center(child: Container(
                              width: 120, height: 80, margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2)),
                              child: ClipRRect(borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _decodeDataUrl(sealData),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40))),
                            )),
                          Row(children: [
                            Expanded(child: OutlinedButton.icon(
                              onPressed: () async {
                                final dataUrl = await web_helper.triggerImageUpload();
                                if (dataUrl != null) {
                                  final appState = context.read<AppState>();
                                  await appState.saveSetting('businessSealData', dataUrl);
                                  setState(() {});
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: const Row(children: [
                                      Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
                                      Text('Seal/Signature uploaded!')]),
                                    backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                                }
                              },
                              icon: const Icon(Icons.upload_file, size: 20),
                              label: const Text('Upload Seal/Signature (PNG/JPEG)'),
                            )),
                            if (sealData != null && sealData.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Remove Seal/Signature',
                                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                onPressed: () async {
                                  await context.read<AppState>().saveSetting('businessSealData', '');
                                  setState(() {});
                                }),
                            ],
                          ]),
                        ]);
                      }),
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

          // Units Management
          _buildCollapsibleSection(
            context,
            icon: Icons.straighten,
            title: 'Units Management',
            color: const Color(0xFF8B5CF6),
            isExpanded: _unitsExpanded,
            onToggle: () => setState(() => _unitsExpanded = !_unitsExpanded),
            children: [
              _buildUnitsManagementCard(context),
            ],
          ),
          const SizedBox(height: 20),

          // Fake Quote
          _buildCollapsibleSection(
            context,
            icon: Icons.description_outlined,
            title: 'Fake Quote',
            color: const Color(0xFFEF4444),
            isExpanded: _fakeQuoteExpanded,
            onToggle: () => setState(() => _fakeQuoteExpanded = !_fakeQuoteExpanded),
            children: [
              _buildFakeQuoteSettingsCard(context),
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

          // Account & Security (collapsible)
          GlassCard(padding: EdgeInsets.zero, child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              leading: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.admin_panel_settings, size: 22, color: AppColors.error)),
              title: Text('Account & Security', style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text('Username, password & factory reset', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
              children: [
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
                const SizedBox(height: 12),
                // Admin Panel
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () => _openAdminPanel(context),
                  icon: const Icon(Icons.admin_panel_settings, size: 20, color: AppColors.error),
                  label: const Text('Admin Panel (Subscriptions)'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                )),
                const SizedBox(height: 16),
                // Divider
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                const SizedBox(height: 16),
                // Factory Data Reset
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Danger Zone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
                ]),
                const SizedBox(height: 8),
                Text('Clear all app data permanently. This action cannot be undone.',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () => _showFactoryResetDialog(context),
                  icon: const Icon(Icons.delete_forever, size: 20),
                  label: const Text('Factory Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.2),
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )),
              ],
            ),
          )),
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
              const SizedBox(height: 8),
              // Device Bound section
              Builder(builder: (ctx) {
                final deviceService = DeviceIdService();
                final deviceId = deviceService.deviceId ?? 'N/A';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.link, size: 18, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text('Device Bound', style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.success)),
                      const SizedBox(width: 6),
                      const Text('✅', style: TextStyle(fontSize: 14)),
                    ]),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.smartphone, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Flexible(child: SelectableText(deviceId,
                        style: TextStyle(fontSize: 12, fontFamily: 'monospace',
                          color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.5))),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: deviceId));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('Device ID copied!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 2)));
                        },
                        child: Icon(Icons.copy, size: 14, color: Colors.white.withValues(alpha: 0.4))),
                    ]),
                  ]),
                );
              }),
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

  // ===== FACTORY DATA RESET =====
  Future<void> _showFactoryResetDialog(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    bool showPassword = false;
    String? error;

    // Step 1: Ask admin password
    final authenticated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.lock, color: AppColors.error, size: 24),
          SizedBox(width: 10),
          Text('Master Password Required'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter master password to proceed with factory reset.',
            style: TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: passwordCtrl,
            obscureText: !showPassword,
            decoration: InputDecoration(
              labelText: 'Master Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setDialogState(() => showPassword = !showPassword),
              ),
              errorText: error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (passwordCtrl.text == AppConstants.masterPassword) {
                Navigator.pop(ctx, true);
              } else {
                setDialogState(() => error = 'Wrong master password');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Verify'),
          ),
        ],
      )),
    );

    if (authenticated != true || !mounted) return;
    passwordCtrl.dispose();

    // Step 2: Show data selection dialog
    await _showResetSelectionDialog(context);
  }

  Future<void> _showResetSelectionDialog(BuildContext context) async {
    // Selectable data categories
    final selections = <String, bool>{
      'items': true,
      'customers': true,
      'bills': true,
      'purchases': true,
      'quotations': true,
      'expenses': true,
      'creditNotes': true,
      'purchaseReturns': true,
      'suppliers': true,
      'recurringBills': true,
      'cashBookEntries': true,
      'bankAccounts': true,
      'settings': false,  // Default OFF — risky to clear settings
      'cloudData': true,  // Clear cloud sync data too
    };

    final labels = {
      'items': 'Items / Products',
      'customers': 'Customers',
      'bills': 'Bills / Invoices',
      'purchases': 'Purchases',
      'quotations': 'Quotations',
      'expenses': 'Expenses',
      'creditNotes': 'Credit Notes',
      'purchaseReturns': 'Purchase Returns',
      'suppliers': 'Suppliers',
      'recurringBills': 'Recurring Bills',
      'cashBookEntries': 'Cash Book Entries',
      'bankAccounts': 'Bank Accounts',
      'settings': 'Settings (business info, preferences)',
      'cloudData': 'Cloud Sync Data (Firestore)',
    };

    final icons = {
      'items': Icons.inventory_2,
      'customers': Icons.people,
      'bills': Icons.receipt_long,
      'purchases': Icons.shopping_cart,
      'quotations': Icons.request_quote,
      'expenses': Icons.money_off,
      'creditNotes': Icons.note,
      'purchaseReturns': Icons.assignment_return,
      'suppliers': Icons.local_shipping,
      'recurringBills': Icons.repeat,
      'cashBookEntries': Icons.book,
      'bankAccounts': Icons.account_balance,
      'settings': Icons.settings,
      'cloudData': Icons.cloud_off,
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final selectedCount = selections.values.where((v) => v).length;
        final allSelected = selections.values.every((v) => v);

        return AlertDialog(
          title: Row(children: [
            const Icon(Icons.delete_forever, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            const Expanded(child: Text('Select Data to Clear')),
            // Select All / Deselect All
            TextButton(
              onPressed: () {
                final newVal = !allSelected;
                setDialogState(() {
                  for (final key in selections.keys) {
                    selections[key] = newVal;
                  }
                });
              },
              child: Text(allSelected ? 'Deselect All' : 'Select All',
                style: const TextStyle(fontSize: 12)),
            ),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: ListView(
              children: selections.keys.map((key) {
                final isCloud = key == 'cloudData';
                return CheckboxListTile(
                  value: selections[key],
                  onChanged: (val) => setDialogState(() => selections[key] = val ?? false),
                  title: Text(labels[key]!, style: TextStyle(
                    fontSize: 14,
                    color: isCloud ? AppColors.warning : null,
                  )),
                  secondary: Icon(icons[key], size: 20,
                    color: isCloud ? AppColors.warning : AppColors.primary),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.error,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: selectedCount == 0 ? null : () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: Text('Clear $selectedCount ${selectedCount == 1 ? 'item' : 'items'}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      }),
    );

    if (confirmed != true || !mounted) return;

    // Step 3: Final confirmation
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning, color: AppColors.error, size: 28),
          SizedBox(width: 10),
          Text('ARE YOU SURE?'),
        ]),
        content: const Text(
          'This will permanently delete the selected data.\n\n'
          'THIS CANNOT BE UNDONE.\n\n'
          'Make sure you have a backup before proceeding.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, Go Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yes, Delete Forever'),
          ),
        ],
      ),
    );

    if (finalConfirm != true || !mounted) return;

    // Execute reset
    await _executeFactoryReset(context, selections);
  }

  Future<void> _executeFactoryReset(BuildContext context, Map<String, bool> selections) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Resetting data...'),
      ]),
      backgroundColor: AppColors.error,
      duration: Duration(seconds: 30),
    ));

    try {
      final appState = context.read<AppState>();
      final db = appState.dbHelper;

      // Clear SQL tables
      if (selections['items'] == true) {
        final allItems = await db.getAllItems();
        for (final item in allItems) {
          await db.deleteItem(item.id);
        }
      }
      if (selections['customers'] == true) {
        final allCustomers = await db.getAllCustomers();
        for (final c in allCustomers) {
          await db.deleteCustomer(c.id);
        }
      }
      if (selections['bills'] == true) {
        final allBills = await db.getAllBills();
        for (final b in allBills) {
          await db.deleteBill(b.id);
        }
      }
      if (selections['purchases'] == true) {
        final allPurchases = await db.getAllPurchases();
        for (final p in allPurchases) {
          await db.deletePurchase(p.id);
        }
      }

      // Clear JSON-blob collections
      if (selections['quotations'] == true) {
        await db.setSetting('quotations_data', '[]');
      }
      if (selections['expenses'] == true) {
        await db.setSetting('expenses_data', '[]');
      }
      if (selections['creditNotes'] == true) {
        await db.setSetting('credit_notes_data', '[]');
      }
      if (selections['purchaseReturns'] == true) {
        await db.setSetting('purchase_returns_data', '[]');
      }
      if (selections['suppliers'] == true) {
        await db.setSetting('suppliers_data', '[]');
      }
      if (selections['recurringBills'] == true) {
        await db.setSetting('recurring_bills_data', '[]');
      }
      if (selections['cashBookEntries'] == true) {
        await db.setSetting('cash_book_entries', '[]');
      }
      if (selections['bankAccounts'] == true) {
        await db.setSetting('bank_accounts', '[]');
      }

      // Clear settings (except critical ones)
      if (selections['settings'] == true) {
        final allSettings = await db.getAllSettings();
        const keepKeys = {
          'loginPassword', 'loginUsername', 'staff_accounts',
          'app_password', 'app_expiry_date', 'subscription_status',
          'quotations_data', 'expenses_data', 'credit_notes_data',
          'purchase_returns_data', 'suppliers_data', 'recurring_bills_data',
          'cash_book_entries', 'bank_accounts', 'audit_log',
        };
        for (final key in allSettings.keys) {
          if (!keepKeys.contains(key)) {
            await db.setSetting(key, '');
          }
        }
      }

      // Clear cloud sync data
      if (selections['cloudData'] == true) {
        try {
          if (defaultTargetPlatform == TargetPlatform.windows) {
            // Windows: clear via REST API
            await WindowsFirestoreService.deleteAllSyncData();
          } else {
            // Android: clear via Firebase SDK
            if (_syncService.isSignedIn) {
              await _syncService.deleteAllCloudData();
            }
          }
        } catch (e) {
          debugPrint('Cloud data clear error: $e');
        }
      }

      // Reload app
      await TombstoneService.clearAll();
      await appState.reloadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
            Text('Factory reset completed!'),
          ]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reset error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  bool _syncing = false;
  bool _autoSyncEnabled = false;
  bool _showSyncPassword = false;
  final _syncService = FirebaseSyncService();
  final _syncEmailCtrl = TextEditingController();
  final _syncPasswordCtrl = TextEditingController();
  Stream? _authStream;

  Stream? _getAuthStream() {
    try {
      _authStream ??= _syncService.authStateChanges;
      return _authStream;
    } catch (e) {
      return null;
    }
  }

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
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    // On Windows: fetch fresh status from Firestore so admin approval is reflected immediately
    // On Android: read from SharedPreferences (updated during checkSubscription at startup)
    return FutureBuilder<List<bool>>(
      future: () async {
        if (isWindows) {
          final email = await WindowsFirestoreService.getCachedEmail();
          if (email != null && email.isNotEmpty) {
            final status = await WindowsFirestoreService.refreshCloudSyncStatus(email);
            return [status['enabled'] ?? false, status['requested'] ?? false];
          }
        }
        return Future.wait([
          SubscriptionService().isCloudSyncEnabled(),
          SubscriptionService().isCloudSyncRequested(),
        ]);
      }(),
      builder: (context, snapshot) {
        final cloudSyncEnabled = snapshot.data?[0] ?? false;
        final cloudSyncRequested = snapshot.data?[1] ?? false;

        // If cloud sync is NOT enabled, show locked card with request button
        if (!cloudSyncEnabled) {
          return GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade600]),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.lock, size: 22, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Firebase Cloud Sync', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Premium feature — requires admin approval',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                ])),
              ]),
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                child: Row(children: [
                  Icon(
                    cloudSyncRequested ? Icons.hourglass_top : Icons.cloud_off,
                    size: 20,
                    color: cloudSyncRequested ? const Color(0xFFFF9800) : Colors.white38),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    cloudSyncRequested
                        ? 'Request sent! Waiting for admin approval...'
                        : 'Cloud sync allows you to sync data across devices via Google Firebase.',
                    style: TextStyle(
                      fontSize: 13,
                      color: cloudSyncRequested ? const Color(0xFFFF9800) : Colors.white54))),
                ])),
              const SizedBox(height: 14),
              if (!cloudSyncRequested)
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    try {
                      String? email;
                      if (isWindows) {
                        email = await WindowsFirestoreService.getCachedEmail();
                      } else {
                        email = await SubscriptionService().getCachedEmail();
                      }
                      if (email == null || email.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Please register first'), backgroundColor: AppColors.warning));
                        }
                        return;
                      }
                      if (isWindows) {
                        await WindowsFirestoreService.requestCloudSync(email);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('sub_cloud_sync_requested', true);
                      } else {
                        await SubscriptionService().requestCloudSync(email);
                      }
                      setState(() {});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Row(children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8),
                            Text('Cloud sync request sent to admin!')]),
                          backgroundColor: const Color(0xFF7C4DFF), behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error: $e'), backgroundColor: AppColors.error));
                      }
                    }
                  },
                  icon: const Icon(Icons.send, size: 20),
                  label: const Text('Request Cloud Sync'),
                ))
              else
                SizedBox(width: double.infinity, child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.hourglass_top, size: 18, color: Color(0xFFFF9800)),
                    SizedBox(width: 8),
                    Text('⏳ Request Pending', style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFFFF9800), fontSize: 14)),
                  ]),
                )),
            ]));
        }

        // Cloud sync IS enabled
        if (isWindows) {
          return _buildWindowsSyncCard(context);
        }

        // Android/other: show normal Firebase sync card
        return _buildCloudSyncCardEnabled(context);
      },
    );
  }

  Widget _buildWindowsSyncCard(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: WindowsFirestoreService.getSyncUser(),
      builder: (context, snapshot) {
        final syncUser = snapshot.data;
        final isSignedIn = syncUser?['uid'] != null && syncUser!['uid']!.isNotEmpty;

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
                const Text('Firebase Cloud Sync', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(isSignedIn ? 'Enabled ✓' : 'Sign in to sync',
                  style: TextStyle(fontSize: 12, color: isSignedIn ? const Color(0xFF4CAF50) : Colors.white54, fontWeight: FontWeight.w600)),
              ])),
            ]),
            const SizedBox(height: 16),

            if (!isSignedIn) ...[
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.15))),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Sign in with your Google account to sync data across all your devices.',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)))),
                ])),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _syncing ? null : () => _windowsGoogleSignIn(context),
                icon: _syncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Image.network('https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        width: 20, height: 20,
                        errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24, color: Color(0xFF4285F4))),
                label: Text(_syncing ? 'Signing in...' : 'Sign in with Google',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              )),
            ] else ...[
              // Signed-in user info
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2))),
                child: Row(children: [
                  CircleAvatar(radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      (syncUser?['email'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Signed In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(syncUser?['email'] ?? '', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                  ])),
                  IconButton(
                    tooltip: 'Sign Out',
                    icon: const Icon(Icons.logout, size: 20, color: AppColors.error),
                    onPressed: () async {
                      await WindowsFirestoreService.syncSignOut();
                      setState(() {});
                    }),
                ])),
              const SizedBox(height: 14),

              // Last sync time
              FutureBuilder<DateTime?>(
                future: WindowsFirestoreService.getLastSyncTime(),
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

              // Sync Now + Download buttons
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _syncing ? null : () => _windowsSyncNow(context),
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
                  onPressed: _syncing ? null : () => _windowsDownload(context),
                  icon: const Icon(Icons.cloud_download, size: 20),
                  label: const Text('Download'),
                )),
              ]),
            ],
          ]));
      });
  }

  Future<void> _windowsGoogleSignIn(BuildContext context) async {
    setState(() => _syncing = true);
    try {
      await WindowsFirestoreService.signInWithGoogle();
      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8),
            Text('Signed in successfully!')]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sign in error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _windowsSyncNow(BuildContext context) async {
    setState(() => _syncing = true);
    try {
      final appState = context.read<AppState>();
      final localSettings = await appState.getAllSettings();

      // Build local data
      final localData = <String, List<Map<String, dynamic>>>{
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
      };

      // Download cloud data for merge
      Map<String, dynamic>? cloudData;
      try {
        cloudData = await WindowsFirestoreService.downloadSyncData();
      } catch (_) {}

      // Merge cloud tombstones with local
      if (cloudData != null && cloudData['_tombstones'] != null) {
        await TombstoneService.mergeFromCloud(
          Map<String, dynamic>.from(cloudData['_tombstones'] as Map));
      }
      final allTombstones = await TombstoneService.getAll();

      // Merge each collection (use specialized merge for numbered collections)
      final mergedBackup = <String, dynamic>{};
      for (final key in localData.keys) {
        final cloudList = (cloudData?[key] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        switch (key) {
          case 'bills':
            mergedBackup[key] = MergeSyncService.mergeBills(localData[key]!, cloudList);
            break;
          case 'purchases':
            mergedBackup[key] = MergeSyncService.mergePurchases(localData[key]!, cloudList);
            break;
          case 'quotations':
            mergedBackup[key] = MergeSyncService.mergeQuotations(localData[key]!, cloudList);
            break;
          case 'creditNotes':
            mergedBackup[key] = MergeSyncService.mergeCreditNotes(localData[key]!, cloudList);
            break;
          case 'purchaseReturns':
            mergedBackup[key] = MergeSyncService.mergePurchaseReturns(localData[key]!, cloudList);
            break;
          default:
            mergedBackup[key] = MergeSyncService.mergeCollections(localData[key]!, cloudList);
        }
        // Filter out tombstoned records
        mergedBackup[key] = TombstoneService.filterDeleted(
            mergedBackup[key] as List<Map<String, dynamic>>,
            allTombstones[key] ?? {});
      }

      // Merge settings
      final cloudSettings = <String, String>{};
      if (cloudData?['settings'] != null) {
        final cs = cloudData!['settings'];
        if (cs is Map) {
          for (final e in cs.entries) {
            cloudSettings[e.key.toString()] = e.value.toString();
          }
        }
      }
      mergedBackup['settings'] = MergeSyncService.mergeSettings(localSettings, cloudSettings);

      // Include tombstones in upload
      final tombstones = await TombstoneService.toSerializable();
      mergedBackup['_tombstones'] = tombstones;

      // Upload merged data
      await WindowsFirestoreService.uploadSyncData(mergedBackup);

      // Import cloud-only records into local DB
      if (cloudData != null) {
        final db = appState.dbHelper;
        for (final key in localData.keys) {
          final mergedList = mergedBackup[key] as List<Map<String, dynamic>>;
          final localIds = localData[key]!.map((r) => r['id'].toString()).toSet();

          for (final record in mergedList) {
            final id = record['id']?.toString() ?? '';
            if (id.isNotEmpty && !localIds.contains(id) && !(allTombstones[key]?.contains(id) ?? false)) {
              // New from cloud — add locally
              switch (key) {
                case 'items':
                  await db.insertItem(Item.fromMap(record));
                  break;
                case 'customers':
                  await db.insertCustomer(Customer.fromMap(record));
                  break;
                case 'bills':
                  await db.insertBill(Bill.fromMap(record));
                  break;
                case 'purchases':
                  await db.insertPurchase(Purchase.fromMap(record));
                  break;
              }
            }
          }

          // Delete locally any records that were deleted on other devices
          final deletedIds = allTombstones[key] ?? {};
          for (final id in deletedIds) {
            if (localIds.contains(id)) {
              try {
                switch (key) {
                  case 'items': await db.deleteItem(id); break;
                  case 'customers': await db.deleteCustomer(id); break;
                  case 'bills': await db.deleteBill(id); break;
                  case 'purchases': await db.deletePurchase(id); break;
                }
              } catch (_) {}
            }
          }
        }

        // Update JSON-blob collections with merged data
        final jsonCollections = {
          'quotations': 'quotations_data', 'expenses': 'expenses_data',
          'creditNotes': 'credit_notes_data', 'purchaseReturns': 'purchase_returns_data',
          'suppliers': 'suppliers_data', 'recurringBills': 'recurring_bills_data',
          'cashBookEntries': 'cash_book_entries', 'bankAccounts': 'bank_accounts',
        };
        for (final entry in jsonCollections.entries) {
          final mergedList = mergedBackup[entry.key] as List<Map<String, dynamic>>;
          if (mergedList.length > (localData[entry.key]?.length ?? 0)) {
            await db.setSetting(entry.value, jsonEncode(mergedList));
          }
        }

        await appState.reloadAllData();
      }

      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.cloud_done, color: Colors.white, size: 18), SizedBox(width: 8),
            Text('Data synced & merged successfully!')]),
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

  Future<void> _windowsDownload(BuildContext context) async {
    setState(() => _syncing = true);
    try {
      final data = await WindowsFirestoreService.downloadSyncData();
      setState(() => _syncing = false);
      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No cloud data found. Upload first!'), backgroundColor: AppColors.warning));
        }
        return;
      }
      if (!mounted) return;
      // Use same download/restore flow as Android
      _firebaseDownloadRestore(context, data);
    } catch (e) {
      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _firebaseDownloadRestore(BuildContext context, Map<String, dynamic> data) async {
    final appState = context.read<AppState>();

    // Count what cloud has
    int cloudItems = (data['items'] as List?)?.length ?? 0;
    int cloudBills = (data['bills'] as List?)?.length ?? 0;
    int cloudCustomers = (data['customers'] as List?)?.length ?? 0;

    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.cloud_download, color: AppColors.primary), SizedBox(width: 10), Text('Merge Cloud Data?')]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Cloud data will be MERGED with your local data.\nNo data will be lost from either side.', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text('Cloud has: $cloudItems items, $cloudCustomers customers, $cloudBills bills'),
        Text('Local has: ${appState.items.length} items, ${appState.customers.length} customers, ${appState.bills.length} bills'),
        const SizedBox(height: 8),
        const Text('• New records from cloud will be added\n• Conflicts resolved by latest timestamp',
            style: TextStyle(fontSize: 12, color: Colors.white54)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Merge & Download')),
      ],
    ));

    if (confirm != true || !mounted) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Merging cloud data...'),
        ]),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 30),
      ));
    }

    final db = appState.dbHelper;

    // Merge cloud tombstones
    if (data['_tombstones'] != null) {
      await TombstoneService.mergeFromCloud(
        Map<String, dynamic>.from(data['_tombstones'] as Map));
    }
    final allTombstones = await TombstoneService.getAll();

    // Build local data maps for merge
    final localData = <String, List<Map<String, dynamic>>>{
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
    };

    // Merge settings (skip JSON-blob keys — they're handled below as collections)
    const skipSettingsKeys = {
      'quotations_data', 'expenses_data', 'credit_notes_data',
      'purchase_returns_data', 'suppliers_data', 'recurring_bills_data',
      'cash_book_entries', 'bank_accounts', 'audit_log',
    };

    if (data['settings'] != null) {
      final cloudSettings = (data['settings'] as Map<String, dynamic>);
      for (final entry in cloudSettings.entries) {
        if (skipSettingsKeys.contains(entry.key)) continue;
        try { await db.setSetting(entry.key, entry.value.toString()); } catch (_) {}
      }
    }

    // Merge SQL-table collections (use specialized merge for numbered ones)
    for (final key in ['items', 'customers', 'bills', 'purchases']) {
      if (data[key] == null) continue;
      final cloudList = (data[key] as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      List<Map<String, dynamic>> merged;
      switch (key) {
        case 'bills':
          merged = MergeSyncService.mergeBills(localData[key]!, cloudList);
          break;
        case 'purchases':
          merged = MergeSyncService.mergePurchases(localData[key]!, cloudList);
          break;
        default:
          merged = MergeSyncService.mergeCollections(localData[key]!, cloudList);
      }
      final localIds = localData[key]!.map((r) => r['id'].toString()).toSet();

      // Filter out tombstoned records from merged
      merged = TombstoneService.filterDeleted(merged, allTombstones[key] ?? {});

      for (final record in merged) {
        final id = record['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        if (!localIds.contains(id)) {
          // New from cloud — add locally
          try {
            switch (key) {
              case 'items': await db.insertItem(Item.fromMap(record)); break;
              case 'customers': await db.insertCustomer(Customer.fromMap(record)); break;
              case 'bills': await db.insertBill(Bill.fromMap(record)); break;
              case 'purchases': await db.insertPurchase(Purchase.fromMap(record)); break;
            }
          } catch (_) {}
        }
      }

      // Delete locally any records that were deleted on other devices
      final deletedIds = allTombstones[key] ?? {};
      for (final id in deletedIds) {
        if (localIds.contains(id)) {
          try {
            switch (key) {
              case 'items': await db.deleteItem(id); break;
              case 'customers': await db.deleteCustomer(id); break;
              case 'bills': await db.deleteBill(id); break;
              case 'purchases': await db.deletePurchase(id); break;
            }
          } catch (_) {}
        }
      }
    }

    // Merge JSON-blob collections
    final jsonCollections = {
      'quotations': 'quotations_data', 'expenses': 'expenses_data',
      'creditNotes': 'credit_notes_data', 'purchaseReturns': 'purchase_returns_data',
      'suppliers': 'suppliers_data', 'recurringBills': 'recurring_bills_data',
      'cashBookEntries': 'cash_book_entries', 'bankAccounts': 'bank_accounts',
    };

    for (final entry in jsonCollections.entries) {
      if (data[entry.key] == null) continue;
      final cloudList = (data[entry.key] as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      List<Map<String, dynamic>> merged;
      switch (entry.key) {
        case 'quotations':
          merged = MergeSyncService.mergeQuotations(localData[entry.key]!, cloudList);
          break;
        case 'creditNotes':
          merged = MergeSyncService.mergeCreditNotes(localData[entry.key]!, cloudList);
          break;
        case 'purchaseReturns':
          merged = MergeSyncService.mergePurchaseReturns(localData[entry.key]!, cloudList);
          break;
        default:
          merged = MergeSyncService.mergeCollections(localData[entry.key]!, cloudList);
      }
      // Filter tombstoned records from JSON-blob merge
      merged = TombstoneService.filterDeleted(merged, allTombstones[entry.key] ?? {});
      await db.setSetting(entry.value, jsonEncode(merged));
    }

    await appState.reloadAllData();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
          Text('Cloud data merged successfully!'),
        ]),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Widget _buildCloudSyncCardEnabled(BuildContext context) {
    try {
      final stream = _getAuthStream();
      if (stream == null) {
        return _buildFirebaseErrorCard();
      }
      return StreamBuilder(
        stream: stream,
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
                      ((user.displayName ?? user.email ?? '?').isNotEmpty ? (user.displayName ?? user.email ?? '?')[0] : '?').toUpperCase(),
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

  Widget _buildFirebaseErrorCard() {
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
            Text('Firebase not configured on this device', style: TextStyle(fontSize: 12, color: Colors.orange)),
          ])),
        ]),
      ]));
  }

  Future<void> _firebaseSyncNow(BuildContext context) async {
    setState(() => _syncing = true);
    try {
      final appState = context.read<AppState>();
      await _syncService.smartSync(appState);
      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.cloud_done, color: Colors.white, size: 18), SizedBox(width: 8),
            Text('Data synced & merged successfully!')]),
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

      // Show progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Restoring cloud data...'),
          ]),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 30),
        ));
      }

      final appState = context.read<AppState>();
      final db = appState.dbHelper;

      // Keys handled separately (not via settings restore)
      const skipSettingsKeys = {
        'quotations_data', 'expenses_data', 'credit_notes_data',
        'purchase_returns_data', 'suppliers_data', 'recurring_bills_data',
        'cash_book_entries', 'bank_accounts', 'audit_log',
      };

      // 1. Restore settings FIRST (includes business profile data)
      if (data['settings'] != null) {
        final settings = (data['settings'] as Map<String, dynamic>);
        for (final entry in settings.entries) {
          if (skipSettingsKeys.contains(entry.key)) continue;
          try { await db.setSetting(entry.key, entry.value.toString()); } catch (_) {}
        }
        debugPrint('Restored ${settings.length} settings');
      }

      // 2. Restore items (direct insert/replace)
      if (data['items'] != null) {
        for (final m in data['items']) {
          try { await db.insertItem(Item.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }

      // 3. Restore customers (direct insert/replace)
      if (data['customers'] != null) {
        for (final m in data['customers']) {
          try { await db.insertCustomer(Customer.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }

      // 4. Restore bills (direct insert/replace - no stock changes)
      if (data['bills'] != null) {
        for (final m in data['bills']) {
          try { await db.insertBill(Bill.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }

      // 5. Restore purchases (direct insert/replace - no stock changes)
      if (data['purchases'] != null) {
        for (final m in data['purchases']) {
          try { await db.insertPurchase(Purchase.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }

      // 6. Restore settings-based JSON data
      if (data['quotations'] != null) {
        await db.setSetting('quotations_data', jsonEncode(data['quotations']));
      }
      if (data['expenses'] != null) {
        await db.setSetting('expenses_data', jsonEncode(data['expenses']));
      }
      if (data['creditNotes'] != null) {
        await db.setSetting('credit_notes_data', jsonEncode(data['creditNotes']));
      }
      if (data['purchaseReturns'] != null) {
        await db.setSetting('purchase_returns_data', jsonEncode(data['purchaseReturns']));
      }
      if (data['suppliers'] != null) {
        await db.setSetting('suppliers_data', jsonEncode(data['suppliers']));
      }
      if (data['recurringBills'] != null) {
        await db.setSetting('recurring_bills_data', jsonEncode(data['recurringBills']));
      }
      if (data['cashBookEntries'] != null) {
        await db.setSetting('cash_book_entries', jsonEncode(data['cashBookEntries']));
      }
      if (data['bankAccounts'] != null) {
        await db.setSetting('bank_accounts', jsonEncode(data['bankAccounts']));
      }

      // 7. Reload everything
      await appState.loadAll();
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

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
      return GlassCard(padding: const EdgeInsets.all(20), child: Text(
        'LAN Sync is available on Android & Windows only.',
        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))));
    }

    return GlassCard(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_lanSharing)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 8, color: AppColors.success), SizedBox(width: 4),
              Text('Sharing Active', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
            ])),

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

  Widget _buildThemeCard(BuildContext context) {
    final currentThemeId = MyBilluApp.themeNotifier.value;
    final themes = AppTheme.allThemes;
    final palette = AppTheme.getPalette(currentThemeId);
    final isDark = palette.isDark;

    return GlassCard(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Choose your preferred color theme',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5))),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: themes.length,
          itemBuilder: (ctx, i) {
            final t = themes[i];
            final isSelected = currentThemeId == t.id;
            return GestureDetector(
              onTap: () async {
                MyBilluApp.themeNotifier.value = t.id;
                final appState = context.read<AppState>();
                await appState.saveSetting('app_theme', t.id);
                setState(() {});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? t.previewColor.withValues(alpha: 0.12) : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? t.previewColor : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                    width: isSelected ? 2.5 : 1),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // Color preview circle
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [t.previewColor, t.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(color: t.previewColor.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1),
                      ] : [],
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 18, color: AppTheme.contrastText(t.previewColor))
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(t.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? t.previewColor : (isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5)))),
                ]),
              ),
            );
          },
        ),
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
        Text('Purchases: ${(data['purchases'] as List?)?.length ?? 0}'),
        Text('Settings: ${(data['settings'] as Map?)?.length ?? 0} keys'),
        if (data['timestamp'] != null) ...[
          const SizedBox(height: 8),
          Text('Backup time: ${data['timestamp']}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
            SizedBox(width: 8),
            Expanded(child: Text('This will replace ALL existing data', style: TextStyle(fontSize: 12, color: AppColors.warning))),
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8E53)),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Sync Now')),
      ],
    ));
    if (confirm != true || !mounted) return;

    // Show progress
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Restoring data...'),
        ]),
        backgroundColor: Color(0xFFFF8E53),
        duration: Duration(seconds: 30),
      ));
    }

    // Restore using direct DB access
    try {
      final appState = context.read<AppState>();
      final db = appState.dbHelper;

      // Keys that are handled separately (not via settings restore)
      const skipSettingsKeys = {
        'quotations_data', 'expenses_data', 'credit_notes_data',
        'purchase_returns_data', 'suppliers_data', 'recurring_bills_data',
        'cash_book_entries', 'bank_accounts', 'audit_log',
      };

      // 1. Restore settings FIRST (includes business profile data)
      if (data['settings'] != null) {
        final settings = (data['settings'] as Map<String, dynamic>);
        for (final entry in settings.entries) {
          // Skip keys that we'll restore separately as JSON blobs
          if (skipSettingsKeys.contains(entry.key)) continue;
          await db.setSetting(entry.key, entry.value.toString());
        }
      }

      // 2. Restore items (direct insert/replace)
      if (data['items'] != null) {
        for (final m in data['items']) {
          try { await db.insertItem(Item.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }

      // 3. Restore customers (direct insert/replace)
      if (data['customers'] != null) {
        for (final m in data['customers']) {
          try { await db.insertCustomer(Customer.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }

      // 4. Restore bills (merge by createdAt - keep both devices' bills)
      if (data['bills'] != null) {
        for (final m in data['bills']) {
          try { await db.insertBill(Bill.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }

      // 5. Restore purchases (direct insert/replace)
      if (data['purchases'] != null) {
        for (final m in data['purchases']) {
          try { await db.insertPurchase(Purchase.fromMap(Map<String, dynamic>.from(m))); } catch (_) {}
        }
      }

      // 6. Restore settings-based data (quotations, expenses, etc.)
      if (data['quotations'] != null) {
        final json = jsonEncode(data['quotations']);
        await db.setSetting('quotations_data', json);
      }
      if (data['expenses'] != null) {
        final json = jsonEncode(data['expenses']);
        await db.setSetting('expenses_data', json);
      }
      if (data['creditNotes'] != null) {
        final json = jsonEncode(data['creditNotes']);
        await db.setSetting('credit_notes_data', json);
      }
      if (data['purchaseReturns'] != null) {
        final json = jsonEncode(data['purchaseReturns']);
        await db.setSetting('purchase_returns_data', json);
      }
      if (data['suppliers'] != null) {
        final json = jsonEncode(data['suppliers']);
        await db.setSetting('suppliers_data', json);
      }
      if (data['recurringBills'] != null) {
        final json = jsonEncode(data['recurringBills']);
        await db.setSetting('recurring_bills_data', json);
      }
      if (data['cashBookEntries'] != null) {
        final json = jsonEncode(data['cashBookEntries']);
        await db.setSetting('cash_book_entries', json);
      }
      if (data['bankAccounts'] != null) {
        final json = jsonEncode(data['bankAccounts']);
        await db.setSetting('bank_accounts', json);
      }

      // 7. Reload everything
      await appState.loadAll();
      await _loadSettings();
    } catch (e) {
      debugPrint('LAN restore error: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
          Text('LAN Sync complete! All data restored.')]),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
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

                // Also update Firestore so control app sees it
                try {
                  final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
                  if (isWindows) {
                    final email = await WindowsFirestoreService.getCachedEmail();
                    if (email != null && email.isNotEmpty) {
                      await WindowsFirestoreService.activateSubscription(email, picked);
                    }
                  } else {
                    final subService = SubscriptionService();
                    final email = await subService.getCachedEmail();
                    if (email != null && email.isNotEmpty) {
                      await subService.activateSubscription(email, picked);
                    }
                  }
                } catch (e) {
                  debugPrint('Firestore expiry update error: $e');
                }

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
      // Content - only build when expanded (no AnimatedCrossFade)
      if (isExpanded)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
    _bizUpiIdCtrl.dispose();
    _thankYouMsgCtrl.dispose();
    _termsConditionsCtrl.dispose();
    _pdfSavePathCtrl.dispose();
    _lanIpCtrl.dispose();
    LanSyncService.stopServer();
    super.dispose();
  }
  void _openAdminPanel(BuildContext context) {
    final pwdCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.admin_panel_settings, color: AppColors.error),
        SizedBox(width: 8),
        Text('Admin Access'),
      ]),
      content: TextField(
        controller: pwdCtrl,
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'Master Password',
          prefixIcon: const Icon(Icons.lock),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            if (pwdCtrl.text == AppConstants.masterPassword) {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AdminPanelScreen(),
              ));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Invalid password'), backgroundColor: AppColors.error));
            }
          },
          child: const Text('Open Admin Panel'),
        ),
      ],
    ));
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
    return Builder(
      builder: (context) {
        final currentFY = FYService.instance.activeFY;

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
            const SizedBox(height: 12),
            // Close Year button
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF59E0B),
                side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const YearCloseScreen()));
              },
              icon: const Icon(Icons.next_plan, size: 18),
              label: const Text('Close Year & Start New FY', style: TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
        );
      },
    );
  }

  void _showFYPickerDialog(BuildContext context, String currentFY) {
    final fys = FYService.instance.availableFYs;
    final activeFY = FYService.instance.activeFY;
    final calendarFY = FYService.getFYFromDate(DateTime.now());

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.date_range, color: Color(0xFFFBBF24)),
        SizedBox(width: 10),
        Text('Switch Financial Year'),
      ]),
      content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (fys.length <= 1)
          Padding(padding: const EdgeInsets.only(bottom: 12),
            child: Text('Only one FY available. Use "Close Year & Start New FY" to create a new FY.',
              style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)))),
        ...fys.reversed.map((fy) {
          final isActive = fy == activeFY;
          final isCalendarCurrent = fy == calendarFY;
          return Padding(padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                if (fy != activeFY) {
                  await FYService.instance.switchToFY(fy);
                  final appState = context.read<AppState>();
                  await appState.reloadAllData();
                  if (mounted) setState(() {});
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFFBBF24).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isActive ? const Color(0xFFFBBF24) : Colors.grey.withValues(alpha: 0.2))),
                child: Row(children: [
                  Icon(isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18, color: isActive ? const Color(0xFFFBBF24) : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(child: Text('FY $fy', style: TextStyle(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? const Color(0xFFFBBF24) : null))),
                  if (isActive)
                    const Icon(Icons.check_circle, size: 18, color: Color(0xFFFBBF24)),
                  if (isCalendarCurrent && !isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                      child: const Text('Current', style: TextStyle(fontSize: 9, color: AppColors.success))),
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
  Widget _buildFakeQuoteSettingsCard(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loadFakeQuoteSettings(context),
      builder: (context, snapshot) {
        return GlassCard(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.business, color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Fake Company Profiles', style: Theme.of(context).textTheme.titleLarge),
                Text('Configure 2 company profiles for fake quotations',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
              ])),
            ]),
            const SizedBox(height: 16),

            // Enable/Disable toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _fakeQuoteEnabled
                    ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _fakeQuoteEnabled
                    ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(children: [
                Icon(_fakeQuoteEnabled ? Icons.visibility : Icons.visibility_off,
                  size: 20, color: _fakeQuoteEnabled ? const Color(0xFFEF4444) : Colors.white54),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_fakeQuoteEnabled ? 'Fake Quote Enabled' : 'Fake Quote Disabled',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                      color: _fakeQuoteEnabled ? const Color(0xFFEF4444) : Colors.white54)),
                  Text(_fakeQuoteEnabled ? 'Visible in sidebar' : 'Hidden from sidebar',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                ])),
                Switch(
                  value: _fakeQuoteEnabled,
                  activeColor: const Color(0xFFEF4444),
                  onChanged: (v) async {
                    final appState = context.read<AppState>();
                    await appState.saveSetting('fake_quote_enabled', v ? 'true' : 'false');
                    setState(() => _fakeQuoteEnabled = v);
                  },
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Company 1
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Company 1', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFEF4444))),
                const SizedBox(height: 12),
                TextField(controller: _fq1NameCtrl,
                  decoration: InputDecoration(labelText: 'Company Name',
                    prefixIcon: const Icon(Icons.business, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: _fq1PhoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: 'Phone',
                      prefixIcon: const Icon(Icons.phone, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _fq1GstinCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    decoration: InputDecoration(labelText: 'GSTIN',
                      prefixIcon: const Icon(Icons.numbers, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: _fq1AddressCtrl,
                  decoration: InputDecoration(labelText: 'Address',
                    prefixIcon: const Icon(Icons.location_on, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              ])),
            const SizedBox(height: 16),

            // Company 2
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Company 2', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF3B82F6))),
                const SizedBox(height: 12),
                TextField(controller: _fq2NameCtrl,
                  decoration: InputDecoration(labelText: 'Company Name',
                    prefixIcon: const Icon(Icons.business, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: _fq2PhoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: 'Phone',
                      prefixIcon: const Icon(Icons.phone, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _fq2GstinCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    decoration: InputDecoration(labelText: 'GSTIN',
                      prefixIcon: const Icon(Icons.numbers, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: _fq2AddressCtrl,
                  decoration: InputDecoration(labelText: 'Address',
                    prefixIcon: const Icon(Icons.location_on, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              ])),
            const SizedBox(height: 16),

            // Save Button
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                final appState = context.read<AppState>();
                await appState.saveSetting('fake_company_1_name', _fq1NameCtrl.text.trim());
                await appState.saveSetting('fake_company_1_phone', _fq1PhoneCtrl.text.trim());
                await appState.saveSetting('fake_company_1_address', _fq1AddressCtrl.text.trim());
                await appState.saveSetting('fake_company_1_gstin', _fq1GstinCtrl.text.trim());
                await appState.saveSetting('fake_company_2_name', _fq2NameCtrl.text.trim());
                await appState.saveSetting('fake_company_2_phone', _fq2PhoneCtrl.text.trim());
                await appState.saveSetting('fake_company_2_address', _fq2AddressCtrl.text.trim());
                await appState.saveSetting('fake_company_2_gstin', _fq2GstinCtrl.text.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Fake company profiles saved!'),
                    backgroundColor: AppColors.success));
                }
              },
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Save Profiles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )),
          ]));
      });
  }

  Future<bool> _loadFakeQuoteSettings(BuildContext context) async {
    final appState = context.read<AppState>();
    final enabled = await appState.getSetting('fake_quote_enabled');
    _fakeQuoteEnabled = enabled == 'true';
    final n1 = await appState.getSetting('fake_company_1_name') ?? '';
    final p1 = await appState.getSetting('fake_company_1_phone') ?? '';
    final a1 = await appState.getSetting('fake_company_1_address') ?? '';
    final g1 = await appState.getSetting('fake_company_1_gstin') ?? '';
    final n2 = await appState.getSetting('fake_company_2_name') ?? '';
    final p2 = await appState.getSetting('fake_company_2_phone') ?? '';
    final a2 = await appState.getSetting('fake_company_2_address') ?? '';
    final g2 = await appState.getSetting('fake_company_2_gstin') ?? '';
    if (_fq1NameCtrl.text.isEmpty && n1.isNotEmpty) _fq1NameCtrl.text = n1;
    if (_fq1PhoneCtrl.text.isEmpty && p1.isNotEmpty) _fq1PhoneCtrl.text = p1;
    if (_fq1AddressCtrl.text.isEmpty && a1.isNotEmpty) _fq1AddressCtrl.text = a1;
    if (_fq1GstinCtrl.text.isEmpty && g1.isNotEmpty) _fq1GstinCtrl.text = g1;
    if (_fq2NameCtrl.text.isEmpty && n2.isNotEmpty) _fq2NameCtrl.text = n2;
    if (_fq2PhoneCtrl.text.isEmpty && p2.isNotEmpty) _fq2PhoneCtrl.text = p2;
    if (_fq2AddressCtrl.text.isEmpty && a2.isNotEmpty) _fq2AddressCtrl.text = a2;
    if (_fq2GstinCtrl.text.isEmpty && g2.isNotEmpty) _fq2GstinCtrl.text = g2;
    return true;
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
            const SizedBox(height: 10),
            _templatePreviewCard(
              context: context,
              name: 'Simple (No GST)',
              value: 'simple',
              selected: currentTemplate,
              icon: Icons.description,
              color: const Color(0xFF0D9488),
              desc: 'Clean bill without any GST/tax details',
              features: ['No GSTIN', 'No CGST/SGST', 'Simple totals'],
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
      case 'simple': template = InvoiceTemplate.simple; break;
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
    final sealBytes = InvoiceGenerator.parseLogoData(settings['businessSealData']);
    final bytes = await InvoiceGenerator.generatePdfBytes(
      sampleBill,
      businessName: settings['businessName'] ?? 'My Billu',
      businessAddress: settings['businessAddress'] ?? 'Main Road, Yellapur 581359',
      businessPhone: settings['businessPhone'] ?? '9449831316',
      businessGstin: settings['businessGstin'] ?? '29ABCDE1234F1ZK',
      businessBankName: settings['businessBankName'] ?? 'AXIS BANK, Branch: YELLAPUR',
      businessBankAccount: settings['businessBankAccount'] ?? '925020007361962',
      businessBankIfsc: settings['businessBankIfsc'] ?? 'UTIB0006083',
      businessUpiId: settings['businessUpiId'] ?? '',
      logoBytes: logoBytes, sealBytes: sealBytes,
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

  Future<void> _loadCustomUnits(BuildContext context) async {
    final appState = context.read<AppState>();
    final json = await appState.getSetting('custom_units');
    if (json != null && json.isNotEmpty) {
      try {
        _customUnits = List<Map<String, dynamic>>.from(jsonDecode(json) as List);
      } catch (_) {}
    }
  }

  Future<void> _saveCustomUnits(BuildContext context) async {
    final appState = context.read<AppState>();
    await appState.saveSetting('custom_units', jsonEncode(_customUnits));
  }

  Widget _buildUnitsManagementCard(BuildContext context) {
    return FutureBuilder(
      future: _loadCustomUnits(context),
      builder: (context, snapshot) {
        final defaultUnits = ['pcs', 'kg', 'ltr', 'mtr', 'box', 'set'];
        return GlassCard(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.straighten, color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Unit Configuration', style: Theme.of(context).textTheme.titleLarge),
                Text('Create composite units like box = 90 mtr',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
              ])),
              IconButton(
                onPressed: () => _showAddUnitDialog(context),
                icon: const Icon(Icons.add_circle, color: Color(0xFF8B5CF6), size: 28),
                tooltip: 'Add Custom Unit',
              ),
            ]),
            const SizedBox(height: 16),

            // Default units
            Text('Default Units', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: defaultUnits.map((u) =>
              Chip(
                label: Text(u, style: const TextStyle(fontWeight: FontWeight.w600)),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ).toList()),

            if (_customUnits.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Custom Units', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
              const SizedBox(height: 8),
              ..._customUnits.asMap().entries.map((entry) {
                final i = entry.key;
                final u = entry.value;
                final name = u['name'] as String? ?? '';
                final subUnit = u['subUnit'] as String? ?? '';
                final factor = (u['factor'] as num?)?.toDouble() ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.straighten, size: 16, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      if (subUnit.isNotEmpty && factor > 0)
                        Text('1 $name = ${factor.toStringAsFixed(factor == factor.roundToDouble() ? 0 : 2)} $subUnit',
                          style: TextStyle(fontSize: 12, color: const Color(0xFF8B5CF6), fontWeight: FontWeight.w600)),
                    ])),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                      onPressed: () async {
                        _customUnits.removeAt(i);
                        await _saveCustomUnits(context);
                        setState(() {});
                      },
                    ),
                  ]),
                );
              }),
            ],
          ],
        ));
      },
    );
  }

  void _showAddUnitDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final subUnitCtrl = TextEditingController();
    final factorCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.add, color: Color(0xFF8B5CF6), size: 20)),
        const SizedBox(width: 10),
        const Text('Add Custom Unit'),
      ]),
      content: SizedBox(width: 350, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Unit Name *', hintText: 'e.g. bundle, roll, carton',
            prefixIcon: Icon(Icons.label_outline))),
        const SizedBox(height: 14),
        Text('If this unit contains a sub-unit (optional):',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: subUnitCtrl,
            decoration: const InputDecoration(labelText: 'Contains (sub-unit)', hintText: 'e.g. mtr, pcs',
              prefixIcon: Icon(Icons.straighten, size: 18), isDense: true))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: factorCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity per unit', hintText: 'e.g. 90',
              prefixIcon: Icon(Icons.numbers, size: 18), isDense: true))),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Expanded(child: Text('Example: 1 box = 90 mtr\nPrice \u20b93200/box \u2192 \u20b935.55/mtr',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)))),
          ]),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unit name is required')));
              return;
            }
            // Check duplicate
            final allUnits = ['pcs', 'kg', 'ltr', 'mtr', 'box', 'set', ..._customUnits.map((u) => u['name'])];
            if (allUnits.contains(nameCtrl.text.trim().toLowerCase())) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unit already exists')));
              return;
            }
            _customUnits.add({
              'name': nameCtrl.text.trim().toLowerCase(),
              'subUnit': subUnitCtrl.text.trim().toLowerCase(),
              'factor': double.tryParse(factorCtrl.text) ?? 0,
            });
            await _saveCustomUnits(context);
            setState(() {});
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Unit "${nameCtrl.text.trim()}" added'),
              ]),
              backgroundColor: const Color(0xFF8B5CF6),
            ));
          },
          child: const Text('Add Unit'),
        ),
      ],
    ));
  }
}


