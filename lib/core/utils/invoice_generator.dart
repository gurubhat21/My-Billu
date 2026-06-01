import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:io' show File, Platform, Directory;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bill.dart';

enum InvoiceTemplate { modern, classic, minimal, gstInvoice, simple }
enum PaperSize { a4, a5 }

class InvoiceGenerator {

  static PdfPageFormat _getPageFormat(PaperSize size) {
    switch (size) {
      case PaperSize.a4: return PdfPageFormat.a4;
      case PaperSize.a5: return PdfPageFormat.a5;
    }
  }

  // ===== MAIN ENTRY POINTS =====

  static Future<void> generateAndPrint(
    Bill bill, {
    String businessName = 'My Billu',
    String businessAddress = '',
    String businessPhone = '',
    String businessGstin = '',
    String businessBankName = '',
    String businessBankAccount = '',
    String businessBankIfsc = '',
    String businessUpiId = '',
    Uint8List? logoBytes,
    InvoiceTemplate template = InvoiceTemplate.modern,
    PaperSize paperSize = PaperSize.a4,
    String? documentTitle,
    String? thankYouMessage,
    String? termsConditions,
  }) async {
    final bytes = await generatePdfBytes(bill,
      businessName: businessName, businessAddress: businessAddress,
      businessPhone: businessPhone, businessGstin: businessGstin,
      businessBankName: businessBankName, businessBankAccount: businessBankAccount,
      businessBankIfsc: businessBankIfsc, businessUpiId: businessUpiId, logoBytes: logoBytes,
      template: template, paperSize: paperSize, documentTitle: documentTitle,
      thankYouMessage: thankYouMessage, termsConditions: termsConditions);
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  static Future<Uint8List> generatePdfBytes(
    Bill bill, {
    String businessName = 'My Billu',
    String businessAddress = '',
    String businessPhone = '',
    String businessGstin = '',
    String businessBankName = '',
    String businessBankAccount = '',
    String businessBankIfsc = '',
    String businessUpiId = '',
    Uint8List? logoBytes,
    InvoiceTemplate template = InvoiceTemplate.modern,
    PaperSize paperSize = PaperSize.a4,
    String? documentTitle,
    String? thankYouMessage,
    String? termsConditions,
  }) async {
    // Load font that supports ₹ (Rupee) symbol
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();
    final fontBoldItalic = await PdfGoogleFonts.notoSansBoldItalic();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
        boldItalic: fontBoldItalic,
      ),
    );
    final pageFormat = _getPageFormat(paperSize);
    final isA5 = paperSize == PaperSize.a5;
    final margin = isA5 ? const pw.EdgeInsets.all(20) : const pw.EdgeInsets.all(32);
    final bk = _BankInfo(businessBankName, businessBankAccount, businessBankIfsc);
    final upiId = businessUpiId;
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    pdf.addPage(pw.Page(
      pageFormat: pageFormat,
      margin: margin,
      build: (context) {
        final docTitle = documentTitle;
        final tyMsg = thankYouMessage;
        final tc = termsConditions;
        switch (template) {
          case InvoiceTemplate.modern:
            return _buildModernTemplate(bill, businessName, businessAddress, businessPhone, businessGstin, isA5, bk, logoImage, docTitle, tyMsg, tc, upiId);
          case InvoiceTemplate.classic:
            return _buildClassicTemplate(bill, businessName, businessAddress, businessPhone, businessGstin, isA5, bk, logoImage, docTitle, tyMsg, tc, upiId);
          case InvoiceTemplate.minimal:
            return _buildMinimalTemplate(bill, businessName, businessAddress, businessPhone, businessGstin, isA5, bk, logoImage, docTitle, tyMsg, tc, upiId);
          case InvoiceTemplate.gstInvoice:
            return _buildGstInvoiceTemplate(bill, businessName, businessAddress, businessPhone, businessGstin, isA5, bk, logoImage, docTitle, tyMsg, tc, upiId);
          case InvoiceTemplate.simple:
            return _buildSimpleTemplate(bill, businessName, businessAddress, businessPhone, isA5, bk, logoImage, docTitle, tyMsg, tc, upiId);
        }
      },
    ));
    return pdf.save();
  }

  static Future<void> shareInvoice(
    Bill bill, {
    String businessName = 'My Billu',
    String businessAddress = '',
    String businessPhone = '',
    String businessGstin = '',
    String businessBankName = '',
    String businessBankAccount = '',
    String businessBankIfsc = '',
    String businessUpiId = '',
    Uint8List? logoBytes,
    InvoiceTemplate template = InvoiceTemplate.modern,
    PaperSize paperSize = PaperSize.a4,
    String? documentTitle,
    String? thankYouMessage,
    String? termsConditions,
  }) async {
    final bytes = await generatePdfBytes(bill,
      businessName: businessName, businessAddress: businessAddress,
      businessPhone: businessPhone, businessGstin: businessGstin,
      businessBankName: businessBankName, businessBankAccount: businessBankAccount,
      businessBankIfsc: businessBankIfsc, businessUpiId: businessUpiId, logoBytes: logoBytes,
      template: template, paperSize: paperSize, documentTitle: documentTitle,
      thankYouMessage: thankYouMessage, termsConditions: termsConditions);

    final fileLabel = documentTitle != null ? documentTitle.replaceAll(' ', '_') : 'Invoice';
    final partyName = _sanitizeFileName(bill.customerName ?? 'Walk-in');
    final fileName = '${partyName}_${bill.billNumber}.pdf';
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: use Printing.sharePdf which opens system print/save dialog
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } else {
      // Mobile: share as file attachment
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
        subject: '${documentTitle ?? 'Invoice'} ${bill.billNumber} - ${_cur(bill.totalAmount)} from $businessName');
    }
  }

  /// Save PDF to a specific folder (user-configured or Downloads)
  static Future<String> savePdfToFile(
    Bill bill, {
    String businessName = 'My Billu',
    String businessAddress = '',
    String businessPhone = '',
    String businessGstin = '',
    String businessBankName = '',
    String businessBankAccount = '',
    String businessBankIfsc = '',
    String businessUpiId = '',
    Uint8List? logoBytes,
    InvoiceTemplate template = InvoiceTemplate.modern,
    PaperSize paperSize = PaperSize.a4,
    String? documentTitle,
    String? thankYouMessage,
    String? termsConditions,
    String? savePath,
  }) async {
    final bytes = await generatePdfBytes(bill,
      businessName: businessName, businessAddress: businessAddress,
      businessPhone: businessPhone, businessGstin: businessGstin,
      businessBankName: businessBankName, businessBankAccount: businessBankAccount,
      businessBankIfsc: businessBankIfsc, businessUpiId: businessUpiId, logoBytes: logoBytes,
      template: template, paperSize: paperSize, documentTitle: documentTitle,
      thankYouMessage: thankYouMessage, termsConditions: termsConditions);

    final fileLabel = documentTitle != null ? documentTitle.replaceAll(' ', '_') : 'Invoice';
    final partyName = _sanitizeFileName(bill.customerName ?? 'Walk-in');
    final fileName = '${partyName}_${bill.billNumber}.pdf';

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return fileName;
    }

    // Determine save directory
    String dirPath;
    if (savePath != null && savePath.isNotEmpty) {
      dirPath = savePath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dirPath = dir.path;
    }

    // Ensure directory exists
    final saveDir = Directory(dirPath);
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final file = File('$dirPath/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<void> emailInvoice(
    Bill bill, {
    String? recipientEmail,
    String businessName = 'My Billu',
    String businessAddress = '',
    String businessPhone = '',
    String businessGstin = '',
    String businessBankName = '',
    String businessBankAccount = '',
    String businessBankIfsc = '',
    String businessUpiId = '',
    Uint8List? logoBytes,
    InvoiceTemplate template = InvoiceTemplate.modern,
    PaperSize paperSize = PaperSize.a4,
  }) async {
    final bytes = await generatePdfBytes(bill,
      businessName: businessName, businessAddress: businessAddress,
      businessPhone: businessPhone, businessGstin: businessGstin,
      businessBankName: businessBankName, businessBankAccount: businessBankAccount,
      businessBankIfsc: businessBankIfsc, businessUpiId: businessUpiId, logoBytes: logoBytes,
      template: template, paperSize: paperSize);

    final itemsList = bill.items.map((i) =>
      '  ${i.itemName} x${i.quantity} - ${_cur(i.total)}').join('\n');

    final subject = 'Invoice ${bill.billNumber} from $businessName - ${_cur(bill.totalAmount)}';
    final body = '''Dear ${bill.customerName ?? 'Customer'},

Please find below the invoice details:

Invoice No: ${bill.billNumber}
Date: ${_fmtDate(bill.createdAt)}

Items:
$itemsList

Subtotal: ${_cur(bill.subtotal)}
${bill.discount > 0 ? 'Discount: -${_cur(bill.discount)}\n' : ''}GST: ${_cur(bill.totalTax)}
Total: ${_cur(bill.totalAmount)}
${bill.paidAmount > 0 && bill.paidAmount < bill.totalAmount ? 'Paid: ${_cur(bill.paidAmount)}\nBalance Due: ${_cur(bill.balanceDue)}\n' : ''}
Thank you for your business!

$businessName
${businessPhone.isNotEmpty ? 'Phone: $businessPhone' : ''}
${businessGstin.isNotEmpty ? 'GSTIN: $businessGstin' : ''}

---
Generated by My Billu - Smart Billing Software''';

    final partyName = _sanitizeFileName(bill.customerName ?? 'Walk-in');
    final fileName = '${partyName}_${bill.billNumber}.pdf';
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], subject: subject, text: body);
    }
  }

  /// Share invoice via WhatsApp — sends PDF + bill summary to customer's number
  static Future<void> shareViaWhatsApp(
    Bill bill, {
    String? customerPhone,
    String businessName = 'My Billu',
    String businessAddress = '',
    String businessPhone = '',
    String businessGstin = '',
    String businessBankName = '',
    String businessBankAccount = '',
    String businessBankIfsc = '',
    String businessUpiId = '',
    Uint8List? logoBytes,
    InvoiceTemplate template = InvoiceTemplate.modern,
    PaperSize paperSize = PaperSize.a4,
    String? thankYouMessage,
    String? termsConditions,
  }) async {
    // Build bill summary message
    final itemsList = bill.items.map((i) =>
      '  • ${i.itemName} ×${i.quantity} — ${_cur(i.total)}').join('\n');

    final message = '''📋 *Invoice ${bill.billNumber}*
From *$businessName*

🛒 *Items:*
$itemsList

💰 Subtotal: ${_cur(bill.subtotal)}
${bill.discount > 0 ? '🏷️ Discount: -${_cur(bill.discount)}\n' : ''}📊 GST: ${_cur(bill.totalTax)}
✅ *Total: ${_cur(bill.totalAmount)}*
${bill.paidAmount > 0 && bill.paidAmount < bill.totalAmount ? '\n💳 Paid: ${_cur(bill.paidAmount)}\n⚠️ Balance Due: ${_cur(bill.balanceDue)}' : ''}
📅 Date: ${_fmtDate(bill.createdAt)}
${bill.paymentMethod.name != 'cash' ? '💳 Payment: ${bill.paymentMethod.name.toUpperCase()}\n' : ''}
${thankYouMessage ?? 'Thank you for your business!'}
— $businessName${businessPhone.isNotEmpty ? ' | $businessPhone' : ''}''';

    // Clean phone number (remove spaces, dashes, add country code)
    String? phone = customerPhone ?? bill.customerPhone;
    if (phone != null && phone.isNotEmpty) {
      phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (!phone.startsWith('+')) {
        // Default to India country code
        if (phone.startsWith('0')) phone = phone.substring(1);
        phone = '91$phone';
      } else {
        phone = phone.substring(1); // Remove + for wa.me URL
      }
    }

    // On mobile (non-web), share PDF + message
    if (!kIsWeb) {
      try {
        // Generate and save PDF
        final bytes = await generatePdfBytes(bill,
          businessName: businessName, businessAddress: businessAddress,
          businessPhone: businessPhone, businessGstin: businessGstin,
          businessBankName: businessBankName, businessBankAccount: businessBankAccount,
          businessBankIfsc: businessBankIfsc, businessUpiId: businessUpiId, logoBytes: logoBytes,
          template: template, paperSize: paperSize,
          thankYouMessage: thankYouMessage, termsConditions: termsConditions);

        final dir = await getTemporaryDirectory();
        final pName = _sanitizeFileName(bill.customerName ?? 'Walk-in');
        final file = File('${dir.path}/${pName}_${bill.billNumber}.pdf');
        await file.writeAsBytes(bytes);

        // Share PDF as primary content with message as subject
        if (Platform.isAndroid || Platform.isIOS) {
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'application/pdf')],
            subject: 'Invoice ${bill.billNumber} from $businessName',
          );
          return;
        }
      } catch (_) {
        // Fall through to URL-based approach
      }
    }

    // Fallback: Open WhatsApp via URL (works on all platforms)
    final encodedMessage = Uri.encodeComponent(message);
    final url = phone != null && phone.isNotEmpty
        ? 'https://wa.me/$phone?text=$encodedMessage'
        : 'https://wa.me/?text=$encodedMessage';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Last resort: try direct share
      await Share.share(message, subject: 'Invoice ${bill.billNumber}');
    }
  }

  // ===== UPI QR HELPER =====

  static pw.Widget _upiQrBlock(String upiId, String businessName, double amount, String billNumber, double fs) {
    final upiUri = 'upi://pay?pa=${Uri.encodeComponent(upiId)}&pn=${Uri.encodeComponent(businessName)}&am=${amount.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent('Payment for $billNumber')}';
    return pw.Container(
      margin: pw.EdgeInsets.only(top: 8 * fs, bottom: 8 * fs),
      padding: pw.EdgeInsets.all(10 * fs),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: upiUri,
          width: 75 * fs,
          height: 75 * fs,
        ),
        pw.SizedBox(width: 12 * fs),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Scan to Pay', style: pw.TextStyle(fontSize: 11 * fs, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4 * fs),
          pw.Text('UPI: $upiId', style: pw.TextStyle(fontSize: 8 * fs, color: PdfColors.grey700)),
          pw.SizedBox(height: 2 * fs),
          pw.Text('Amount: \u20b9${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9 * fs, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2 * fs),
          pw.Text('Ref: $billNumber', style: pw.TextStyle(fontSize: 7 * fs, color: PdfColors.grey500)),
        ]),
      ]),
    );
  }

  // ===== BANK INFO HELPER =====

  static pw.Widget _bankDetailsBlock(double fs, _BankInfo bk, {PdfColor accent = PdfColors.indigo}) {
    if (!bk.hasData) return pw.SizedBox();
    return pw.Container(
      padding: pw.EdgeInsets.all(8 * fs),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Bank Details', style: pw.TextStyle(fontSize: 9 * fs, fontWeight: pw.FontWeight.bold, color: accent)),
        pw.SizedBox(height: 3 * fs),
        if (bk.name.isNotEmpty) pw.Text('Bank: ${bk.name}', style: pw.TextStyle(fontSize: 8 * fs)),
        if (bk.account.isNotEmpty) pw.Text('A/C No: ${bk.account}', style: pw.TextStyle(fontSize: 8 * fs)),
        if (bk.ifsc.isNotEmpty) pw.Text('IFSC: ${bk.ifsc}', style: pw.TextStyle(fontSize: 8 * fs, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  // ===== LOGO HELPER =====
  static pw.Widget? _logoWidget(pw.ImageProvider? logo, double size) {
    if (logo == null) return null;
    return pw.Container(
      width: size, height: size,
      margin: const pw.EdgeInsets.only(right: 12),
      child: pw.Image(logo, fit: pw.BoxFit.contain),
    );
  }

  /// Parse base64 data URL to bytes
  static Uint8List? parseLogoData(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    try {
      if (dataUrl.startsWith('data:')) {
        final commaIdx = dataUrl.indexOf(',');
        if (commaIdx == -1) return null;
        return base64Decode(dataUrl.substring(commaIdx + 1));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ===== TEMPLATE 1: MODERN (Indigo accent, colored header) =====

  static pw.Widget _buildModernTemplate(Bill bill, String bName, String bAddr, String bPhone, String bGstin, bool isA5, _BankInfo bk, pw.ImageProvider? logo, String? docTitle, String? thankYouMsg, String? termsText, String upiId) {
    final isQuotation = docTitle != null;
    final fs = isA5 ? 0.8 : 1.0;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Logo centered at top
      if (logo != null) ...[
        pw.Center(child: pw.Container(
          width: isA5 ? 50 : 70, height: isA5 ? 50 : 70,
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        )),
        pw.SizedBox(height: 8 * fs),
      ],
      // Header with colored badge
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(bName, style: pw.TextStyle(fontSize: 24 * fs, fontWeight: pw.FontWeight.bold)),
          if (bAddr.isNotEmpty) pw.Text(bAddr, style: pw.TextStyle(fontSize: 10 * fs, color: PdfColors.grey700)),
          if (bPhone.isNotEmpty) pw.Text('Phone: $bPhone', style: pw.TextStyle(fontSize: 10 * fs, color: PdfColors.grey700)),
          if (bGstin.isNotEmpty) pw.Text('GSTIN: $bGstin', style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 16 * fs, vertical: 8 * fs),
            decoration: pw.BoxDecoration(color: PdfColors.indigo, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Text(docTitle ?? 'TAX INVOICE', style: pw.TextStyle(fontSize: 14 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
          pw.SizedBox(height: 8),
          pw.Text('${isQuotation ? 'Quotation' : 'Invoice'} #: ${bill.billNumber}', style: pw.TextStyle(fontSize: 11 * fs, fontWeight: pw.FontWeight.bold)),
          pw.Text('Date: ${_fmtDate(bill.createdAt)}', style: pw.TextStyle(fontSize: 10 * fs, color: PdfColors.grey700)),
        ]),
      ]),
      pw.SizedBox(height: 16 * fs),
      pw.Divider(color: PdfColors.indigo200),
      pw.SizedBox(height: 10 * fs),
      // Customer
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Bill To:', style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(bill.customerName ?? 'Walk-in Customer', style: pw.TextStyle(fontSize: 13 * fs, fontWeight: pw.FontWeight.bold)),
          if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty)
            pw.Text('Ph: ${bill.customerPhone}', style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey600)),
        ])),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Payment: ${bill.paymentMethod.name.toUpperCase()}', style: pw.TextStyle(fontSize: 10 * fs)),
          pw.Text('Status: ${bill.status.name.toUpperCase()}',
            style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold,
              color: bill.status == BillStatus.paid ? PdfColors.green700 : PdfColors.red700)),
        ]),
      ]),
      pw.SizedBox(height: 14 * fs),
      // Items table
      _buildItemsTable(bill, PdfColors.indigo, PdfColors.white, fs),
      pw.SizedBox(height: 14 * fs),
      // Totals
      _buildTotalsBox(bill, PdfColors.grey100, PdfColors.grey300, PdfColors.indigo, fs, isQuotation: isQuotation),
      pw.SizedBox(height: 6 * fs),
      pw.Text('Amount in words: ${_amountToWords(bill.totalAmount)} Only',
        style: pw.TextStyle(fontSize: 8.5 * fs, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
      pw.SizedBox(height: 14 * fs),
      // Bank Details
      _bankDetailsBlock(fs, bk, accent: PdfColors.indigo),
      pw.SizedBox(height: 8 * fs),
      pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 8 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      pw.Text(termsText != null && termsText.isNotEmpty ? termsText : 'Goods once sold cannot be taken back.', style: pw.TextStyle(fontSize: 7.5 * fs, color: PdfColors.grey600)),
      if (upiId.isNotEmpty) _upiQrBlock(upiId, bName, bill.totalAmount, bill.billNumber, fs),
      pw.SizedBox(height: 14 * fs),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 6 * fs),
      pw.Center(child: pw.Text(thankYouMsg ?? 'Thank you for your business!', style: pw.TextStyle(fontSize: 11 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo))),
      pw.SizedBox(height: 3),
      pw.Center(child: pw.Text('Generated by My Billu - Smart Billing Software', style: pw.TextStyle(fontSize: 8 * fs, color: PdfColors.grey500))),
    ]);
  }

  // ===== TEMPLATE 2: CLASSIC (Professional, bordered, black & gold) =====

  static pw.Widget _buildClassicTemplate(Bill bill, String bName, String bAddr, String bPhone, String bGstin, bool isA5, _BankInfo bk, pw.ImageProvider? logo, String? docTitle, String? thankYouMsg, String? termsText, String upiId) {
    final isQuotation = docTitle != null;
    final fs = isA5 ? 0.8 : 1.0;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Outer border effect header
      pw.Container(
        padding: pw.EdgeInsets.all(16 * fs),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey800, width: 2),
          borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(children: [
          if (logo != null) ...[
            pw.Center(child: pw.Container(
              width: isA5 ? 50 : 70, height: isA5 ? 50 : 70,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )),
            pw.SizedBox(height: 6),
          ],
          pw.Center(child: pw.Text(bName.toUpperCase(),
            style: pw.TextStyle(fontSize: 22 * fs, fontWeight: pw.FontWeight.bold, letterSpacing: 2))),
          if (bAddr.isNotEmpty) pw.Center(child: pw.Text(bAddr, style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey600))),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            if (bPhone.isNotEmpty) pw.Text('Tel: $bPhone  ', style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey600)),
            if (bGstin.isNotEmpty) pw.Text('GSTIN: $bGstin', style: pw.TextStyle(fontSize: 9 * fs, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.Divider(color: PdfColors.grey800, thickness: 1.5),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(docTitle ?? 'TAX INVOICE', style: pw.TextStyle(fontSize: 16 * fs, fontWeight: pw.FontWeight.bold, letterSpacing: 3))),
        ]),
      ),
      pw.SizedBox(height: 14 * fs),
      // Invoice details row
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('${isQuotation ? 'Quotation' : 'Invoice'} No: ${bill.billNumber}', style: pw.TextStyle(fontSize: 11 * fs, fontWeight: pw.FontWeight.bold)),
          pw.Text('Date: ${_fmtDate(bill.createdAt)}', style: pw.TextStyle(fontSize: 10 * fs)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Customer: ${bill.customerName ?? "Walk-in"}', style: pw.TextStyle(fontSize: 11 * fs, fontWeight: pw.FontWeight.bold)),
          if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty)
            pw.Text('Ph: ${bill.customerPhone}', style: pw.TextStyle(fontSize: 10 * fs, color: PdfColors.grey600)),
          pw.Text('Payment: ${bill.paymentMethod.name.toUpperCase()} | ${bill.status.name.toUpperCase()}', style: pw.TextStyle(fontSize: 10 * fs)),
        ]),
      ]),
      pw.SizedBox(height: 14 * fs),
      // Items
      _buildItemsTable(bill, PdfColors.grey800, PdfColors.white, fs),
      pw.SizedBox(height: 14 * fs),
      // Totals
      _buildTotalsBox(bill, PdfColors.amber50, PdfColors.amber200, PdfColors.grey800, fs, isQuotation: isQuotation),
      pw.SizedBox(height: 6 * fs),
      pw.Text('Amount in words: ${_amountToWords(bill.totalAmount)} Only',
        style: pw.TextStyle(fontSize: 8.5 * fs, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
      pw.SizedBox(height: 14 * fs),
      // Bank Details
      _bankDetailsBlock(fs, bk, accent: PdfColors.grey800),
      pw.SizedBox(height: 8 * fs),
      pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 8 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      pw.Text(termsText != null && termsText.isNotEmpty ? termsText : 'Goods once sold cannot be taken back.', style: pw.TextStyle(fontSize: 7.5 * fs, color: PdfColors.grey600)),
      if (upiId.isNotEmpty) _upiQrBlock(upiId, bName, bill.totalAmount, bill.billNumber, fs),
      pw.SizedBox(height: 18 * fs),
      // Signature line
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(width: 150, child: pw.Divider(color: PdfColors.grey400)),
          pw.Text("Customer's Signature", style: pw.TextStyle(fontSize: 8 * fs, color: PdfColors.grey500)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Container(width: 150, child: pw.Divider(color: PdfColors.grey400)),
          pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 8 * fs, color: PdfColors.grey500)),
        ]),
      ]),
      if (thankYouMsg != null && thankYouMsg.isNotEmpty) ...[
        pw.SizedBox(height: 8 * fs),
        pw.Center(child: pw.Text(thankYouMsg, style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))),
      ],
      pw.SizedBox(height: 12 * fs),
      pw.Center(child: pw.Text('Generated by My Billu', style: pw.TextStyle(fontSize: 7 * fs, color: PdfColors.grey400))),
    ]);
  }

  // ===== TEMPLATE 3: MINIMAL (Clean, lightweight, blue accent) =====

  static pw.Widget _buildMinimalTemplate(Bill bill, String bName, String bAddr, String bPhone, String bGstin, bool isA5, _BankInfo bk, pw.ImageProvider? logo, String? docTitle, String? thankYouMsg, String? termsText, String upiId) {
    final isQuotation = docTitle != null;
    final fs = isA5 ? 0.8 : 1.0;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Logo at top
      if (logo != null) ...[
        pw.Center(child: pw.Container(
          width: isA5 ? 44 : 60, height: isA5 ? 44 : 60,
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        )),
        pw.SizedBox(height: 8 * fs),
      ],
      // Simple clean header
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(bName, style: pw.TextStyle(fontSize: 20 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
          if (bAddr.isNotEmpty) pw.Text(bAddr, style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey500)),
        ]),
      ]),
      pw.Row(children: [
        if (bPhone.isNotEmpty) pw.Text(bPhone, style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey500)),
        if (bPhone.isNotEmpty && bGstin.isNotEmpty) pw.Text('  |  ', style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey400)),
        if (bGstin.isNotEmpty) pw.Text('GSTIN: $bGstin', style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey500)),
      ]),
      pw.SizedBox(height: 6 * fs),
      pw.Container(height: 3, color: PdfColors.blue400),
      pw.SizedBox(height: 14 * fs),
      // Invoice meta + customer in 2 columns
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(docTitle ?? 'INVOICE', style: pw.TextStyle(fontSize: 18 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.blue400, letterSpacing: 2)),
          pw.SizedBox(height: 6),
          _metaLine('Number', bill.billNumber, fs),
          _metaLine('Date', _fmtDate(bill.createdAt), fs),
          _metaLine('Status', bill.status.name.toUpperCase(), fs),
        ])),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('BILL TO', style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500, letterSpacing: 1)),
          pw.SizedBox(height: 6),
          pw.Text(bill.customerName ?? 'Walk-in Customer', style: pw.TextStyle(fontSize: 12 * fs, fontWeight: pw.FontWeight.bold)),
          if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty)
            pw.Text('Ph: ${bill.customerPhone}', style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey500)),
          pw.SizedBox(height: 4),
          pw.Text('Payment: ${bill.paymentMethod.name.toUpperCase()}', style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey500)),
        ])),
      ]),
      pw.SizedBox(height: 16 * fs),
      // Simple items table
      _buildItemsTable(bill, PdfColors.blue400, PdfColors.white, fs),
      pw.SizedBox(height: 14 * fs),
      // Right-aligned totals
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.SizedBox(
          width: isA5 ? 180 : 220,
          child: pw.Column(children: [
            _simpleTotalRow('Subtotal', _cur(bill.subtotal), fs),
            _simpleTotalRow('CGST', _cur(bill.totalCgst), fs),
            _simpleTotalRow('SGST', _cur(bill.totalSgst), fs),
            pw.Container(height: 1, color: PdfColors.blue400, margin: pw.EdgeInsets.symmetric(vertical: 4 * fs)),
            _simpleTotalRow('Total', _cur(bill.totalAmount), fs, bold: true, color: PdfColors.blue800),
            if (!isQuotation && bill.paidAmount > 0 && bill.paidAmount < bill.totalAmount) ...[
              _simpleTotalRow('Paid', _cur(bill.paidAmount), fs),
              _simpleTotalRow('Balance', _cur(bill.balanceDue), fs, bold: true, color: PdfColors.red700),
            ],
          ]),
        ),
      ]),
      pw.SizedBox(height: 14 * fs),
      pw.Text('Amount in words: ${_amountToWords(bill.totalAmount)} Only',
        style: pw.TextStyle(fontSize: 8.5 * fs, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
      pw.SizedBox(height: 10 * fs),
      // Bank Details
      _bankDetailsBlock(fs, bk, accent: PdfColors.blue400),
      pw.SizedBox(height: 8 * fs),
      pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 8 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      pw.Text(termsText != null && termsText.isNotEmpty ? termsText : 'Goods once sold cannot be taken back.', style: pw.TextStyle(fontSize: 7.5 * fs, color: PdfColors.grey600)),
      if (upiId.isNotEmpty) _upiQrBlock(upiId, bName, bill.totalAmount, bill.billNumber, fs),
      pw.Spacer(),
      pw.Container(height: 1, color: PdfColors.grey200),
      pw.SizedBox(height: 6),
      pw.Center(child: pw.Text(thankYouMsg ?? 'Thank you!', style: pw.TextStyle(fontSize: 9 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.blue400))),
      pw.SizedBox(height: 2),
      pw.Center(child: pw.Text('My Billu', style: pw.TextStyle(fontSize: 7 * fs, color: PdfColors.grey400))),
    ]);
  }

  // ===== SHARED HELPERS =====

  static pw.Widget _buildItemsTable(Bill bill, PdfColor headerBg, PdfColor headerText, double fs) {
    final headerStyle = pw.TextStyle(fontSize: 8.5 * fs, fontWeight: pw.FontWeight.bold, color: headerText);
    final cellStyle = pw.TextStyle(fontSize: 8.5 * fs);
    final subStyle = pw.TextStyle(fontSize: 7 * fs, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic);
    final pad = pw.EdgeInsets.symmetric(horizontal: 5 * fs, vertical: 3 * fs);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.6),  // #
        1: const pw.FlexColumnWidth(3.5),  // Item Name (+ desc/SN below)
        2: const pw.FlexColumnWidth(1.2),  // Price
        3: const pw.FlexColumnWidth(0.8),  // Qty
        4: const pw.FlexColumnWidth(0.7),  // GST%
        5: const pw.FlexColumnWidth(1),    // GST
        6: const pw.FlexColumnWidth(1.3),  // Total
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          children: [
            pw.Padding(padding: pad, child: pw.Text('#', style: headerStyle)),
            pw.Padding(padding: pad, child: pw.Text('Item', style: headerStyle)),
            pw.Padding(padding: pad, child: pw.Text('Price', style: headerStyle)),
            pw.Padding(padding: pad, child: pw.Text('Qty', style: headerStyle)),
            pw.Padding(padding: pad, child: pw.Text('GST%', style: headerStyle)),
            pw.Padding(padding: pad, child: pw.Text('GST', style: headerStyle)),
            pw.Padding(padding: pad, child: pw.Text('Total', style: headerStyle)),
          ],
        ),
        // Data rows
        ...bill.items.asMap().entries.map((e) {
          final item = e.value;
          final altBg = e.key % 2 == 1 ? PdfColors.grey50 : null;
          // Build item name with description and serial numbers below
          final nameChildren = <pw.Widget>[
            pw.Text(item.itemName, style: cellStyle),
          ];
          if (item.description != null && item.description!.isNotEmpty) {
            nameChildren.add(pw.Text(item.description!, style: subStyle));
          }
          if (item.serialNumber != null && item.serialNumber!.isNotEmpty) {
            nameChildren.add(pw.Text('SN: ${item.serialNumber}', style: subStyle));
          }
          return pw.TableRow(
            decoration: altBg != null ? pw.BoxDecoration(color: altBg) : null,
            children: [
              pw.Padding(padding: pad, child: pw.Text('${e.key + 1}', style: cellStyle)),
              pw.Padding(padding: pad, child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: nameChildren)),
              pw.Padding(padding: pad, child: pw.Text(_cur(item.unitPrice), style: cellStyle)),
              pw.Padding(padding: pad, child: pw.Text('${item.quantity} ${item.unit}', style: cellStyle)),
              pw.Padding(padding: pad, child: pw.Text('${item.taxRate}%', style: cellStyle)),
              pw.Padding(padding: pad, child: pw.Text(_cur(item.taxAmount), style: cellStyle)),
              pw.Padding(padding: pad, child: pw.Text(_cur(item.total),
                style: pw.TextStyle(fontSize: 8.5 * fs, fontWeight: pw.FontWeight.bold))),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildGstItemsTable(Bill bill, double fs) {
    final pad = pw.EdgeInsets.symmetric(horizontal: 4 * fs, vertical: 2 * fs);
    final subStyle = pw.TextStyle(fontSize: 7 * fs, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic);

    // Fixed headers — no separate Serial/Description columns
    final headers = <String>['no.', 'Particulars', 'Qty', 'Rate', 'Amount', 'GST%', 'GST Total', 'Total'];

    // Build column widths
    final colWidths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(22 * fs),
      1: const pw.FlexColumnWidth(3.5),
      2: pw.FixedColumnWidth(30 * fs),
      3: pw.FixedColumnWidth(50 * fs),
      4: pw.FixedColumnWidth(55 * fs),
      5: pw.FixedColumnWidth(28 * fs),
      6: pw.FixedColumnWidth(50 * fs),
      7: pw.FixedColumnWidth(55 * fs),
    };

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: colWidths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.map((h) {
            final isRight = ['Rate', 'Amount', 'GST Total', 'Total'].contains(h);
            return _tCell(h, fs, bold: true, align: isRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft);
          }).toList(),
        ),
        ...bill.items.asMap().entries.map((e) {
          final item = e.value;
          // Build item name with description and serial numbers below
          final nameChildren = <pw.Widget>[
            pw.Text(item.itemName, style: pw.TextStyle(fontSize: 9 * fs)),
          ];
          if (item.description != null && item.description!.isNotEmpty) {
            nameChildren.add(pw.Text(item.description!, style: subStyle));
          }
          if (item.serialNumber != null && item.serialNumber!.isNotEmpty) {
            nameChildren.add(pw.Text('SN: ${item.serialNumber}', style: subStyle));
          }
          final cells = <pw.Widget>[
            _tCell('${e.key + 1}', fs),
            pw.Padding(padding: pad, child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: nameChildren)),
            _tCell('${item.quantity}', fs),
            _tCell(item.unitPrice.toStringAsFixed(2), fs, align: pw.Alignment.centerRight),
            _tCell(item.subtotal.toStringAsFixed(2), fs, align: pw.Alignment.centerRight),
            _tCell('${item.taxRate.toStringAsFixed(0)}', fs),
            _tCell(item.taxAmount.toStringAsFixed(2), fs, align: pw.Alignment.centerRight),
            _tCell(item.total.toStringAsFixed(2), fs, align: pw.Alignment.centerRight),
          ];
          return pw.TableRow(children: cells);
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tCell('', fs),
            _tCell('Total', fs, bold: true),
            _tCell('', fs), // Qty
            _tCell('', fs), // Rate
            _tCell(bill.subtotal.toStringAsFixed(2), fs, bold: true, align: pw.Alignment.centerRight),
            _tCell('', fs), // GST%
            _tCell(bill.totalTax.toStringAsFixed(2), fs, bold: true, align: pw.Alignment.centerRight),
            _tCell(bill.totalAmount.toStringAsFixed(2), fs, bold: true, align: pw.Alignment.centerRight),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTotalsBox(Bill bill, PdfColor bg, PdfColor border, PdfColor accent, double fs, {bool isQuotation = false}) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Container(
        width: 220 * fs, padding: pw.EdgeInsets.all(10 * fs),
        decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: border)),
        child: pw.Column(children: [
          _totalRow('Subtotal', _cur(bill.subtotal), fontSize: 10 * fs),
          if (bill.discount > 0) ...[
            pw.SizedBox(height: 3 * fs),
            _totalRow('Discount', '- ${_cur(bill.discount)}', fontSize: 10 * fs, color: PdfColors.red700),
          ],
          pw.SizedBox(height: 3 * fs),
          _totalRow('CGST', _cur(bill.totalCgst), fontSize: 10 * fs),
          pw.SizedBox(height: 3 * fs),
          _totalRow('SGST', _cur(bill.totalSgst), fontSize: 10 * fs),
          pw.Divider(color: border),
          _totalRow('Total', _cur(bill.totalAmount), bold: true, fontSize: 13 * fs),
          if (bill.discount > 0) ...[
            pw.SizedBox(height: 6 * fs),
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.symmetric(horizontal: 8 * fs, vertical: 4 * fs),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.green200)),
              child: pw.Text('YOU SAVED ${_cur(bill.discount)}',
                style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                textAlign: pw.TextAlign.center),
            ),
          ],
          if (!isQuotation && bill.paidAmount > 0 && bill.paidAmount < bill.totalAmount) ...[
            pw.SizedBox(height: 3 * fs),
            _totalRow('Paid', _cur(bill.paidAmount), fontSize: 10 * fs),
            pw.SizedBox(height: 3 * fs),
            _totalRow('Balance Due', _cur(bill.balanceDue), bold: true, fontSize: 11 * fs, color: PdfColors.red700),
          ],
        ])),
    ]);
  }

  static pw.Widget _totalRow(String label, String value,
      {bool bold = false, double fontSize = 11, PdfColor? color}) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
    ]);
  }

  static pw.Widget _simpleTotalRow(String label, String value, double fs, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2 * fs),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10 * fs, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10 * fs, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ]),
    );
  }

  static pw.Widget _metaLine(String label, String value, double fs) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 3 * fs),
      child: pw.Row(children: [
        pw.SizedBox(width: 60 * fs, child: pw.Text(label, style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey500))),
        pw.Text(': ', style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey400)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  static String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  static String _cur(double a) => 'Rs.${a.toStringAsFixed(2)}';

  /// Sanitize a string for use as a file name
  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // Remove invalid file chars
        .replaceAll(RegExp(r'\s+'), '_')          // Spaces to underscores
        .trim();
  }

  // ===== TEMPLATE 5: SIMPLE (No GST) =====

  static pw.Widget _buildSimpleTemplate(Bill bill, String bName, String bAddr, String bPhone, bool isA5, _BankInfo bk, pw.ImageProvider? logo, String? docTitle, String? thankYouMsg, String? termsText, String upiId) {
    final isQuotation = docTitle != null;
    final fs = isA5 ? 0.8 : 1.0;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Logo
      if (logo != null) ...[
        pw.Center(child: pw.Container(
          width: isA5 ? 50 : 70, height: isA5 ? 50 : 70,
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        )),
        pw.SizedBox(height: 8 * fs),
      ],
      // Header
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(bName, style: pw.TextStyle(fontSize: 22 * fs, fontWeight: pw.FontWeight.bold)),
          if (bAddr.isNotEmpty) pw.Text(bAddr, style: pw.TextStyle(fontSize: 10 * fs, color: PdfColors.grey700)),
          if (bPhone.isNotEmpty) pw.Text('Phone: $bPhone', style: pw.TextStyle(fontSize: 10 * fs, color: PdfColors.grey700)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 16 * fs, vertical: 8 * fs),
            decoration: pw.BoxDecoration(color: PdfColors.teal700, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Text(docTitle ?? 'BILL / INVOICE', style: pw.TextStyle(fontSize: 14 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
          pw.SizedBox(height: 8),
          pw.Text('${isQuotation ? 'Quotation' : 'Invoice'} #: ${bill.billNumber}', style: pw.TextStyle(fontSize: 11 * fs, fontWeight: pw.FontWeight.bold)),
          pw.Text('Date: ${_fmtDate(bill.createdAt)}', style: pw.TextStyle(fontSize: 10 * fs, color: PdfColors.grey700)),
        ]),
      ]),
      pw.SizedBox(height: 16 * fs),
      pw.Divider(color: PdfColors.teal200),
      pw.SizedBox(height: 10 * fs),
      // Customer
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Bill To:', style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(bill.customerName ?? 'Walk-in Customer', style: pw.TextStyle(fontSize: 13 * fs, fontWeight: pw.FontWeight.bold)),
          if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty)
            pw.Text('Ph: ${bill.customerPhone}', style: pw.TextStyle(fontSize: 9 * fs, color: PdfColors.grey600)),
        ])),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Payment: ${bill.paymentMethod.name.toUpperCase()}', style: pw.TextStyle(fontSize: 10 * fs)),
          pw.Text('Status: ${bill.status.name.toUpperCase()}',
            style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold,
              color: bill.status == BillStatus.paid ? PdfColors.green700 : PdfColors.red700)),
        ]),
      ]),
      pw.SizedBox(height: 14 * fs),
      // Simple items table (no GST columns)
      _buildSimpleItemsTable(bill, fs),
      pw.SizedBox(height: 14 * fs),
      // Totals (no CGST/SGST)
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Container(
          width: 200 * fs, padding: pw.EdgeInsets.all(10 * fs),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(children: [
            _totalRow('Subtotal', _cur(bill.subtotal), fontSize: 10 * fs),
            if (bill.discount > 0) ...[
              pw.SizedBox(height: 3 * fs),
              _totalRow('Discount', '- ${_cur(bill.discount)}', fontSize: 10 * fs, color: PdfColors.red700),
            ],
            pw.Divider(color: PdfColors.grey300),
            _totalRow('Total', _cur(bill.totalAmount), bold: true, fontSize: 13 * fs),
            if (bill.discount > 0) ...[
              pw.SizedBox(height: 6 * fs),
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.symmetric(horizontal: 8 * fs, vertical: 4 * fs),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.green200)),
                child: pw.Text('YOU SAVED ${_cur(bill.discount)}',
                  style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                  textAlign: pw.TextAlign.center),
              ),
            ],
            if (!isQuotation && bill.paidAmount > 0 && bill.paidAmount < bill.totalAmount) ...[
              pw.SizedBox(height: 3 * fs),
              _totalRow('Paid', _cur(bill.paidAmount), fontSize: 10 * fs),
              pw.SizedBox(height: 3 * fs),
              _totalRow('Balance Due', _cur(bill.balanceDue), bold: true, fontSize: 11 * fs, color: PdfColors.red700),
            ],
          ])),
      ]),
      pw.SizedBox(height: 6 * fs),
      pw.Text('Amount in words: ${_amountToWords(bill.totalAmount)} Only',
        style: pw.TextStyle(fontSize: 8.5 * fs, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
      pw.SizedBox(height: 14 * fs),
      _bankDetailsBlock(fs, bk, accent: PdfColors.teal700),
      pw.SizedBox(height: 8 * fs),
      pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 8 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      pw.Text(termsText != null && termsText.isNotEmpty ? termsText : 'Goods once sold cannot be taken back.', style: pw.TextStyle(fontSize: 7.5 * fs, color: PdfColors.grey600)),
      if (upiId.isNotEmpty) _upiQrBlock(upiId, bName, bill.totalAmount, bill.billNumber, fs),
      pw.SizedBox(height: 14 * fs),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 6 * fs),
      pw.Center(child: pw.Text(thankYouMsg ?? 'Thank you for your business!', style: pw.TextStyle(fontSize: 11 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700))),
      pw.SizedBox(height: 3),
      pw.Center(child: pw.Text('Generated by My Billu - Smart Billing Software', style: pw.TextStyle(fontSize: 8 * fs, color: PdfColors.grey500))),
    ]);
  }

  static pw.Widget _buildSimpleItemsTable(Bill bill, double fs) {
    final headerStyle = pw.TextStyle(fontSize: 8.5 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final cellStyle = pw.TextStyle(fontSize: 8.5 * fs);
    final subStyle = pw.TextStyle(fontSize: 7 * fs, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic);
    final pad = pw.EdgeInsets.symmetric(horizontal: 5 * fs, vertical: 3 * fs);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.6),  // #
        1: const pw.FlexColumnWidth(4),    // Item
        2: const pw.FlexColumnWidth(1.2),  // Price
        3: const pw.FlexColumnWidth(1),    // Qty
        4: const pw.FlexColumnWidth(1.3),  // Total
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.teal700),
          children: [
            pw.Padding(padding: pad, child: pw.Text('#', style: headerStyle)),
            pw.Padding(padding: pad, child: pw.Text('Item', style: headerStyle)),
            pw.Padding(padding: pad, child: pw.Text('Price', style: headerStyle)),
            pw.Padding(padding: pad, child: pw.Text('Qty', style: headerStyle)),
            pw.Padding(padding: pad, child: pw.Text('Total', style: headerStyle)),
          ],
        ),
        ...bill.items.asMap().entries.map((e) {
          final item = e.value;
          final altBg = e.key % 2 == 1 ? PdfColors.grey50 : null;
          final nameChildren = <pw.Widget>[
            pw.Text(item.itemName, style: cellStyle),
          ];
          if (item.description != null && item.description!.isNotEmpty) {
            nameChildren.add(pw.Text(item.description!, style: subStyle));
          }
          if (item.serialNumber != null && item.serialNumber!.isNotEmpty) {
            nameChildren.add(pw.Text('SN: ${item.serialNumber}', style: subStyle));
          }
          return pw.TableRow(
            decoration: altBg != null ? pw.BoxDecoration(color: altBg) : null,
            children: [
              pw.Padding(padding: pad, child: pw.Text('${e.key + 1}', style: cellStyle)),
              pw.Padding(padding: pad, child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: nameChildren)),
              pw.Padding(padding: pad, child: pw.Text(_cur(item.unitPrice), style: cellStyle)),
              pw.Padding(padding: pad, child: pw.Text('${item.quantity} ${item.unit}', style: cellStyle)),
              pw.Padding(padding: pad, child: pw.Text(_cur(item.total),
                style: pw.TextStyle(fontSize: 8.5 * fs, fontWeight: pw.FontWeight.bold))),
            ],
          );
        }),
      ],
    );
  }

  // ===== TEMPLATE 4: GST INVOICE (Traditional Indian Tax Invoice) =====

  static pw.Widget _buildGstInvoiceTemplate(Bill bill, String bName, String bAddr, String bPhone, String bGstin, bool isA5, _BankInfo bk, pw.ImageProvider? logo, String? docTitle, String? thankYouMsg, String? termsText, String upiId) {
    final isQuotation = docTitle != null;
    final fs = isA5 ? 0.78 : 1.0;
    final bdr = pw.BorderSide(color: PdfColors.black, width: 0.8);

    // Group items by GST rate for the breakdown table
    final gstGroups = <double, double>{};
    for (final item in bill.items) {
      gstGroups[item.taxRate] = (gstGroups[item.taxRate] ?? 0) + item.subtotal;
    }

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.2)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // ---- Header: Company Name, Address, GSTIN, Phone, TAX INVOICE ----
        pw.Container(
          padding: pw.EdgeInsets.all(8 * fs),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: bdr)),
          child: pw.Column(children: [
            if (logo != null) ...[pw.Center(child: pw.Container(
              width: isA5 ? 50 : 70, height: isA5 ? 50 : 70,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )), pw.SizedBox(height: 4)],
            pw.Center(child: pw.Text(bName.toUpperCase(),
              style: pw.TextStyle(fontSize: 16 * fs, fontWeight: pw.FontWeight.bold))),
            if (bAddr.isNotEmpty)
              pw.Center(child: pw.Text(bAddr, style: pw.TextStyle(fontSize: 9 * fs), textAlign: pw.TextAlign.center)),
            pw.SizedBox(height: 2 * fs),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              if (bGstin.isNotEmpty) pw.Text('GSTIN: $bGstin', style: pw.TextStyle(fontSize: 9 * fs, fontWeight: pw.FontWeight.bold)),
              if (bPhone.isNotEmpty) pw.Text('Ph: $bPhone', style: pw.TextStyle(fontSize: 9 * fs)),
            ]),
            pw.Container(
              margin: pw.EdgeInsets.only(top: 4 * fs),
              padding: pw.EdgeInsets.symmetric(vertical: 2 * fs),
              decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5), bottom: pw.BorderSide(width: 0.5))),
              child: pw.Center(child: pw.Text(docTitle ?? 'TAX INVOICE',
                style: pw.TextStyle(fontSize: 11 * fs, fontWeight: pw.FontWeight.bold, letterSpacing: 1))),
            ),
          ]),
        ),

        // ---- Sold To, Invoice No, Date ----
        pw.Container(
          padding: pw.EdgeInsets.symmetric(horizontal: 8 * fs, vertical: 6 * fs),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: bdr)),
          child: pw.Column(children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Sold to, ${bill.customerName ?? "Walk-in Customer"}',
                  style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold)),
                if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty)
                  pw.Text('Ph: ${bill.customerPhone}', style: pw.TextStyle(fontSize: 8 * fs)),
              ])),
              pw.Text('Original', style: pw.TextStyle(fontSize: 9 * fs, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 3 * fs),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Text('No.: ', style: pw.TextStyle(fontSize: 9 * fs)),
              pw.SizedBox(width: 4),
              pw.Text(bill.billNumber, style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 20 * fs),
              pw.Text('Date: ', style: pw.TextStyle(fontSize: 9 * fs)),
              pw.Text(_fmtDate(bill.createdAt), style: pw.TextStyle(fontSize: 10 * fs, fontWeight: pw.FontWeight.bold)),
            ]),
          ]),
        ),
        // ---- Items Table ----
        _buildGstItemsTable(bill, fs),

        // ---- GST Breakdown + Totals side by side ----
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border(bottom: bdr)),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            // Left: GST Breakdown table
            pw.Expanded(flex: 3, child: pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border(right: bdr)),
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tCell('GST%', fs, bold: true),
                      _tCell('Taxable Amt', fs, bold: true, align: pw.Alignment.centerRight),
                      _tCell('CGST', fs, bold: true, align: pw.Alignment.centerRight),
                      _tCell('SGST', fs, bold: true, align: pw.Alignment.centerRight),
                      _tCell('IGST', fs, bold: true, align: pw.Alignment.centerRight),
                    ]),
                  ...gstGroups.entries.map((g) => pw.TableRow(children: [
                    _tCell('${g.key.toStringAsFixed(1)}', fs),
                    _tCell(g.value.toStringAsFixed(2), fs, align: pw.Alignment.centerRight),
                    _tCell((g.value * g.key / 200).toStringAsFixed(2), fs, align: pw.Alignment.centerRight),
                    _tCell((g.value * g.key / 200).toStringAsFixed(2), fs, align: pw.Alignment.centerRight),
                    _tCell('.00', fs, align: pw.Alignment.centerRight),
                  ])),
                  // GST Totals row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _tCell('Total', fs, bold: true),
                      _tCell(bill.subtotal.toStringAsFixed(2), fs, bold: true, align: pw.Alignment.centerRight),
                      _tCell(bill.totalCgst.toStringAsFixed(2), fs, bold: true, align: pw.Alignment.centerRight),
                      _tCell(bill.totalSgst.toStringAsFixed(2), fs, bold: true, align: pw.Alignment.centerRight),
                      _tCell('.00', fs, bold: true, align: pw.Alignment.centerRight),
                    ]),
                ],
              ),
            )),
            // Right: Totals summary
            pw.Expanded(flex: 2, child: pw.Padding(
              padding: pw.EdgeInsets.all(6 * fs),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                _gstTotalLine('Total', bill.subtotal, fs),
                if (bill.discount > 0)
                  _gstTotalLine('Discount', -bill.discount, fs),
                _gstTotalLine('CGST Total', bill.totalCgst, fs),
                _gstTotalLine('SGST Total', bill.totalSgst, fs),
                _gstTotalLine('Round off', 0, fs),
                pw.SizedBox(height: 4 * fs),
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(vertical: 4 * fs, horizontal: 6 * fs),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1.5),
                    color: PdfColors.grey100),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Grand Total Rs.', style: pw.TextStyle(fontSize: 11 * fs, fontWeight: pw.FontWeight.bold)),
                    pw.Text(bill.totalAmount.toStringAsFixed(2),
                      style: pw.TextStyle(fontSize: 12 * fs, fontWeight: pw.FontWeight.bold)),
                  ]),
                ),
                if (bill.discount > 0) ...[
                  pw.SizedBox(height: 4 * fs),
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(horizontal: 6 * fs, vertical: 3 * fs),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(3),
                      border: pw.Border.all(color: PdfColors.green200)),
                    child: pw.Text('YOU SAVED ${_cur(bill.discount)}',
                      style: pw.TextStyle(fontSize: 9 * fs, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                  ),
                ],
              ]),
            )),
          ]),
        ),

        // ---- Rupees in words ----
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(horizontal: 8 * fs, vertical: 4 * fs),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: bdr)),
          child: pw.Text('Rupees in words: ${_amountToWords(bill.totalAmount)} Only',
            style: pw.TextStyle(fontSize: 9 * fs, fontWeight: pw.FontWeight.bold)),
        ),

        // ---- Bank Details + Signature ----
        pw.Container(
          padding: pw.EdgeInsets.all(8 * fs),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            // Left: Bank details & Terms
            pw.Expanded(flex: 3, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(
                padding: pw.EdgeInsets.all(6 * fs),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5), borderRadius: pw.BorderRadius.circular(2)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('E.&.O.E.', style: pw.TextStyle(fontSize: 8 * fs, fontWeight: pw.FontWeight.bold)),
                  if (bk.hasData) ...[   
                    pw.SizedBox(height: 3 * fs),
                    if (bk.name.isNotEmpty) pw.Text('Bank Name: ${bk.name}', style: pw.TextStyle(fontSize: 7 * fs)),
                    if (bk.account.isNotEmpty) pw.Text('A/C No: ${bk.account}', style: pw.TextStyle(fontSize: 7 * fs)),
                    if (bk.ifsc.isNotEmpty) pw.Text('IFSC: ${bk.ifsc}', style: pw.TextStyle(fontSize: 7 * fs, fontWeight: pw.FontWeight.bold)),
                  ],
                  pw.SizedBox(height: 2 * fs),
                  pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 7 * fs, fontWeight: pw.FontWeight.bold)),
                  pw.Text(termsText ?? 'Goods once sold cannot be taken back.', style: pw.TextStyle(fontSize: 7 * fs)),
                ]),
              ),
            ])),
            pw.SizedBox(width: 16 * fs),
            // Right: Signature
            pw.Expanded(flex: 2, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('FOR ${bName.toUpperCase()}', style: pw.TextStyle(fontSize: 9 * fs, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 24 * fs),
              pw.Container(width: 120 * fs, child: pw.Divider(color: PdfColors.black)),
              pw.Text('Proprietor', style: pw.TextStyle(fontSize: 8 * fs)),
            ])),
          ]),
        ),

        // ---- UPI QR ----
        if (upiId.isNotEmpty) pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: 8 * fs),
          child: _upiQrBlock(upiId, bName, bill.totalAmount, bill.billNumber, fs),
        ),

        // ---- Footer ----
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: 4 * fs),
          decoration: pw.BoxDecoration(border: pw.Border(top: bdr)),
          child: pw.Center(child: pw.Text(thankYouMsg ?? 'Thank you..... visit again.',
            style: pw.TextStyle(fontSize: 9 * fs, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600))),
        ),
      ]),
    );
  }

  static pw.Widget _tCell(String text, double fs, {bool bold = false, pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 3 * fs, vertical: 2 * fs),
      alignment: align,
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8 * fs, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _gstTotalLine(String label, double value, double fs) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 1 * fs),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9 * fs)),
        pw.Text(value.toStringAsFixed(2), style: pw.TextStyle(fontSize: 9 * fs, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  static String _amountToWords(double amount) {
    final rupees = amount.truncate();
    if (rupees == 0) return 'Zero';
    
    const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String twoDigit(int n) {
      if (n < 20) return ones[n];
      return '${tens[n ~/ 10]}${n % 10 > 0 ? ' ${ones[n % 10]}' : ''}';
    }

    String threeDigit(int n) {
      if (n >= 100) {
        return '${ones[n ~/ 100]} Hundred${n % 100 > 0 ? ' And ${twoDigit(n % 100)}' : ''}';
      }
      return twoDigit(n);
    }

    // Indian number system: Crore, Lakh, Thousand, Hundred
    var remaining = rupees;
    final parts = <String>[];
    
    if (remaining >= 10000000) {
      parts.add('${threeDigit(remaining ~/ 10000000)} Crore');
      remaining %= 10000000;
    }
    if (remaining >= 100000) {
      parts.add('${twoDigit(remaining ~/ 100000)} Lakh');
      remaining %= 100000;
    }
    if (remaining >= 1000) {
      parts.add('${twoDigit(remaining ~/ 1000)} Thousand');
      remaining %= 1000;
    }
    if (remaining > 0) {
      parts.add(threeDigit(remaining));
    }

    return parts.join(' ');
  }
}

class _BankInfo {
  final String name;
  final String account;
  final String ifsc;
  const _BankInfo(this.name, this.account, this.ifsc);
  bool get hasData => name.isNotEmpty || account.isNotEmpty || ifsc.isNotEmpty;
}


