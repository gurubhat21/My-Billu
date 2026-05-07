import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bill.dart';
import '../models/purchase.dart';
import '../models/expense.dart';

class ReportPdfExporter {
  static String _fc(double amount) => '₹${amount.toStringAsFixed(2)}';
  static String _fd(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ══════════════ SALES REPORT PDF ══════════════
  static Future<Uint8List> generateSalesReport({
    required List<Bill> bills,
    required String period,
    required String businessName,
  }) async {
    final pdf = pw.Document();
    final totalSales = bills.fold<double>(0, (s, b) => s + b.totalAmount);
    final totalTax = bills.fold<double>(0, (s, b) => s + b.totalTax);
    final totalDiscount = bills.fold<double>(0, (s, b) => s + b.discount);
    final totalPaid = bills.fold<double>(0, (s, b) => s + b.paidAmount);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _reportHeader(businessName, 'Sales Report', period),
      footer: (ctx) => _reportFooter(ctx),
      build: (ctx) => [
        // Summary
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryItem('Total Sales', _fc(totalSales)),
            _summaryItem('Bills', '${bills.length}'),
            _summaryItem('Tax Collected', _fc(totalTax)),
            _summaryItem('Discounts', _fc(totalDiscount)),
            _summaryItem('Collected', _fc(totalPaid)),
          ])),
        pw.SizedBox(height: 20),
        // Table
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellHeight: 24,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          headers: ['#', 'Bill No', 'Customer', 'Date', 'Subtotal', 'Tax', 'Total', 'Paid', 'Status'],
          data: bills.asMap().entries.map((e) {
            final b = e.value;
            return ['${e.key + 1}', b.billNumber, b.customerName ?? 'Walk-in', _fd(b.createdAt),
              _fc(b.subtotal), _fc(b.totalTax), _fc(b.totalAmount), _fc(b.paidAmount), b.status.name.toUpperCase()];
          }).toList(),
        ),
      ],
    ));
    return pdf.save();
  }

  // ══════════════ GST REPORT PDF ══════════════
  static Future<Uint8List> generateGSTReport({
    required List<Bill> bills,
    required String period,
    required String businessName,
  }) async {
    final pdf = pw.Document();
    final gstByRate = <double, List<double>>{};
    for (final bill in bills) {
      for (final item in bill.items) {
        gstByRate.putIfAbsent(item.taxRate, () => [0, 0, 0, 0, 0]);
        gstByRate[item.taxRate]![0] += item.subtotal;
        gstByRate[item.taxRate]![1] += item.cgst;
        gstByRate[item.taxRate]![2] += item.sgst;
        gstByRate[item.taxRate]![3] += item.taxAmount;
        gstByRate[item.taxRate]![4] += 1;
      }
    }
    final sortedRates = gstByRate.keys.toList()..sort();
    final totalTaxable = bills.fold<double>(0, (s, b) => s + b.subtotal);
    final totalCGST = bills.fold<double>(0, (s, b) => s + b.totalCgst);
    final totalSGST = bills.fold<double>(0, (s, b) => s + b.totalSgst);
    final totalGST = bills.fold<double>(0, (s, b) => s + b.totalTax);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _reportHeader(businessName, 'GST Report', period),
      footer: (ctx) => _reportFooter(ctx),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: PdfColors.teal50, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryItem('Taxable Value', _fc(totalTaxable)),
            _summaryItem('CGST', _fc(totalCGST)),
            _summaryItem('SGST', _fc(totalSGST)),
            _summaryItem('Total GST', _fc(totalGST)),
          ])),
        pw.SizedBox(height: 20),
        pw.Text('GST Slab-wise Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellHeight: 24,
          headers: ['GST Rate', 'Items', 'Taxable Value', 'CGST', 'SGST', 'Total Tax'],
          data: [
            ...sortedRates.map((rate) {
              final d = gstByRate[rate]!;
              return ['${rate.toStringAsFixed(0)}%', '${d[4].toInt()}', _fc(d[0]), _fc(d[1]), _fc(d[2]), _fc(d[3])];
            }),
            ['TOTAL', '', _fc(totalTaxable), _fc(totalCGST), _fc(totalSGST), _fc(totalGST)],
          ],
        ),
      ],
    ));
    return pdf.save();
  }

  // ══════════════ P&L REPORT PDF ══════════════
  static Future<Uint8List> generatePnLReport({
    required List<Bill> bills,
    required List<Purchase> purchases,
    required List<Expense> expenses,
    required String period,
    required String businessName,
  }) async {
    final pdf = pw.Document();

    final totalSales = bills.fold<double>(0, (s, b) => s + b.totalAmount);
    final salesSubtotal = bills.fold<double>(0, (s, b) => s + b.subtotal);
    final salesTax = bills.fold<double>(0, (s, b) => s + b.totalTax);
    final salesDiscount = bills.fold<double>(0, (s, b) => s + b.discount);
    final totalPurchases = purchases.fold<double>(0, (s, p) => s + p.totalAmount);
    final purchaseSubtotal = purchases.fold<double>(0, (s, p) => s + p.subtotal);
    final purchaseTax = purchases.fold<double>(0, (s, p) => s + p.totalTax);
    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
    final grossProfit = salesSubtotal - purchaseSubtotal;
    final netProfit = totalSales - totalPurchases - totalExpenses;
    final netTaxLiab = salesTax - purchaseTax;

    // Expense breakdown
    final expByCat = <String, double>{};
    for (final e in expenses) {
      expByCat[e.category.label] = (expByCat[e.category.label] ?? 0) + e.amount;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _reportHeader(businessName, 'Profit & Loss Report', period),
      footer: (ctx) => _reportFooter(ctx),
      build: (ctx) => [
        // P&L Statement
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: netProfit >= 0 ? PdfColors.green50 : PdfColors.red50,
            borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryItem('Revenue', _fc(totalSales)),
            _summaryItem('Purchases', _fc(totalPurchases)),
            _summaryItem('Expenses', _fc(totalExpenses)),
            _summaryItem(netProfit >= 0 ? 'Net Profit' : 'Net Loss', _fc(netProfit.abs())),
          ])),
        pw.SizedBox(height: 24),

        // Revenue section
        _sectionTitle('REVENUE'),
        _pnlLine('Sales Revenue', salesSubtotal),
        _pnlLine('GST Collected', salesTax),
        _pnlLine('Less: Discounts', -salesDiscount),
        _pnlLine('Total Revenue', totalSales, bold: true),
        pw.Divider(),
        pw.SizedBox(height: 8),

        // COGS
        _sectionTitle('COST OF GOODS SOLD'),
        _pnlLine('Purchase Cost', purchaseSubtotal),
        _pnlLine('GST on Purchases', purchaseTax),
        _pnlLine('Total Purchases', totalPurchases, bold: true),
        pw.Divider(),
        pw.SizedBox(height: 8),

        // Gross Profit
        _pnlLine('GROSS PROFIT', grossProfit, bold: true, highlight: true),
        pw.SizedBox(height: 12),

        // Operating Expenses
        if (expenses.isNotEmpty) ...[
          _sectionTitle('OPERATING EXPENSES'),
          ...expByCat.entries.map((e) => _pnlLine(e.key, e.value)),
          _pnlLine('Total Expenses', totalExpenses, bold: true),
          pw.Divider(),
          pw.SizedBox(height: 8),
        ],

        // Tax
        _pnlLine('Net Tax Liability (GST Out - GST In)', netTaxLiab),
        pw.SizedBox(height: 12),

        // Net Profit
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: netProfit >= 0 ? PdfColors.green100 : PdfColors.red100,
            borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(_fc(netProfit.abs()),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold,
                color: netProfit >= 0 ? PdfColors.green800 : PdfColors.red800)),
          ])),
      ],
    ));
    return pdf.save();
  }

  // ══════════════ HELPERS ══════════════

  static pw.Widget _reportHeader(String businessName, String reportTitle, String period) {
    return pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text(reportTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Period: $period', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Generated: ${_fd(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ]),
      ]),
      pw.SizedBox(height: 8),
      pw.Divider(color: PdfColors.indigo),
      pw.SizedBox(height: 12),
    ]);
  }

  static pw.Widget _reportFooter(pw.Context ctx) {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Generated by My Billu', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ]),
    ]);
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    ]);
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)));
  }

  static pw.Widget _pnlLine(String label, double amount, {bool bold = false, bool highlight = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 3, horizontal: highlight ? 8 : 0),
      decoration: highlight ? pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)) : null,
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: bold ? 11 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(_fc(amount), style: pw.TextStyle(fontSize: bold ? 11 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]));
  }

  /// Print a report PDF
  static Future<void> printReport(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Share/download a report PDF
  static Future<void> shareReport(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } else {
      final xFile = XFile.fromData(bytes, mimeType: 'application/pdf', name: filename);
      await Share.shareXFiles([xFile]);
    }
  }
}
