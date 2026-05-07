import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/supplier.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});
  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _search.isEmpty ? appState.suppliers
        : appState.suppliers.where((s) => s.name.toLowerCase().contains(_search.toLowerCase()) ||
            (s.phone ?? '').contains(_search)).toList();

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Row(children: [
        Text('Suppliers', style: Theme.of(context).textTheme.headlineLarge),
        const Spacer(),
        SizedBox(width: 220, child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(hintText: 'Search...', prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          onPressed: () => _showDialog(context, appState),
          icon: const Icon(Icons.add, size: 18), label: const Text('Add Supplier')),
      ])),
      const SizedBox(height: 16),
      Expanded(child: filtered.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text('No suppliers yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.3)))]))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final s = filtered[i];
              return Padding(padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(padding: const EdgeInsets.all(16), child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.local_shipping, color: Colors.white, size: 22)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (s.phone != null) Text(s.phone!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                    if (s.gstin != null) Text('GSTIN: ${s.gstin}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(AppFormatters.currency(s.totalPurchases), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Purchases', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.4))),
                  ]),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showDialog(context, appState, supplier: s)),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                    onPressed: () async {
                      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                        title: const Text('Delete Supplier?'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
                      if (ok == true) await appState.deleteSupplier(s.id);
                    }),
                ])));
            })),
    ]);
  }

  void _showDialog(BuildContext context, AppState appState, {Supplier? supplier}) {
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final emailCtrl = TextEditingController(text: supplier?.email ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final gstinCtrl = TextEditingController(text: supplier?.gstin ?? '');

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(supplier == null ? 'Add Supplier' : 'Edit Supplier'),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.trim().isEmpty) return;
          if (supplier == null) {
            await appState.addSupplier(Supplier(name: nameCtrl.text.trim(),
              phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
              email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
              address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
              gstin: gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim()));
          } else {
            supplier.name = nameCtrl.text.trim();
            supplier.phone = phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim();
            supplier.email = emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim();
            supplier.address = addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim();
            supplier.gstin = gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim();
            await appState.updateSupplier(supplier);
          }
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: Text(supplier == null ? 'Add' : 'Save')),
      ],
    ));
  }
}
