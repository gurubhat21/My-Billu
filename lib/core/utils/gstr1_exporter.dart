import 'dart:typed_data';
import 'dart:io' show Directory, File, Process;
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import '../models/bill.dart';
import '../models/customer.dart';

class GSTR1Exporter {
  static String _fc(double a) {
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

  static String _fd(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${_ms(d.month)}-${d.year}';
  static String _ms(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  // ═══════════════════════════════════════
  //  SHARED STYLES
  // ═══════════════════════════════════════
  static CellStyle get _headerStyle => CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#1a1a2e'),
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    fontSize: 11,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );
  static CellStyle get _totalStyle => CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
    fontSize: 11,
  );
  static CellStyle get _numStyle => CellStyle(
    horizontalAlign: HorizontalAlign.Right,
    fontSize: 10,
  );
  static CellStyle get _titleStyle => CellStyle(bold: true, fontSize: 14);
  static CellStyle get _subTitleStyle => CellStyle(
    bold: true, fontSize: 11,
    backgroundColorHex: ExcelColor.fromHexString('#F0F4FF'),
  );

  static void _setColWidths(Sheet sheet, List<double> widths) {
    for (int i = 0; i < widths.length; i++) sheet.setColumnWidth(i, widths[i]);
  }
  static void _styleRow(Sheet sheet, int rowIdx, int colCount, CellStyle style) {
    for (int c = 0; c < colCount; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).cellStyle = style;
    }
  }
  static void _styleNumCols(Sheet sheet, int rowIdx, List<int> cols) {
    for (final c in cols) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).cellStyle = _numStyle;
    }
  }

  // ═══════════════════════════════════════
  //  GSTR1 EXCEL EXPORT
  // ═══════════════════════════════════════
  static Future<Uint8List> generateExcel({
    required List<Bill> bills,
    required List<Customer> customers,
    required String businessName,
    required String businessAddress,
    required String period,
  }) async {
    final excel = Excel.createExcel();

    // Build customer GSTIN lookup
    final gstinMap = <String, String>{};
    for (final c in customers) {
      if (c.gstin != null && c.gstin!.isNotEmpty) {
        gstinMap[c.id] = c.gstin!;
        gstinMap[c.name] = c.gstin!;
      }
    }

    final b2bBills = <Bill>[];
    final b2cBills = <Bill>[];
    for (final b in bills) {
      String? gstin;
      if (b.customerId != null) gstin = gstinMap[b.customerId!];
      gstin ??= gstinMap[b.customerName ?? ''];
      if (gstin != null && gstin.isNotEmpty) {
        b2bBills.add(b);
      } else {
        b2cBills.add(b);
      }
    }

    String getGstin(Bill b) {
      if (b.customerId != null && gstinMap.containsKey(b.customerId!)) return gstinMap[b.customerId!]!;
      return gstinMap[b.customerName ?? ''] ?? '';
    }

    String getState(String gstin) {
      if (gstin.length < 2) return '';
      final code = int.tryParse(gstin.substring(0, 2)) ?? 0;
      const states = {
        1: 'JAMMU & KASHMIR', 2: 'HIMACHAL PRADESH', 3: 'PUNJAB', 4: 'CHANDIGARH',
        5: 'UTTARAKHAND', 6: 'HARYANA', 7: 'DELHI', 8: 'RAJASTHAN', 9: 'UTTAR PRADESH',
        10: 'BIHAR', 11: 'SIKKIM', 12: 'ARUNACHAL PRADESH', 13: 'NAGALAND', 14: 'MANIPUR',
        15: 'MIZORAM', 16: 'TRIPURA', 17: 'MEGHALAYA', 18: 'ASSAM', 19: 'WEST BENGAL',
        20: 'JHARKHAND', 21: 'ODISHA', 22: 'CHHATTISGARH', 23: 'MADHYA PRADESH',
        24: 'GUJARAT', 25: 'DAMAN & DIU', 26: 'DADRA & NAGAR HAVELI', 27: 'MAHARASHTRA',
        28: 'ANDHRA PRADESH', 29: 'KARNATAKA', 30: 'GOA', 31: 'LAKSHADWEEP',
        32: 'KERALA', 33: 'TAMIL NADU', 34: 'PUDUCHERRY', 35: 'ANDAMAN & NICOBAR',
        36: 'TELANGANA', 37: 'ANDHRA PRADESH (NEW)', 38: 'LADAKH',
      };
      return '${code}-${states[code] ?? ''}';
    }

    // ══════════════════════════════
    //  B2B SHEET
    // ══════════════════════════════
    final b2bSheet = excel['B2B'];
    excel.setDefaultSheet('B2B');

    // Title
    b2bSheet.appendRow([TextCellValue('GSTR-1 B2B Invoices — $businessName — $period')]);
    b2bSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = _titleStyle;
    b2bSheet.appendRow([TextCellValue('Invoices issued to Registered Dealers (with GSTIN)')]);
    b2bSheet.appendRow([]);

    // Headers (row 3)
    const b2bHeaders = ['GSTIN/UIN', 'Receiver Name', 'Invoice No', 'Invoice Date',
      'Invoice Value', 'Place Of Supply', 'Reverse Charge', 'Invoice Type',
      'Rate %', 'Taxable Value', 'Cess', 'CGST', 'SGST'];
    b2bSheet.appendRow(b2bHeaders.map((h) => TextCellValue(h)).toList());
    _styleRow(b2bSheet, 3, b2bHeaders.length, _headerStyle);
    _setColWidths(b2bSheet, [22, 22, 16, 14, 15, 22, 14, 14, 8, 16, 10, 14, 14]);

    final b2bNumCols = [4, 8, 9, 10, 11, 12];
    double b2bTotalTaxable = 0, b2bTotalCgst = 0, b2bTotalSgst = 0, b2bTotalValue = 0;
    int row = 4;
    for (final b in b2bBills) {
      final gstin = getGstin(b);
      final state = getState(gstin);
      final rateMap = <double, List<BillItem>>{};
      for (final item in b.items) {
        rateMap.putIfAbsent(item.taxRate, () => []).add(item);
      }
      for (final entry in rateMap.entries) {
        final rate = entry.key;
        final items = entry.value;
        final taxable = items.fold<double>(0, (s, i) => s + i.subtotal);
        final cgst = items.fold<double>(0, (s, i) => s + i.cgst);
        final sgst = items.fold<double>(0, (s, i) => s + i.sgst);
        b2bTotalTaxable += taxable;
        b2bTotalCgst += cgst;
        b2bTotalSgst += sgst;
        b2bTotalValue += b.totalAmount;
        b2bSheet.appendRow([
          TextCellValue(gstin), TextCellValue(b.customerName ?? 'N/A'),
          TextCellValue(b.billNumber), TextCellValue(_fd(b.createdAt)),
          DoubleCellValue(b.totalAmount), TextCellValue(state),
          TextCellValue('N'), TextCellValue('Regular'),
          DoubleCellValue(rate), DoubleCellValue(taxable),
          DoubleCellValue(0), DoubleCellValue(cgst), DoubleCellValue(sgst),
        ]);
        _styleNumCols(b2bSheet, row, b2bNumCols);
        row++;
      }
    }
    // Total
    b2bSheet.appendRow([
      TextCellValue('TOTAL'), TextCellValue('${b2bBills.length} invoices'),
      TextCellValue(''), TextCellValue(''),
      DoubleCellValue(b2bTotalValue), TextCellValue(''), TextCellValue(''), TextCellValue(''),
      TextCellValue(''), DoubleCellValue(b2bTotalTaxable),
      DoubleCellValue(0), DoubleCellValue(b2bTotalCgst), DoubleCellValue(b2bTotalSgst),
    ]);
    _styleRow(b2bSheet, row, b2bHeaders.length, _totalStyle);

    // ══════════════════════════════
    //  B2C SHEET
    // ══════════════════════════════
    final b2cSheet = excel['B2C'];

    b2cSheet.appendRow([TextCellValue('GSTR-1 B2C Summary — $businessName — $period')]);
    b2cSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = _titleStyle;
    b2cSheet.appendRow([TextCellValue('Sales to Unregistered Consumers (without GSTIN) — Rate-wise')]);
    b2cSheet.appendRow([]);

    const b2cHeaders = ['Type', 'Rate %', 'No. of Invoices', 'Taxable Value', 'CGST', 'SGST', 'Total Tax', 'Total Value'];
    b2cSheet.appendRow(b2cHeaders.map((h) => TextCellValue(h)).toList());
    _styleRow(b2cSheet, 3, b2cHeaders.length, _headerStyle);
    _setColWidths(b2cSheet, [10, 10, 16, 18, 14, 14, 14, 18]);

    final b2cNumCols = [1, 2, 3, 4, 5, 6, 7];
    final b2cByRate = <double, double>{};
    final b2cCgstByRate = <double, double>{};
    final b2cSgstByRate = <double, double>{};
    final b2cTotalByRate = <double, double>{};
    final b2cCountByRate = <double, int>{};
    for (final b in b2cBills) {
      for (final item in b.items) {
        b2cByRate[item.taxRate] = (b2cByRate[item.taxRate] ?? 0) + item.subtotal;
        b2cCgstByRate[item.taxRate] = (b2cCgstByRate[item.taxRate] ?? 0) + item.cgst;
        b2cSgstByRate[item.taxRate] = (b2cSgstByRate[item.taxRate] ?? 0) + item.sgst;
        b2cTotalByRate[item.taxRate] = (b2cTotalByRate[item.taxRate] ?? 0) + item.total;
      }
      if (b.items.isNotEmpty) {
        final rate = b.items.first.taxRate;
        b2cCountByRate[rate] = (b2cCountByRate[rate] ?? 0) + 1;
      }
    }
    int b2cRow = 4;
    double b2cSumTaxable = 0, b2cSumCgst = 0, b2cSumSgst = 0, b2cSumTotal = 0;
    for (final rate in b2cByRate.keys.toList()..sort()) {
      final taxable = b2cByRate[rate]!;
      final cgst = b2cCgstByRate[rate] ?? 0;
      final sgst = b2cSgstByRate[rate] ?? 0;
      final total = b2cTotalByRate[rate] ?? 0;
      b2cSumTaxable += taxable;
      b2cSumCgst += cgst;
      b2cSumSgst += sgst;
      b2cSumTotal += total;
      b2cSheet.appendRow([
        TextCellValue('OE'), DoubleCellValue(rate),
        IntCellValue(b2cCountByRate[rate] ?? 0),
        DoubleCellValue(taxable), DoubleCellValue(cgst), DoubleCellValue(sgst),
        DoubleCellValue(cgst + sgst), DoubleCellValue(total),
      ]);
      _styleNumCols(b2cSheet, b2cRow, b2cNumCols);
      b2cRow++;
    }
    b2cSheet.appendRow([
      TextCellValue('TOTAL'), TextCellValue(''),
      IntCellValue(b2cBills.length),
      DoubleCellValue(b2cSumTaxable), DoubleCellValue(b2cSumCgst), DoubleCellValue(b2cSumSgst),
      DoubleCellValue(b2cSumCgst + b2cSumSgst), DoubleCellValue(b2cSumTotal),
    ]);
    _styleRow(b2cSheet, b2cRow, b2cHeaders.length, _totalStyle);

    // ══════════════════════════════
    //  SALES SUMMARY SHEET
    // ══════════════════════════════
    final summarySheet = excel['Sales Summary'];

    summarySheet.appendRow([TextCellValue('GSTR-1 Sales Summary — $businessName')]);
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = _titleStyle;
    summarySheet.appendRow([TextCellValue(businessAddress)]);
    summarySheet.appendRow([TextCellValue('Period: $period | Generated: ${_fd(DateTime.now())}')]);
    summarySheet.appendRow([]);
    _setColWidths(summarySheet, [18, 18, 14, 14, 14, 14]);

    final sortedBills = List<Bill>.from(bills)..sort((a, b) => a.billNumber.compareTo(b.billNumber));
    summarySheet.appendRow([
      TextCellValue('Start Voucher'), TextCellValue(sortedBills.isNotEmpty ? sortedBills.first.billNumber : '-'),
      TextCellValue('End Voucher'), TextCellValue(sortedBills.isNotEmpty ? sortedBills.last.billNumber : '-'),
      TextCellValue('Total Vouchers'), IntCellValue(bills.length),
    ]);
    summarySheet.appendRow([]);

    // B2B Rate Summary
    int sRow = 7;
    summarySheet.appendRow([TextCellValue('B2B Summary (Rate-wise)')]);
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sRow)).cellStyle = _subTitleStyle;
    sRow++;
    const sumHeaders = ['Rate %', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'CESS'];
    summarySheet.appendRow(sumHeaders.map((h) => TextCellValue(h)).toList());
    _styleRow(summarySheet, sRow, sumHeaders.length, _headerStyle);
    sRow++;

    final b2bRates = <double, List<double>>{};
    for (final b in b2bBills) {
      for (final item in b.items) {
        b2bRates.putIfAbsent(item.taxRate, () => [0, 0, 0]);
        b2bRates[item.taxRate]![0] += item.subtotal;
        b2bRates[item.taxRate]![1] += item.cgst;
        b2bRates[item.taxRate]![2] += item.sgst;
      }
    }
    double b2bSumTaxable = 0, b2bSumCgst = 0, b2bSumSgst = 0;
    for (final rate in b2bRates.keys.toList()..sort()) {
      final d = b2bRates[rate]!;
      b2bSumTaxable += d[0]; b2bSumCgst += d[1]; b2bSumSgst += d[2];
      summarySheet.appendRow([
        DoubleCellValue(rate), DoubleCellValue(d[0]),
        DoubleCellValue(0), DoubleCellValue(d[1]),
        DoubleCellValue(d[2]), DoubleCellValue(0),
      ]);
      _styleNumCols(summarySheet, sRow, [0,1,2,3,4,5]);
      sRow++;
    }
    summarySheet.appendRow([
      TextCellValue('Total'), DoubleCellValue(b2bSumTaxable),
      DoubleCellValue(0), DoubleCellValue(b2bSumCgst),
      DoubleCellValue(b2bSumSgst), DoubleCellValue(0),
    ]);
    _styleRow(summarySheet, sRow, sumHeaders.length, _totalStyle);
    sRow++;
    summarySheet.appendRow([]);
    sRow++;

    // B2C Rate Summary
    summarySheet.appendRow([TextCellValue('B2C Summary (Rate-wise)')]);
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sRow)).cellStyle = _subTitleStyle;
    sRow++;
    summarySheet.appendRow(sumHeaders.map((h) => TextCellValue(h)).toList());
    _styleRow(summarySheet, sRow, sumHeaders.length, _headerStyle);
    sRow++;

    double b2cSumTaxable2 = 0, b2cSumCgst2 = 0, b2cSumSgst2 = 0;
    for (final rate in b2cByRate.keys.toList()..sort()) {
      b2cSumTaxable2 += b2cByRate[rate]!;
      b2cSumCgst2 += b2cCgstByRate[rate] ?? 0;
      b2cSumSgst2 += b2cSgstByRate[rate] ?? 0;
      summarySheet.appendRow([
        DoubleCellValue(rate), DoubleCellValue(b2cByRate[rate]!),
        DoubleCellValue(0), DoubleCellValue(b2cCgstByRate[rate] ?? 0),
        DoubleCellValue(b2cSgstByRate[rate] ?? 0), DoubleCellValue(0),
      ]);
      _styleNumCols(summarySheet, sRow, [0,1,2,3,4,5]);
      sRow++;
    }
    summarySheet.appendRow([
      TextCellValue('Total'), DoubleCellValue(b2cSumTaxable2),
      DoubleCellValue(0), DoubleCellValue(b2cSumCgst2),
      DoubleCellValue(b2cSumSgst2), DoubleCellValue(0),
    ]);
    _styleRow(summarySheet, sRow, sumHeaders.length, _totalStyle);
    sRow++;
    summarySheet.appendRow([]);
    sRow++;
    summarySheet.appendRow([
      TextCellValue('B2B Vouchers'), IntCellValue(b2bBills.length),
      TextCellValue('B2C Vouchers'), IntCellValue(b2cBills.length),
      TextCellValue('Total'), IntCellValue(bills.length),
    ]);

    // Remove default Sheet1
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    return Uint8List.fromList(excel.encode()!);
  }

  // ═══════════════════════════════════════
  //  GSTR1 PDF EXPORT
  // ═══════════════════════════════════════
  static Future<Uint8List> generatePdf({
    required List<Bill> bills,
    required List<Customer> customers,
    required String businessName,
    required String businessAddress,
    required String period,
  }) async {
    final pdf = pw.Document();
    final gstinMap = <String, String>{};
    for (final c in customers) {
      if (c.gstin != null && c.gstin!.isNotEmpty) {
        gstinMap[c.id] = c.gstin!;
        gstinMap[c.name] = c.gstin!;
      }
    }

    final b2bBills = <Bill>[];
    final b2cBills = <Bill>[];
    for (final b in bills) {
      String? gstin;
      if (b.customerId != null) gstin = gstinMap[b.customerId!];
      gstin ??= gstinMap[b.customerName ?? ''];
      if (gstin != null && gstin.isNotEmpty) {
        b2bBills.add(b);
      } else {
        b2cBills.add(b);
      }
    }

    String getGstin(Bill b) {
      if (b.customerId != null && gstinMap.containsKey(b.customerId!)) return gstinMap[b.customerId!]!;
      return gstinMap[b.customerName ?? ''] ?? '';
    }

    const headerBg = PdfColor.fromInt(0xFF1a1a2e);
    const borderColor = PdfColor.fromInt(0xFFDEE2E6);

    pw.Widget header(String title) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(color: headerBg, borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
      child: pw.Column(children: [
        pw.Text(businessName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        pw.SizedBox(height: 2),
        pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
        pw.SizedBox(height: 4),
        pw.Text('GSTR-1 $title — $period', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.amber200)),
      ]),
    );

    pw.Widget tableRow(List<String> cells, {bool isHead = false, bool isTotal = false, List<double>? w}) {
      final bg = isHead ? const PdfColor.fromInt(0xFF16213e) : (isTotal ? const PdfColor.fromInt(0xFFE8F5E9) : null);
      final tc = isHead ? PdfColors.white : PdfColors.black;
      final fw = (isHead || isTotal) ? pw.FontWeight.bold : pw.FontWeight.normal;
      return pw.Container(
        decoration: pw.BoxDecoration(color: bg, border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 0.5))),
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: pw.Row(children: cells.asMap().entries.map((e) {
          final flex = w != null ? w[e.key] : (e.key == 0 ? 3.0 : 2.0);
          return pw.Expanded(flex: (flex * 10).toInt(),
            child: pw.Text(e.value, textAlign: e.key == 0 ? pw.TextAlign.left : pw.TextAlign.right,
              style: pw.TextStyle(fontSize: isHead ? 7 : 7.5, fontWeight: fw, color: tc)));
        }).toList()),
      );
    }

    // ── B2B PAGE ──
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (_) => pw.Column(children: [header('B2B Invoices'), pw.SizedBox(height: 8)]),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Generated by My Billu | ${_fd(DateTime.now())}', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
        pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
      ]),
      build: (_) => [
        tableRow(['GSTIN', 'Receiver', 'Inv No', 'Date', 'Value', 'Type', 'Rate', 'Taxable', 'CGST', 'SGST'],
          isHead: true, w: [2.5, 2.5, 1.5, 1.2, 1.2, 1.2, 0.8, 1.5, 1.2, 1.2]),
        ...b2bBills.map((b) => tableRow([
          getGstin(b), b.customerName ?? 'N/A', b.billNumber, _fd(b.createdAt),
          _fc(b.totalAmount), 'Regular B2B', '${b.items.first.taxRate}%',
          _fc(b.subtotal), _fc(b.totalCgst), _fc(b.totalSgst),
        ], w: [2.5, 2.5, 1.5, 1.2, 1.2, 1.2, 0.8, 1.5, 1.2, 1.2])),
        tableRow(['TOTAL', '', '${b2bBills.length} invoices', '', _fc(b2bBills.fold<double>(0, (s, b) => s + b.totalAmount)),
          '', '', _fc(b2bBills.fold<double>(0, (s, b) => s + b.subtotal)),
          _fc(b2bBills.fold<double>(0, (s, b) => s + b.totalCgst)),
          _fc(b2bBills.fold<double>(0, (s, b) => s + b.totalSgst)),
        ], isTotal: true, w: [2.5, 2.5, 1.5, 1.2, 1.2, 1.2, 0.8, 1.5, 1.2, 1.2]),
      ],
    ));

    // ── B2C PAGE ──
    final b2cRates = <double, List<double>>{};
    for (final b in b2cBills) {
      for (final item in b.items) {
        b2cRates.putIfAbsent(item.taxRate, () => [0, 0, 0]);
        b2cRates[item.taxRate]![0] += item.subtotal;
        b2cRates[item.taxRate]![1] += item.cgst;
        b2cRates[item.taxRate]![2] += item.sgst;
      }
    }
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        header('B2C Summary'),
        pw.SizedBox(height: 12),
        tableRow(['Rate', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'CESS'], isHead: true),
        ...b2cRates.entries.map((e) => tableRow([
          '${e.key}%', _fc(e.value[0]), '0.00', _fc(e.value[1]), _fc(e.value[2]), '0.00'])),
        tableRow(['Total',
          _fc(b2cRates.values.fold<double>(0, (s, v) => s + v[0])), '0.00',
          _fc(b2cRates.values.fold<double>(0, (s, v) => s + v[1])),
          _fc(b2cRates.values.fold<double>(0, (s, v) => s + v[2])), '0.00',
        ], isTotal: true),
        pw.SizedBox(height: 20),
        pw.Text('Total B2C Vouchers: ${b2cBills.length}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ]),
    ));

    // ── SALES SUMMARY PAGE ──
    final b2bSumRates = <double, List<double>>{};
    for (final b in b2bBills) {
      for (final item in b.items) {
        b2bSumRates.putIfAbsent(item.taxRate, () => [0, 0, 0]);
        b2bSumRates[item.taxRate]![0] += item.subtotal;
        b2bSumRates[item.taxRate]![1] += item.cgst;
        b2bSumRates[item.taxRate]![2] += item.sgst;
      }
    }
    final sortedBills = List<Bill>.from(bills)..sort((a, b) => a.billNumber.compareTo(b.billNumber));
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        header('Sales Summary'),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Start Voucher: ${sortedBills.isNotEmpty ? sortedBills.first.billNumber : "-"}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('End Voucher: ${sortedBills.isNotEmpty ? sortedBills.last.billNumber : "-"}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Total: ${bills.length}', style: const pw.TextStyle(fontSize: 9)),
        ]),
        pw.SizedBox(height: 16),
        pw.Text('B2B Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        tableRow(['Rate', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'CESS'], isHead: true),
        ...b2bSumRates.entries.map((e) => tableRow([
          '${e.key}%', _fc(e.value[0]), '0.00', _fc(e.value[1]), _fc(e.value[2]), '0.00'])),
        tableRow(['Total',
          _fc(b2bSumRates.values.fold<double>(0, (s, v) => s + v[0])), '0.00',
          _fc(b2bSumRates.values.fold<double>(0, (s, v) => s + v[1])),
          _fc(b2bSumRates.values.fold<double>(0, (s, v) => s + v[2])), '0.00',
        ], isTotal: true),
        pw.SizedBox(height: 16),
        pw.Text('B2C Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        tableRow(['Rate', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'CESS'], isHead: true),
        ...b2cRates.entries.map((e) => tableRow([
          '${e.key}%', _fc(e.value[0]), '0.00', _fc(e.value[1]), _fc(e.value[2]), '0.00'])),
        tableRow(['Total',
          _fc(b2cRates.values.fold<double>(0, (s, v) => s + v[0])), '0.00',
          _fc(b2cRates.values.fold<double>(0, (s, v) => s + v[1])),
          _fc(b2cRates.values.fold<double>(0, (s, v) => s + v[2])), '0.00',
        ], isTotal: true),
        pw.SizedBox(height: 20),
        pw.Row(children: [
          pw.Text('Total B2B Vouchers: ${b2bBills.length}   ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text('Total B2C Vouchers: ${b2cBills.length}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ]),
      ]),
    ));

    return pdf.save();
  }

  // ═══════════════════════════════════════
  //  SALES REGISTER EXCEL EXPORT
  // ═══════════════════════════════════════
  static Future<Uint8List> generateSalesExcel({
    required List<Bill> bills,
    required String businessName,
    required String period,
  }) async {
    final excel = Excel.createExcel();

    // ── Sales Register Sheet ──
    final sheet = excel['Sales Register'];
    excel.setDefaultSheet('Sales Register');

    // Title
    sheet.appendRow([TextCellValue(businessName)]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = _titleStyle;
    sheet.appendRow([TextCellValue('Sales Register — $period')]);
    sheet.appendRow([TextCellValue('Generated: ${_fd(DateTime.now())}')]);
    sheet.appendRow([]);

    // Headers (row 4)
    const headers = ['Date', 'Bill No', 'Customer', 'Phone', 'Items',
      'Taxable Value', 'GST', 'Discount', 'Total Amount', 'Paid',
      'Balance Due', 'Payment', 'Status'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    _styleRow(sheet, 4, headers.length, _headerStyle);
    _setColWidths(sheet, [14, 16, 22, 14, 8, 16, 14, 12, 16, 14, 14, 12, 10]);

    final numCols = [5, 6, 7, 8, 9, 10];
    double totalSub = 0, totalTax = 0, totalDisc = 0, totalAmt = 0, totalPaid = 0, totalDue = 0;
    int dRow = 5;
    for (final b in bills) {
      totalSub += b.subtotal;
      totalTax += b.totalTax;
      totalDisc += b.discount;
      totalAmt += b.totalAmount;
      totalPaid += b.paidAmount;
      totalDue += b.balanceDue;
      sheet.appendRow([
        TextCellValue(_fd(b.createdAt)),
        TextCellValue(b.billNumber),
        TextCellValue(b.customerName ?? 'Walk-in'),
        TextCellValue(b.customerPhone ?? ''),
        IntCellValue(b.items.length),
        DoubleCellValue(b.subtotal),
        DoubleCellValue(b.totalTax),
        DoubleCellValue(b.discount),
        DoubleCellValue(b.totalAmount),
        DoubleCellValue(b.paidAmount),
        DoubleCellValue(b.balanceDue),
        TextCellValue(b.paymentMethod.name.toUpperCase()),
        TextCellValue(b.status.name.toUpperCase()),
      ]);
      _styleNumCols(sheet, dRow, numCols);
      dRow++;
    }

    // Totals
    sheet.appendRow([
      TextCellValue('TOTAL'), TextCellValue(''),
      TextCellValue('${bills.length} Bills'), TextCellValue(''), TextCellValue(''),
      DoubleCellValue(totalSub), DoubleCellValue(totalTax),
      DoubleCellValue(totalDisc), DoubleCellValue(totalAmt),
      DoubleCellValue(totalPaid), DoubleCellValue(totalDue),
      TextCellValue(''), TextCellValue(''),
    ]);
    _styleRow(sheet, dRow, headers.length, _totalStyle);

    // ── Item Details Sheet ──
    final itemSheet = excel['Item Details'];
    const iHeaders = ['Bill No', 'Date', 'Customer', 'Item Name', 'Qty', 'Unit',
      'Unit Price', 'Subtotal', 'Tax Rate %', 'CGST', 'SGST', 'Total'];
    itemSheet.appendRow(iHeaders.map((h) => TextCellValue(h)).toList());
    _styleRow(itemSheet, 0, iHeaders.length, _headerStyle);
    _setColWidths(itemSheet, [16, 14, 22, 26, 8, 8, 14, 14, 10, 14, 14, 14]);

    int iRow = 1;
    for (final b in bills) {
      for (final item in b.items) {
        itemSheet.appendRow([
          TextCellValue(b.billNumber), TextCellValue(_fd(b.createdAt)),
          TextCellValue(b.customerName ?? 'Walk-in'),
          TextCellValue(item.itemName),
          IntCellValue(item.quantity), TextCellValue(item.unit),
          DoubleCellValue(item.unitPrice), DoubleCellValue(item.subtotal),
          DoubleCellValue(item.taxRate), DoubleCellValue(item.cgst),
          DoubleCellValue(item.sgst), DoubleCellValue(item.total),
        ]);
        _styleNumCols(itemSheet, iRow, [6,7,8,9,10,11]);
        iRow++;
      }
    }

    // ── Summary Sheet ──
    final sumSheet = excel['Summary'];
    sumSheet.appendRow([TextCellValue(businessName)]);
    sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = _titleStyle;
    sumSheet.appendRow([TextCellValue('Sales Summary — $period')]);
    sumSheet.appendRow([]);
    _setColWidths(sumSheet, [24, 18, 18]);

    sumSheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    _styleRow(sumSheet, 3, 2, _headerStyle);

    final metrics = [
      ['Total Bills', '${bills.length}'],
      ['Taxable Value', _fc(totalSub)],
      ['Total GST', _fc(totalTax)],
      ['Total Discount', _fc(totalDisc)],
      ['Total Sales', _fc(totalAmt)],
      ['Total Collected', _fc(totalPaid)],
      ['Total Outstanding', _fc(totalDue)],
      ['Average Bill', bills.isNotEmpty ? _fc(totalAmt / bills.length) : '0.00'],
    ];
    for (final m in metrics) {
      sumSheet.appendRow([TextCellValue(m[0]), TextCellValue(m[1])]);
    }
    sumSheet.appendRow([]);

    final pmRow = 3 + 1 + metrics.length + 1;
    sumSheet.appendRow([TextCellValue('Payment Method'), TextCellValue('Count'), TextCellValue('Amount')]);
    _styleRow(sumSheet, pmRow, 3, _headerStyle);

    final methodMap = <String, List<double>>{};
    for (final b in bills) {
      final m = b.paymentMethod.name.toUpperCase();
      methodMap.putIfAbsent(m, () => [0, 0]);
      methodMap[m]![0] += 1;
      methodMap[m]![1] += b.totalAmount;
    }
    for (final e in methodMap.entries) {
      sumSheet.appendRow([TextCellValue(e.key), DoubleCellValue(e.value[0]), DoubleCellValue(e.value[1])]);
    }

    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    return Uint8List.fromList(excel.encode()!);
  }

  static Future<void> printPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareExcel(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      await _saveAndOpenWindows(bytes, filename);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')]);
    }
  }

  static Future<void> sharePdf(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      await _saveAndOpenWindows(bytes, filename);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')]);
    }
  }

  /// Save file to Documents/MyBillu and open with default Windows app
  static Future<void> _saveAndOpenWindows(Uint8List bytes, String filename) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${docsDir.path}/MyBillu/Exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File('${exportDir.path}/$filename');
    await file.writeAsBytes(bytes);
    // Open the file with default Windows application
    await Process.run('cmd', ['/c', 'start', '', file.path]);
  }
}
