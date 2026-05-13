import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../models/item.dart';
import '../models/purchase.dart';
import '../models/expense.dart';
import '../models/supplier.dart';

class FullBackupExporter {
  static Future<Uint8List> exportAll({
    required List<Item> items,
    required List<Customer> customers,
    required List<Bill> bills,
    required List<Purchase> purchases,
    required List<Expense> expenses,
    required List<Supplier> suppliers,
  }) async {
    final excel = Excel.createExcel();

    // Items Sheet
    final itemSheet = excel['Items'];
    itemSheet.appendRow([TextCellValue('Name'), TextCellValue('Price'), TextCellValue('Tax %'), TextCellValue('Category'), TextCellValue('Unit'), TextCellValue('Stock'), TextCellValue('HSN')]);
    for (final i in items) {
      itemSheet.appendRow([TextCellValue(i.name), DoubleCellValue(i.price), DoubleCellValue(i.taxRate),
        TextCellValue(i.category ?? ''), TextCellValue(i.unit), IntCellValue(i.stockQuantity), TextCellValue(i.hsnCode ?? '')]);
    }

    // Customers Sheet
    final custSheet = excel['Customers'];
    custSheet.appendRow([TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Email'), TextCellValue('GSTIN'), TextCellValue('Total Purchases'), TextCellValue('Outstanding')]);
    for (final c in customers) {
      custSheet.appendRow([TextCellValue(c.name), TextCellValue(c.phone ?? ''), TextCellValue(c.email ?? ''),
        TextCellValue(c.gstin ?? ''), DoubleCellValue(c.totalPurchases), DoubleCellValue(c.outstandingBalance)]);
    }

    // Suppliers Sheet
    final suppSheet = excel['Suppliers'];
    suppSheet.appendRow([TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Email'), TextCellValue('GSTIN'), TextCellValue('Total Purchases'), TextCellValue('Outstanding')]);
    for (final s in suppliers) {
      suppSheet.appendRow([TextCellValue(s.name), TextCellValue(s.phone ?? ''), TextCellValue(s.email ?? ''),
        TextCellValue(s.gstin ?? ''), DoubleCellValue(s.totalPurchases), DoubleCellValue(s.outstandingBalance)]);
    }

    // Bills Sheet
    final billSheet = excel['Sales'];
    billSheet.appendRow([TextCellValue('Bill No'), TextCellValue('Date'), TextCellValue('Customer'), TextCellValue('Subtotal'),
      TextCellValue('Tax'), TextCellValue('Total'), TextCellValue('Paid'), TextCellValue('Status'), TextCellValue('Payment')]);
    for (final b in bills) {
      billSheet.appendRow([TextCellValue(b.billNumber), TextCellValue(b.createdAt.toIso8601String().substring(0, 10)),
        TextCellValue(b.customerName ?? 'Walk-in'), DoubleCellValue(b.subtotal), DoubleCellValue(b.totalTax),
        DoubleCellValue(b.totalAmount), DoubleCellValue(b.paidAmount), TextCellValue(b.status.name), TextCellValue(b.paymentMethod.name)]);
    }

    // Purchases Sheet
    final purchSheet = excel['Purchases'];
    purchSheet.appendRow([TextCellValue('Purchase No'), TextCellValue('Date'), TextCellValue('Supplier'), TextCellValue('Subtotal'),
      TextCellValue('Tax'), TextCellValue('Total'), TextCellValue('Status')]);
    for (final p in purchases) {
      purchSheet.appendRow([TextCellValue(p.purchaseNumber), TextCellValue(p.createdAt.toIso8601String().substring(0, 10)),
        TextCellValue(p.supplierName), DoubleCellValue(p.subtotal), DoubleCellValue(p.totalTax),
        DoubleCellValue(p.totalAmount), TextCellValue(p.status.name)]);
    }

    // Expenses Sheet
    final expSheet = excel['Expenses'];
    expSheet.appendRow([TextCellValue('Date'), TextCellValue('Category'), TextCellValue('Title'), TextCellValue('Amount'), TextCellValue('Notes')]);
    for (final e in expenses) {
      expSheet.appendRow([TextCellValue(e.date.toIso8601String().substring(0, 10)),
        TextCellValue(e.category.label), TextCellValue(e.title), DoubleCellValue(e.amount), TextCellValue(e.notes ?? '')]);
    }

    // Remove default sheet
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    return Uint8List.fromList(excel.encode()!);
  }
}


