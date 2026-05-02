import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/item.dart';
import '../models/customer.dart';

class ExcelImporter {
  /// Import items from an Excel file.
  /// Expected columns: Name, Price, TaxRate(%), HSN Code, Unit, Stock, Category
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
        price: _cellToDouble(row.length > 1 ? row[1] : null),
        taxRate: row.length > 2 ? _cellToDouble(row[2], fallback: 18.0) : 18.0,
        hsnCode: row.length > 3 ? _cellToString(row[3]) : '',
        unit: row.length > 4 ? _cellToString(row[4], fallback: 'pcs') : 'pcs',
        stockQuantity: row.length > 5 ? _cellToInt(row[5]) : 0,
        category: row.length > 6 ? _cellToString(row[6]) : '',
      ));
    }
    return items;
  }

  /// Import customers from an Excel file.
  /// Expected columns: Name, Phone, Email, Address, GSTIN
  /// First row is treated as header and skipped.
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
