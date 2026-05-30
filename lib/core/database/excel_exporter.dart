import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/item.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import '../utils/formatters.dart';

// Conditional import for saving files
import 'export_save_native.dart' if (dart.library.js_interop) 'export_save_web.dart'
    as saver;

class ExcelExporter {
  /// Export items list to Excel and trigger download
  static Future<void> exportItems(List<Item> items, {String fileName = 'items_export'}) async {
    final excel = Excel.createExcel();
    final sheet = excel['Items'];
    excel.delete('Sheet1');

    // Header row
    final headers = ['Name', 'Purchase Price (₹)', 'Sales Price (₹)', 'GST %', 'HSN Code', 'Unit', 'Stock Qty', 'Category'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i]);
    }

    // Data rows
    for (int r = 0; r < items.length; r++) {
      final item = items[r];
      final row = r + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(item.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(item.purchasePrice > 0 ? item.purchasePrice.toStringAsFixed(2) : '0.00');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(item.price.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(item.taxRate.toStringAsFixed(1));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(item.hsnCode ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue(item.unit);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(item.stockQuantity.toString());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue(item.category ?? '');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      await saver.saveFile(Uint8List.fromList(bytes), '$fileName.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    }
  }

  /// Export customers list to Excel and trigger download
  static Future<void> exportCustomers(List<Customer> customers, {String fileName = 'customers_export'}) async {
    final excel = Excel.createExcel();
    final sheet = excel['Customers'];
    excel.delete('Sheet1');

    final headers = ['Name', 'Phone', 'Email', 'Address', 'GSTIN', 'Total Purchases (₹)', 'Outstanding (₹)'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i]);
    }

    for (int r = 0; r < customers.length; r++) {
      final c = customers[r];
      final row = r + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(c.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(c.phone ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(c.email ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(c.address ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(c.gstin ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue(c.totalPurchases.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(c.outstandingBalance.toStringAsFixed(2));
    }

    final bytes = excel.encode();
    if (bytes != null) {
      await saver.saveFile(Uint8List.fromList(bytes), '$fileName.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    }
  }

  /// Export bills/invoices list to Excel
  static Future<void> exportBills(List<Bill> bills, {String fileName = 'bills_export'}) async {
    final excel = Excel.createExcel();
    final sheet = excel['Bills'];
    excel.delete('Sheet1');

    final headers = ['Bill #', 'Date', 'Customer', 'Subtotal (₹)', 'GST (₹)', 'Total (₹)', 'Paid (₹)', 'Balance (₹)', 'Payment Method', 'Status'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i]);
    }

    for (int r = 0; r < bills.length; r++) {
      final b = bills[r];
      final row = r + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(b.billNumber);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(AppFormatters.date(b.createdAt));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(b.customerName ?? 'Walk-in');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(b.subtotal.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(b.totalTax.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue(b.totalAmount.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(b.paidAmount.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue(b.balanceDue.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = TextCellValue(b.paymentMethod.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = TextCellValue(b.status.name.toUpperCase());
    }

    final bytes = excel.encode();
    if (bytes != null) {
      await saver.saveFile(Uint8List.fromList(bytes), '$fileName.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    }
  }
}


