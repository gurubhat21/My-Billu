import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/bill.dart';
import '../models/purchase.dart';
import '../models/expense.dart';

/// Tally-style professional PDF report generator
class ReportPdfExporter {
  static String _fc(double a) => a < 0 ? '(${_fcp(a.abs())})' : _fcp(a);
  static String _fcp(double a) {
    // Indian number format: 1,23,456.00
    final parts = a.toStringAsFixed(2).split('.');
    String num = parts[0];
    String result = '';
    if (num.length <= 3) {
      result = num;
    } else {
      result = num.substring(num.length - 3);
      num = num.substring(0, num.length - 3);
      while (num.length > 2) {
        result = '${num.substring(num.length - 2)},$result';
        num = num.substring(0, num.length - 2);
      }
      result = '$num,$result';
    }
    return '$result.${parts[1]}';
  }
  static String _fd(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${_monthShort(d.month)}-${d.year}';
  static String _monthShort(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  // ═══════ COLORS ═══════
  static const _headerBg = PdfColor.fromInt(0xFF1a1a2e);
  static const _accentBlue = PdfColor.fromInt(0xFF16213e);
  static const _lightBg = PdfColor.fromInt(0xFFF8F9FA);
  static const _borderColor = PdfColor.fromInt(0xFFDEE2E6);
  static const _greenText = PdfColor.fromInt(0xFF198754);
  static const _redText = PdfColor.fromInt(0xFFDC3545);

  // ═══════ TALLY HEADER ═══════
  static pw.Widget _tallyHeader(String companyName, String reportTitle, String period) {
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        color: _headerBg,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: pw.Column(children: [
        pw.Text(companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        pw.SizedBox(height: 4),
        pw.Text(reportTitle, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.amber200)),
        pw.SizedBox(height: 2),
        pw.Text(period, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
      ]),
    );
  }

  // ═══════ TABLE HELPERS ═══════
  static pw.Widget _tableRow(List<String> cells, {bool isHeader = false, bool isTotal = false, bool isBold = false, bool isSubTotal = false, PdfColor? valueColor, List<double>? widths}) {
    final bgColor = isHeader ? _accentBlue : (isTotal ? const PdfColor.fromInt(0xFFE8F5E9) : (isSubTotal ? _lightBg : null));
    final textColor = isHeader ? PdfColors.white : (valueColor ?? PdfColors.black);
    final weight = (isHeader || isTotal || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal;
    final fontSize = isHeader ? 9.0 : (isTotal ? 10.0 : 9.0);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border(bottom: pw.BorderSide(color: isTotal ? PdfColors.black : _borderColor, width: isTotal ? 1.5 : 0.5)),
      ),
      padding: pw.EdgeInsets.symmetric(vertical: isTotal ? 6 : 4, horizontal: 6),
      child: pw.Row(
        children: cells.asMap().entries.map((e) {
          final isFirst = e.key == 0;
          final flex = widths != null ? widths[e.key] : (isFirst ? 4.0 : 2.0);
          return pw.Expanded(
            flex: (flex * 10).toInt(),
            child: pw.Text(e.value,
              textAlign: isFirst ? pw.TextAlign.left : pw.TextAlign.right,
              style: pw.TextStyle(fontSize: fontSize, fontWeight: weight, color: isFirst ? textColor : (valueColor ?? textColor)),
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _sectionLabel(String label) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: const pw.BoxDecoration(color: _lightBg, border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.5))),
      child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF495057))),
    );
  }

  static pw.Widget _doubleLineTotal(String label, String value, {PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 1), bottom: pw.BorderSide(color: PdfColors.black, width: 2.5))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color ?? PdfColors.black)),
      ]),
    );
  }

  static pw.Widget _pnlRow(String label, String amount, {int indent = 0, bool bold = false, PdfColor? color}) {
    return pw.Container(
      padding: pw.EdgeInsets.only(left: 8.0 + indent * 16, right: 8, top: 3, bottom: 3),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.3))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: bold ? 10 : 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(amount, style: pw.TextStyle(fontSize: bold ? 10 : 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ]),
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _borderColor))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Generated by My Billu | ${_fd(DateTime.now())}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
      ]),
    );
  }

  // ══════════════════════════════════════════════
  //  SALES REPORT — Tally Daybook Style
  // ══════════════════════════════════════════════
  static Future<Uint8List> generateSalesReport({
    required List<Bill> bills,
    required String period,
    required String businessName,
  }) async {
    final pdf = pw.Document();
    final totalSales = bills.fold<double>(0, (s, b) => s + b.totalAmount);
    final totalTax = bills.fold<double>(0, (s, b) => s + b.totalTax);
    final totalSub = bills.fold<double>(0, (s, b) => s + b.subtotal);
    final totalDisc = bills.fold<double>(0, (s, b) => s + b.discount);
    final totalPaid = bills.fold<double>(0, (s, b) => s + b.paidAmount);
    final totalDue = bills.fold<double>(0, (s, b) => s + b.balanceDue);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Column(children: [
        _tallyHeader(businessName, 'Sales Register', period),
        pw.SizedBox(height: 10),
      ]),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        // Summary box
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderColor), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Row(children: [
            _summaryBox('Total Sales', _fc(totalSales)),
            _summaryBox('Invoices', '${bills.length}'),
            _summaryBox('Taxable Value', _fc(totalSub)),
            _summaryBox('GST', _fc(totalTax)),
            _summaryBox('Collected', _fc(totalPaid)),
            _summaryBox('Outstanding', _fc(totalDue), color: totalDue > 0 ? _redText : _greenText),
          ]),
        ),
        pw.SizedBox(height: 12),

        // Voucher Register table
        _sectionLabel('Voucher Register'),
        _tableRow(['Date', 'Voucher No.', 'Party Name', 'Taxable', 'GST', 'Discount', 'Total', 'Paid', 'Status'], isHeader: true,
          widths: [1.5, 1.5, 2.5, 1.5, 1.2, 1.2, 1.5, 1.5, 1.0]),
        ...bills.map((b) => _tableRow([
          _fd(b.createdAt), b.billNumber, b.customerName ?? 'Cash',
          _fc(b.subtotal), _fc(b.totalTax), _fc(b.discount), _fc(b.totalAmount), _fc(b.paidAmount),
          b.status.name.toUpperCase(),
        ], widths: [1.5, 1.5, 2.5, 1.5, 1.2, 1.2, 1.5, 1.5, 1.0],
           valueColor: b.status == BillStatus.paid ? null : _redText)),

        // Totals
        _tableRow(['TOTAL', '', '${bills.length} Vouchers', _fc(totalSub), _fc(totalTax), _fc(totalDisc), _fc(totalSales), _fc(totalPaid), ''],
          isTotal: true, widths: [1.5, 1.5, 2.5, 1.5, 1.2, 1.2, 1.5, 1.5, 1.0]),
        pw.SizedBox(height: 8),
        _doubleLineTotal('Net Sales Amount', _fc(totalSales)),
      ],
    ));
    return pdf.save();
  }

  // ══════════════════════════════════════════════
  //  GST REPORT — Tally GSTR-1 Style
  // ══════════════════════════════════════════════
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
    final totalInvoice = bills.fold<double>(0, (s, b) => s + b.totalAmount);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Column(children: [
        _tallyHeader(businessName, 'GST Computation Report', period),
        pw.SizedBox(height: 10),
      ]),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        // Tax Summary
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderColor), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Row(children: [
            _summaryBox('Taxable Value', _fc(totalTaxable)),
            _summaryBox('CGST', _fc(totalCGST)),
            _summaryBox('SGST', _fc(totalSGST)),
            _summaryBox('Total Tax', _fc(totalGST)),
            _summaryBox('Invoice Total', _fc(totalInvoice)),
          ]),
        ),
        pw.SizedBox(height: 16),

        // Rate-wise summary
        _sectionLabel('Tax Rate-wise Summary'),
        _tableRow(['GST Slab', 'No. of Items', 'Taxable Value', 'CGST (₹)', 'SGST (₹)', 'Total Tax (₹)'], isHeader: true,
          widths: [1.5, 1.2, 2, 1.5, 1.5, 1.8]),
        ...sortedRates.map((rate) {
          final d = gstByRate[rate]!;
          return _tableRow(['${rate.toStringAsFixed(1)}%', '${d[4].toInt()}', _fc(d[0]), _fc(d[1]), _fc(d[2]), _fc(d[3])],
            widths: [1.5, 1.2, 2, 1.5, 1.5, 1.8]);
        }),
        _tableRow(['TOTAL', '', _fc(totalTaxable), _fc(totalCGST), _fc(totalSGST), _fc(totalGST)],
          isTotal: true, widths: [1.5, 1.2, 2, 1.5, 1.5, 1.8]),
        pw.SizedBox(height: 16),

        // Invoice-wise GST
        _sectionLabel('Invoice-wise Tax Details'),
        _tableRow(['Date', 'Invoice No.', 'Party', 'Taxable', 'CGST', 'SGST', 'Total Tax', 'Invoice Amt'], isHeader: true,
          widths: [1.3, 1.5, 2.2, 1.5, 1.2, 1.2, 1.3, 1.5]),
        ...bills.map((b) => _tableRow([
          _fd(b.createdAt), b.billNumber, b.customerName ?? 'Cash',
          _fc(b.subtotal), _fc(b.totalCgst), _fc(b.totalSgst), _fc(b.totalTax), _fc(b.totalAmount),
        ], widths: [1.3, 1.5, 2.2, 1.5, 1.2, 1.2, 1.3, 1.5])),
        _tableRow(['TOTAL', '', '${bills.length} Invoices', _fc(totalTaxable), _fc(totalCGST), _fc(totalSGST), _fc(totalGST), _fc(totalInvoice)],
          isTotal: true, widths: [1.3, 1.5, 2.2, 1.5, 1.2, 1.2, 1.3, 1.5]),

        pw.SizedBox(height: 8),
        _doubleLineTotal('Net GST Liability', _fc(totalGST)),
      ],
    ));
    return pdf.save();
  }

  // ══════════════════════════════════════════════
  //  PROFIT & LOSS — Tally P&L Account Style
  // ══════════════════════════════════════════════
  static Future<Uint8List> generatePnLReport({
    required List<Bill> bills,
    required List<Purchase> purchases,
    required List<Expense> expenses,
    required String period,
    required String businessName,
  }) async {
    final pdf = pw.Document();

    final totalSales = bills.fold<double>(0, (s, b) => s + b.totalAmount);
    final salesSub = bills.fold<double>(0, (s, b) => s + b.subtotal);
    final salesTax = bills.fold<double>(0, (s, b) => s + b.totalTax);
    final salesDisc = bills.fold<double>(0, (s, b) => s + b.discount);
    final totalPurch = purchases.fold<double>(0, (s, p) => s + p.totalAmount);
    final purchSub = purchases.fold<double>(0, (s, p) => s + p.subtotal);
    final purchTax = purchases.fold<double>(0, (s, p) => s + p.totalTax);
    final totalExp = expenses.fold<double>(0, (s, e) => s + e.amount);
    final grossProfit = salesSub - purchSub;
    final netProfit = totalSales - totalPurch - totalExp;
    final netTax = salesTax - purchTax;
    final marginPct = salesSub > 0 ? (grossProfit / salesSub * 100) : 0.0;

    final expByCat = <String, double>{};
    for (final e in expenses) {
      expByCat[e.category.label] = (expByCat[e.category.label] ?? 0) + e.amount;
    }
    final sortedExpCats = expByCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Column(children: [
        _tallyHeader(businessName, 'Profit & Loss Account', period),
        pw.SizedBox(height: 10),
      ]),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        // ── TRADING ACCOUNT ──
        _sectionLabel('Trading Account'),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderColor)),
          child: pw.Column(children: [
            _tableRow(['Particulars', 'Amount (₹)'], isHeader: true, widths: [3, 2]),
            _pnlRow('Sales Revenue (Net of GST)', _fc(salesSub)),
            _pnlRow('Add: GST Collected (Output Tax)', _fc(salesTax), indent: 1),
            if (salesDisc > 0) _pnlRow('Less: Discounts Given', _fc(salesDisc), indent: 1),
            _pnlRow('Total Revenue', _fc(totalSales), bold: true, color: _greenText),
            pw.SizedBox(height: 4),
            _pnlRow('Less: Purchase Cost', _fc(purchSub)),
            _pnlRow('Add: GST on Purchases (Input Tax)', _fc(purchTax), indent: 1),
            _pnlRow('Total Purchases', _fc(totalPurch), bold: true, color: _redText),
          ]),
        ),
        pw.SizedBox(height: 4),
        _doubleLineTotal('Gross Profit / (Loss)', _fc(grossProfit), color: grossProfit >= 0 ? _greenText : _redText),
        pw.SizedBox(height: 4),
        _pnlRow('Gross Profit Margin', '${marginPct.toStringAsFixed(1)}%', bold: true),

        pw.SizedBox(height: 16),

        // ── OPERATING EXPENSES ──
        if (expenses.isNotEmpty) ...[
          _sectionLabel('Operating Expenses (Indirect Expenses)'),
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderColor)),
            child: pw.Column(children: [
              _tableRow(['Expense Head', 'Amount (₹)'], isHeader: true, widths: [3, 2]),
              ...sortedExpCats.map((e) => _pnlRow(e.key, _fc(e.value), indent: 1)),
            ]),
          ),
          pw.SizedBox(height: 4),
          _doubleLineTotal('Total Operating Expenses', _fc(totalExp), color: _redText),
          pw.SizedBox(height: 16),
        ],

        // ── TAX LIABILITY ──
        _sectionLabel('Tax Computation'),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderColor)),
          child: pw.Column(children: [
            _pnlRow('Output GST (Collected on Sales)', _fc(salesTax)),
            _pnlRow('Less: Input GST (Paid on Purchases)', _fc(purchTax)),
          ]),
        ),
        pw.SizedBox(height: 4),
        _doubleLineTotal('Net GST Payable / (Receivable)', _fc(netTax), color: netTax > 0 ? _redText : _greenText),

        pw.SizedBox(height: 16),

        // ── NET PROFIT ──
        _sectionLabel('Profit & Loss Summary'),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderColor)),
          child: pw.Column(children: [
            _pnlRow('Gross Profit', _fc(grossProfit), color: grossProfit >= 0 ? _greenText : _redText),
            _pnlRow('Less: Operating Expenses', _fc(totalExp)),
            _pnlRow('Less: Net Tax Liability', _fc(netTax > 0 ? netTax : 0)),
          ]),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: netProfit >= 0 ? const PdfColor.fromInt(0xFFD4EDDA) : const PdfColor.fromInt(0xFFF8D7DA),
            border: pw.Border.all(color: netProfit >= 0 ? _greenText : _redText, width: 1.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: netProfit >= 0 ? _greenText : _redText)),
            pw.Text(_fc(netProfit.abs()),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: netProfit >= 0 ? _greenText : _redText)),
          ]),
        ),

        pw.SizedBox(height: 20),

        // ── KEY RATIOS ──
        _sectionLabel('Key Financial Ratios'),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderColor)),
          child: pw.Column(children: [
            _pnlRow('Total Invoices', '${bills.length}'),
            _pnlRow('Total Purchase Orders', '${purchases.length}'),
            _pnlRow('Avg Invoice Value', bills.isNotEmpty ? _fc(totalSales / bills.length) : '0.00'),
            _pnlRow('Gross Profit Margin', '${marginPct.toStringAsFixed(1)}%'),
            _pnlRow('Net Profit Margin', salesSub > 0 ? '${(netProfit / salesSub * 100).toStringAsFixed(1)}%' : '0.0%'),
            _pnlRow('Operating Expense Ratio', totalSales > 0 ? '${(totalExp / totalSales * 100).toStringAsFixed(1)}%' : '0.0%'),
          ]),
        ),
      ],
    ));
    return pdf.save();
  }

  // ═══════ SUMMARY BOX ═══════
  static pw.Widget _summaryBox(String label, String value, {PdfColor? color}) {
    return pw.Expanded(child: pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color ?? PdfColors.black)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
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
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')]);
    }
  }
}


