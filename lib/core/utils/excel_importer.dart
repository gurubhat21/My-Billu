import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/item.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/bill.dart';

class ExcelImporter {
  /// Import items from an Excel file.
  /// Expected columns: Name, Purchase Price, Sales Price, GST%, HSN Code, Unit, Stock Qty, Category
  /// First row is treated as header and skipped.
  static Future<List<Item>?> importItems() async {
    final bytes = await _pickExcelFile();
    if (bytes == null) return null;

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return null;

    final items = <Item>[];
    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty || row[0]?.value == null) continue;

      final name = _cellToString(row[0]);
      if (name.isEmpty) continue;

      items.add(Item(
        name: name,
        purchasePrice: row.length > 1 ? _cellToDouble(row[1]) : 0.0,
        price: row.length > 2 ? _cellToDouble(row[2]) : 0.0,
        taxRate: row.length > 3 ? _cellToDouble(row[3], fallback: 18.0) : 18.0,
        hsnCode: row.length > 4 ? _cellToString(row[4]) : '',
        unit: row.length > 5 ? _cellToString(row[5], fallback: 'pcs') : 'pcs',
        stockQuantity: row.length > 6 ? _cellToInt(row[6]) : 0,
        category: row.length > 7 ? _cellToString(row[7]) : '',
      ));
    }
    return items;
  }

  /// Import customers from an Excel file.
  /// Expected columns: Name, Phone, Email, Address, GSTIN
  static Future<List<Customer>?> importCustomers() async {
    final bytes = await _pickExcelFile();
    if (bytes == null) return null;

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return null;

    final customers = <Customer>[];
    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty || row[0]?.value == null) continue;

      final name = _cellToString(row[0]);
      if (name.isEmpty) continue;

      customers.add(Customer(
        name: name,
        phone: row.length > 1 ? _cellToString(row[1]) : '',
        email: row.length > 2 ? _cellToString(row[2]) : '',
        address: row.length > 3 ? _cellToString(row[3]) : '',
        gstin: row.length > 4 ? _cellToString(row[4]) : '',
      ));
    }
    return customers;
  }

  /// Import suppliers from an Excel file.
  /// Expected columns: Name, Phone, Email, Address, GSTIN
  static Future<List<Supplier>?> importSuppliers() async {
    final bytes = await _pickExcelFile();
    if (bytes == null) return null;

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return null;

    final suppliers = <Supplier>[];
    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty || row[0]?.value == null) continue;

      final name = _cellToString(row[0]);
      if (name.isEmpty) continue;

      suppliers.add(Supplier(
        name: name,
        phone: row.length > 1 ? _cellToString(row[1]) : null,
        email: row.length > 2 ? _cellToString(row[2]) : null,
        address: row.length > 3 ? _cellToString(row[3]) : null,
        gstin: row.length > 4 ? _cellToString(row[4]) : null,
      ));
    }
    return suppliers;
  }

  /// Import ledger/bills from an Excel file.
  /// Expected columns: BillNo, Date, CustomerName, Subtotal, Tax, Total, PaidAmount, Status, PaymentMethod
  static Future<List<Bill>?> importLedger() async {
    final bytes = await _pickExcelFile();
    if (bytes == null) return null;

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return null;

    final bills = <Bill>[];
    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty || row[0]?.value == null) continue;

      final billNo = _cellToString(row[0]);
      if (billNo.isEmpty) continue;

      final subtotal = row.length > 3 ? _cellToDouble(row[3]) : 0.0;
      final tax = row.length > 4 ? _cellToDouble(row[4]) : 0.0;
      final total = row.length > 5 ? _cellToDouble(row[5]) : subtotal + tax;
      final paid = row.length > 6 ? _cellToDouble(row[6]) : 0.0;
      final statusStr = row.length > 7 ? _cellToString(row[7]) : 'unpaid';
      final pmStr = row.length > 8 ? _cellToString(row[8]) : 'cash';

      DateTime? date;
      if (row.length > 1) {
        final ds = _cellToString(row[1]);
        date = DateTime.tryParse(ds);
      }

      bills.add(Bill(
        billNumber: billNo,
        customerName: row.length > 2 ? _cellToString(row[2]) : null,
        items: [],
        subtotal: subtotal,
        totalTax: tax,
        totalAmount: total,
        paidAmount: paid,
        paymentMethod: PaymentMethod.values.firstWhere((e) => e.name == pmStr, orElse: () => PaymentMethod.cash),
        status: BillStatus.values.firstWhere((e) => e.name == statusStr, orElse: () => BillStatus.unpaid),
        createdAt: date,
      ));
    }
    return bills;
  }

  static Future<Uint8List?> _pickExcelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first.bytes;
  }

  static String _cellToString(Data? cell, {String fallback = ''}) {
    if (cell == null || cell.value == null) return fallback;
    return cell.value.toString().trim();
  }

  static double _cellToDouble(Data? cell, {double fallback = 0.0}) {
    if (cell == null || cell.value == null) return fallback;
    final val = cell.value;
    if (val is DoubleCellValue) return val.value;
    if (val is IntCellValue) return val.value.toDouble();
    return double.tryParse(val.toString()) ?? fallback;
  }

  static int _cellToInt(Data? cell, {int fallback = 0}) {
    if (cell == null || cell.value == null) return fallback;
    final val = cell.value;
    if (val is IntCellValue) return val.value;
    if (val is DoubleCellValue) return val.value.toInt();
    return int.tryParse(val.toString()) ?? fallback;
  }
}


