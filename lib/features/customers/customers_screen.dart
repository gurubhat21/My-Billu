import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/customer.dart';
import '../../core/models/bill.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/excel_importer.dart';
import '../../core/database/excel_exporter.dart';
import '../../widgets/common_widgets.dart';
import '../../core/utils/validators.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final customers = _searchQuery.isEmpty
            ? appState.customers
            : appState.customers
                .where((c) =>
                    c.name
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ||
                    (c.phone ?? '')
                        .contains(_searchQuery))
                .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(isWide ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Customers',
                              style:
                                  Theme.of(context).textTheme.headlineLarge,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _importFromExcel(context),
                            icon: const Icon(Icons.upload_file, size: 20),
                            label: Text(isWide ? 'Import Excel' : 'Import'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _exportToExcel(context, appState.customers),
                            icon: const Icon(Icons.download, size: 20),
                            label: Text(isWide ? 'Export Excel' : 'Export'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showCustomerDialog(context),
                            icon: const Icon(Icons.person_add, size: 20),
                            label: Text(isWide ? 'Add Customer' : 'Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText: 'Search customers...',
                          prefixIcon:
                              Icon(Icons.search, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: customers.isEmpty
                      ? EmptyState(
                          icon: Icons.people_outline,
                          title: 'No customers yet',
                          subtitle: 'Add your first customer to get started',
                          actionLabel: 'Add Customer',
                          onAction: () => _showCustomerDialog(context),
                        )
                      : ListView.builder(
                          padding:
                              EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
                          itemCount: customers.length,
                          itemBuilder: (context, index) =>
                              _buildCustomerTile(context, customers[index]),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerTile(BuildContext context, Customer customer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () => _showCustomerDialog(context, customer: customer),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                customer.name.isNotEmpty
                    ? customer.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (customer.phone != null && customer.phone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        customer.phone!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long, size: 20, color: AppColors.accent),
              tooltip: 'View Ledger',
              onPressed: () => _showLedger(context, customer),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatters.currency(customer.totalPurchases),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                if (customer.outstandingBalance > 0)
                  Text(
                    'Due: ${AppFormatters.currency(customer.outstandingBalance)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDialog(BuildContext context, {Customer? customer}) {
    final isEditing = customer != null;
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final addressCtrl = TextEditingController(text: customer?.address ?? '');
    final gstinCtrl = TextEditingController(text: customer?.gstin ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Customer' : 'Add New Customer'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gstinCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN',
                    prefixIcon: Icon(Icons.badge_outlined),
                    hintText: 'e.g. 29ABCDE1234F1Z5',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('Delete Customer?'),
                    content: Text(
                        'Are you sure you want to delete "${customer.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error),
                        onPressed: () {
                          context.read<AppState>().deleteCustomer(customer.id);
                          Navigator.pop(ctx2);
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }
              // GSTIN validation
              final gstinError = Validators.validateGstin(gstinCtrl.text);
              if (gstinError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(gstinError), backgroundColor: AppColors.error));
                return;
              }
              // Duplicate detection (only when adding new)
              if (!isEditing) {
                final appState = context.read<AppState>();
                final existing = appState.customers
                    .map((c) => {'name': c.name, 'phone': c.phone ?? ''}).toList();
                final dupError = Validators.checkDuplicateCustomer(
                    nameCtrl.text, phoneCtrl.text, existing);
                if (dupError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Row(children: [
                      const Icon(Icons.warning_amber, color: Colors.white), const SizedBox(width: 8),
                      Expanded(child: Text(dupError)),
                    ]), backgroundColor: AppColors.warning));
                  return;
                }
              }
              final newCustomer = isEditing
                  ? customer.copyWith(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      gstin: gstinCtrl.text.trim().toUpperCase(),
                    )
                  : Customer(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      gstin: gstinCtrl.text.trim().toUpperCase(),
                    );

              final appState = context.read<AppState>();
              if (isEditing) {
                appState.updateCustomer(newCustomer);
              } else {
                appState.addCustomer(newCustomer);
              }
              Navigator.pop(ctx);
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromExcel(BuildContext context) async {
    try {
      final customers = await ExcelImporter.importCustomers();
      if (customers == null) return;
      if (customers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No customers found in the Excel file')),
          );
        }
        return;
      }

      final appState = context.read<AppState>();
      int count = 0;
      for (final customer in customers) {
        await appState.addCustomer(customer);
        count++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text('Successfully imported $count customers!'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel(BuildContext context, List<Customer> customers) async {
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers to export')),
      );
      return;
    }
    try {
      await ExcelExporter.exportCustomers(customers);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Customers exported successfully!'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showLedger(BuildContext context, Customer customer) {
    final appState = context.read<AppState>();
    final customerBills = appState.bills.where((b) => b.customerId == customer.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    double totalBilled = customerBills.fold(0, (s, b) => s + b.totalAmount);
    double totalPaid = customerBills.fold(0, (s, b) => s + b.paidAmount);
    double totalDue = totalBilled - totalPaid;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        CircleAvatar(radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(customer.name[0].toUpperCase(),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(customer.name, style: const TextStyle(fontSize: 16)),
          if (customer.phone != null)
            Text(customer.phone!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
        ])),
      ]),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Summary
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primary.withValues(alpha: 0.08), AppColors.primary.withValues(alpha: 0.02)]),
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: Column(children: [
                Text(AppFormatters.currency(totalBilled),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
                const Text('Total Billed', style: TextStyle(fontSize: 10)),
              ])),
              Expanded(child: Column(children: [
                Text(AppFormatters.currency(totalPaid),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.success)),
                const Text('Paid', style: TextStyle(fontSize: 10)),
              ])),
              Expanded(child: Column(children: [
                Text(AppFormatters.currency(totalDue),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
                    color: totalDue > 0 ? AppColors.error : AppColors.success)),
                const Text('Due', style: TextStyle(fontSize: 10)),
              ])),
            ])),
          const SizedBox(height: 16),
          Text('Transactions (${customerBills.length})',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          if (customerBills.isEmpty)
            const Padding(padding: EdgeInsets.all(20),
              child: Center(child: Text('No transactions', style: TextStyle(fontSize: 13))))
          else
            ...customerBills.map((bill) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
              child: Row(children: [
                Container(width: 4, height: 36,
                  decoration: BoxDecoration(
                    color: bill.status == BillStatus.paid ? AppColors.success : AppColors.error,
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${AppFormatters.date(bill.createdAt)} · ${bill.items.length} items',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(AppFormatters.currency(bill.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(bill.status == BillStatus.paid ? 'Paid' : 'Due: ${AppFormatters.currency(bill.balanceDue)}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: bill.status == BillStatus.paid ? AppColors.success : AppColors.error)),
                ]),
              ]))),
        ]))),
      actions: [
        ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ));
  }
}


