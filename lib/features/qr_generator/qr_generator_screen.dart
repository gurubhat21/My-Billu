import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/invoice_generator.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();

  String _upiId = '';
  String _businessName = '';
  Uint8List? _logoBytes;
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final appState = context.read<AppState>();
    final s = await appState.getAllSettings();
    if (mounted) {
      setState(() {
        _upiId = s['businessUpiId'] ?? '';
        _businessName = s['businessName'] ?? 'My Billu';
        _logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
        _loading = false;
      });
    }
  }

  String _buildUpiUri() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final note = _noteCtrl.text.trim();
    var uri = 'upi://pay?pa=${Uri.encodeComponent(_upiId)}&pn=${Uri.encodeComponent(_businessName)}';
    if (amount > 0) {
      uri += '&am=${amount.toStringAsFixed(2)}&cu=INR';
    }
    if (note.isNotEmpty) {
      uri += '&tn=${Uri.encodeComponent(note)}';
    }
    return uri;
  }

  Future<void> _shareQrImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw 'QR not rendered';

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw 'Failed to capture image';

      final pngBytes = byteData.buffer.asUint8List();
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      final amtStr = amount > 0 ? ' - Rs.${amount.toStringAsFixed(2)}' : '';

      if (!kIsWeb && Platform.isWindows) {
        // Windows: Save and open in explorer
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/upi_qr_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);
        await Process.run('explorer.exe', ['/select,', file.path]);
      } else {
        // Android/Web: Share via share_plus
        final xFile = XFile.fromData(pngBytes, mimeType: 'image/png', name: 'UPI_QR$amtStr.png');
        await Share.shareXFiles([xFile], text: 'Pay $_businessName$amtStr via UPI');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _saveQrImage() async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw 'QR not rendered';

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw 'Failed to capture image';

      final pngBytes = byteData.buffer.asUint8List();
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      final amtStr = amount > 0 ? '_Rs${amount.toStringAsFixed(0)}' : '';

      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/UPI_QR${amtStr}_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
              Expanded(child: Text('Saved to ${file.path}')),
            ]),
            backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_upiId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('UPI QR Generator')),
        body: Center(
          child: Container(
            width: 400, padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_2, size: 64, color: AppColors.warning),
              ),
              const SizedBox(height: 24),
              const Text('UPI ID Not Set', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('Please add your UPI ID in Settings → Business Profile to use this feature.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to settings
                },
                icon: const Icon(Icons.settings),
                label: const Text('Go to Settings'),
              ),
            ]),
          ),
        ),
      );
    }

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final upiUri = _buildUpiUri();

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI QR Generator'),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Save Image',
              onPressed: _saveQrImage,
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share QR',
            onPressed: _shareQrImage,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(children: [
              // UPI ID display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.accent.withValues(alpha: 0.05),
                  ]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_businessName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('UPI: $_upiId', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
                  ])),
                ]),
              ),
              const SizedBox(height: 24),

              // Amount & Note inputs
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      hintText: '0.00',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _noteCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: const Icon(Icons.note),
                      hintText: 'Payment for...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 28),

              // QR Code Card
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(children: [
                    // Business logo
                    if (_logoBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_logoBytes!, width: 70, height: 70, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Business name header
                    Text(_businessName, style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E),
                    )),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('UPI: $_upiId', style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF),
                      )),
                    ),
                    const SizedBox(height: 20),

                    // QR Code
                    QrImageView(
                      data: upiUri,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1A1A2E),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount display
                    if (amount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF4834D4)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('₹ ${amount.toStringAsFixed(2)}', style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white,
                        )),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Any Amount', style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF666666),
                        )),
                      ),
                    const SizedBox(height: 16),

                    // Scan to pay text
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.qr_code_scanner, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text('Scan to Pay', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500,
                      )),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 28),

              // Action buttons
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sharing ? null : _shareQrImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _sharing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.share, size: 20),
                    label: Text(_sharing ? 'Sharing...' : 'Share QR Image', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveQrImage,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.save_alt, size: 20),
                      label: const Text('Save Image', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ]),

              // Quick amount buttons
              const SizedBox(height: 20),
              Text('Quick Amounts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.4))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [100, 200, 500, 1000, 2000, 5000].map((amt) {
                  return ActionChip(
                    label: Text('₹$amt'),
                    onPressed: () {
                      _amountCtrl.text = amt.toString();
                      setState(() {});
                    },
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }
}
