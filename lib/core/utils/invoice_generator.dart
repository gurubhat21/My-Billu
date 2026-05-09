import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bill.dart';

enum InvoiceTemplate { modern, classic, thermal }

class InvoiceGenerator {
  static Future<void> generateAndPrint(
    Bill bill, {
    String businessName = 'My Billu',
    String businessAddress = '',
    String businessPhone = '',
    String businessGstin = '',
    InvoiceTemplate template = InvoiceTemplate.modern,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName,
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    if (businessAddress.isNotEmpty)
                      pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    if (businessPhone.isNotEmpty)
                      pw.Text('Phone: $businessPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    if (businessGstin.isNotEmpty)
                      pw.Text('GSTIN: $businessGstin', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.indigo,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text('TAX INVOICE',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Invoice #: ${bill.billNumber}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${_formatDate(bill.createdAt)}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            // Customer Info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bill To:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(bill.customerName ?? 'Walk-in Customer',
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Payment: ${bill.paymentMethod.name.toUpperCase()}',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Status: ${bill.status.name.toUpperCase()}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                            color: bill.status == BillStatus.paid ? PdfColors.green700 : PdfColors.red700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Items Table
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
              headerAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellHeight: 28,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1),
                6: const pw.FlexColumnWidth(1.5),
              },
              headers: ['#', 'Item', 'Unit Price', 'Qty', 'GST %', 'GST Amt', 'Total'],
              data: bill.items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return [
                  '${i + 1}',
                  item.itemName,
                  _formatCurrency(item.unitPrice),
                  '${item.quantity} ${item.unit}',
                  '${item.taxRate}%',
                  _formatCurrency(item.taxAmount),
                  _formatCurrency(item.total),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 250,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(children: [
                    _totalRow('Subtotal', _formatCurrency(bill.subtotal)),
                    pw.SizedBox(height: 4),
                    _totalRow('CGST', _formatCurrency(bill.totalCgst)),
                    pw.SizedBox(height: 4),
                    _totalRow('SGST', _formatCurrency(bill.totalSgst)),
                    pw.Divider(color: PdfColors.grey400),
                    _totalRow('Total', _formatCurrency(bill.totalAmount), bold: true, fontSize: 14),
                    if (bill.paidAmount > 0 && bill.paidAmount < bill.totalAmount) ...[
                      pw.SizedBox(height: 4),
                      _totalRow('Paid', _formatCurrency(bill.paidAmount)),
                      pw.SizedBox(height: 4),
                      _totalRow('Balance Due', _formatCurrency(bill.balanceDue),
                          bold: true, color: PdfColors.red700),
                    ],
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Footer
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text('Thank you for your business!',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text('Generated by My Billu - Smart Billing Software',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static pw.Widget _totalRow(String label, String value,
      {bool bold = false, double fontSize = 11, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(
            fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(
            fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color)),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  /// Generate PDF bytes for a bill (reusable for print + share)
  static Future<Uint8List> generatePdfBytes(
    Bill bill, {
    String businessName = 'My Billu',
    String businessAddress = '',
    String businessPhone = '',
    String businessGstin = '',
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => _buildInvoiceContent(bill, businessName, businessAddress, businessPhone, businessGstin),
      ),
    );
    return pdf.save();
  }

  /// Share invoice PDF via WhatsApp / other apps
  static Future<void> shareInvoice(
    Bill bill, {
    String businessName = 'My Billu',
    String businessAddress = '',
    String businessPhone = '',
    String businessGstin = '',
  }) async {
    final bytes = await generatePdfBytes(bill,
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      businessGstin: businessGstin,
    );

    if (kIsWeb) {
      // On web, use printing to download
      await Printing.sharePdf(bytes: bytes, filename: 'Invoice_${bill.billNumber}.pdf');
    } else {
      // On mobile/desktop, use share_plus
      final xFile = XFile.fromData(bytes, mimeType: 'application/pdf', name: 'Invoice_${bill.billNumber}.pdf');
      await Share.shareXFiles(
        [xFile],
        text: 'Invoice ${bill.billNumber} - ${_formatCurrency(bill.totalAmount)} from $businessName',
      );
    }
  }

  /// Email invoice - opens email client with invoice details and PDF
  static Future<void> emailInvoice(
    Bill bill, {
    String? recipientEmail,
    String businessName = 'My Billu',
    String businessAddress = '',
    String businessPhone = '',
    String businessGstin = '',
  }) async {
    // Generate the PDF first for attachment
    final bytes = await generatePdfBytes(bill,
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      businessGstin: businessGstin,
    );

    // Build email body with invoice summary
    final itemsList = bill.items.map((i) =>
      '  ${i.itemName} x${i.quantity} - ${_formatCurrency(i.total)}').join('\n');

    final subject = 'Invoice ${bill.billNumber} from $businessName - ${_formatCurrency(bill.totalAmount)}';
    final body = '''Dear ${bill.customerName ?? 'Customer'},

Please find below the invoice details:

Invoice No: ${bill.billNumber}
Date: ${_formatDate(bill.createdAt)}

Items:
$itemsList

Subtotal: ${_formatCurrency(bill.subtotal)}
${bill.discount > 0 ? 'Discount: -${_formatCurrency(bill.discount)}\n' : ''}GST: ${_formatCurrency(bill.totalTax)}
Total: ${_formatCurrency(bill.totalAmount)}
${bill.paidAmount > 0 && bill.paidAmount < bill.totalAmount ? 'Paid: ${_formatCurrency(bill.paidAmount)}\nBalance Due: ${_formatCurrency(bill.balanceDue)}\n' : ''}
Thank you for your business!

$businessName
${businessPhone.isNotEmpty ? 'Phone: $businessPhone' : ''}
${businessGstin.isNotEmpty ? 'GSTIN: $businessGstin' : ''}

---
Generated by My Billu - Smart Billing Software''';

    // Share PDF as attachment via share_plus (works on all platforms)
    final xFile = XFile.fromData(bytes, mimeType: 'application/pdf', name: 'Invoice_${bill.billNumber}.pdf');
    await Share.shareXFiles(
      [xFile],
      subject: subject,
      text: body,
    );
  }

  static pw.Widget _buildInvoiceContent(Bill bill, String businessName, String businessAddress, String businessPhone, String businessGstin) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(businessName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              if (businessAddress.isNotEmpty) pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              if (businessPhone.isNotEmpty) pw.Text('Phone: $businessPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              if (businessGstin.isNotEmpty) pw.Text('GSTIN: $businessGstin', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: pw.BoxDecoration(color: PdfColors.indigo, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
              pw.SizedBox(height: 8),
              pw.Text('Invoice #: ${bill.billNumber}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date: ${_formatDate(bill.createdAt)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ]),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 12),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Bill To:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(bill.customerName ?? 'Walk-in Customer', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ])),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Payment: ${bill.paymentMethod.name.toUpperCase()}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Status: ${bill.status.name.toUpperCase()}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                color: bill.status == BillStatus.paid ? PdfColors.green700 : PdfColors.red700)),
          ]),
        ]),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellHeight: 28,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(1.2), 3: const pw.FlexColumnWidth(1), 4: const pw.FlexColumnWidth(1), 5: const pw.FlexColumnWidth(1), 6: const pw.FlexColumnWidth(1.5)},
          headers: ['#', 'Item', 'Unit Price', 'Qty', 'GST %', 'GST Amt', 'Total'],
          data: bill.items.asMap().entries.map((entry) => [
            '${entry.key + 1}', entry.value.itemName, _formatCurrency(entry.value.unitPrice),
            '${entry.value.quantity} ${entry.value.unit}', '${entry.value.taxRate}%',
            _formatCurrency(entry.value.taxAmount), _formatCurrency(entry.value.total),
          ]).toList(),
        ),
        pw.SizedBox(height: 16),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(
            width: 250, padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Column(children: [
              _totalRow('Subtotal', _formatCurrency(bill.subtotal)),
              pw.SizedBox(height: 4),
              _totalRow('CGST', _formatCurrency(bill.totalCgst)),
              pw.SizedBox(height: 4),
              _totalRow('SGST', _formatCurrency(bill.totalSgst)),
              pw.Divider(color: PdfColors.grey400),
              _totalRow('Total', _formatCurrency(bill.totalAmount), bold: true, fontSize: 14),
              if (bill.paidAmount > 0 && bill.paidAmount < bill.totalAmount) ...[
                pw.SizedBox(height: 4),
                _totalRow('Paid', _formatCurrency(bill.paidAmount)),
                pw.SizedBox(height: 4),
                _totalRow('Balance Due', _formatCurrency(bill.balanceDue), bold: true, color: PdfColors.red700),
              ],
            ])),
        ]),
        pw.SizedBox(height: 30),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('Generated by My Billu - Smart Billing Software', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500))),
      ],
    );
  }
}
