import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/item.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _search = '';
  String _filter = 'all'; // all, low, out

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      var items = appState.items.toList();

      // Filter
      if (_filter == 'low') {
        items = items.where((i) => i.stockQuantity > 0 && i.stockQuantity <= 10).toList();
      } else if (_filter == 'out') {
        items = items.where((i) => i.stockQuantity <= 0).toList();
      }

      // Search
      if (_search.isNotEmpty) {
        items = items.where((i) =>
            i.name.toLowerCase().contains(_search.toLowerCase()) ||
            (i.category ?? '').toLowerCase().contains(_search.toLowerCase())).toList();
      }

      // Stats
      final totalItems = appState.items.length;
      final totalStock = appState.items.fold<int>(0, (sum, i) => sum + i.stockQuantity);
      final totalValue = appState.items.fold<double>(0, (sum, i) => sum + (i.price * i.stockQuantity));
      final lowStock = appState.items.where((i) => i.stockQuantity > 0 && i.stockQuantity <= 10).length;
      final outOfStock = appState.items.where((i) => i.stockQuantity <= 0).length;

      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return Column(children: [
          Padding(padding: EdgeInsets.all(isWide ? 24 : 16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Stock Details', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 16),

              // Summary Cards
              Wrap(spacing: 12, runSpacing: 12, children: [
                _statCard('Total Items', '$totalItems', Icons.inventory_2, AppColors.primary,
                  onTap: () => _showStockDetail(context, 'Total Items', appState.items.map((i) => '${i.name}: ${i.stockQuantity} ${i.unit}').toList())),
                _statCard('Total Stock', '$totalStock', Icons.stacked_bar_chart, AppColors.accent,
                  onTap: () => _showStockDetail(context, 'Total Stock', appState.items.map((i) => '${i.name}: ${i.stockQuantity} ${i.unit}').toList())),
                _statCard('Stock Value', AppFormatters.currency(totalValue), Icons.currency_rupee, AppColors.success,
                  onTap: () => _showStockDetail(context, 'Stock Value', appState.items.map((i) => '${i.name}: ${AppFormatters.currency(i.price * i.stockQuantity)}').toList())),
                _statCard('Low Stock', '$lowStock', Icons.warning_amber, AppColors.warning,
                  onTap: () => _showStockDetail(context, 'Low Stock Items', appState.items.where((i) => i.stockQuantity > 0 && i.stockQuantity <= 10).map((i) => '${i.name}: ${i.stockQuantity} ${i.unit}').toList())),
                _statCard('Out of Stock', '$outOfStock', Icons.error_outline, AppColors.error,
                  onTap: () => _showStockDetail(context, 'Out of Stock Items', appState.items.where((i) => i.stockQuantity <= 0).map((i) => i.name).toList())),
              ]),
              const SizedBox(height: 16),

              // Filters
              Row(children: [
                Expanded(child: TextField(onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(hintText: 'Search items...', prefixIcon: Icon(Icons.search, color: AppColors.primary)))),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'low', label: Text('Low')),
                    ButtonSegment(value: 'out', label: Text('Out')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (val) => setState(() => _filter = val.first),
                ),
              ]),
            ])),

          // Stock Table
          Expanded(child: items.isEmpty
            ? const EmptyState(icon: Icons.inventory_outlined, title: 'No items found', subtitle: 'Add items to track stock')
            : ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
                itemCount: items.length,
                itemBuilder: (ctx, i) => _stockTile(context, items[i], isWide),
              )),
        ]);
      });
    });
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 160, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }

  void _showStockDetail(BuildContext context, String title, List<String> items) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${items.length} items', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('No items found')
          else
            ...items.map<Widget>((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $item', style: const TextStyle(fontSize: 13)),
            )),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Widget _stockTile(BuildContext context, Item item, bool isWide) {
    final stockColor = item.stockQuantity <= 0
        ? AppColors.error
        : item.stockQuantity <= 10
            ? AppColors.warning
            : AppColors.success;

    final stockLabel = item.stockQuantity <= 0
        ? 'OUT OF STOCK'
        : item.stockQuantity <= 10
            ? 'LOW STOCK'
            : 'IN STOCK';

    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showItemDetail(context, item),
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(padding: const EdgeInsets.all(16), child: Row(children: [
        // Item icon
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary))),
        ),
        const SizedBox(width: 14),

        // Item details
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          if (item.category != null && item.category!.isNotEmpty)
            Text(item.category!, style: Theme.of(context).textTheme.bodySmall),
          Text('${item.unit} · ${AppFormatters.currency(item.price)}', 
            style: Theme.of(context).textTheme.bodySmall),
        ])),

        // Stock quantity
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${item.stockQuantity}', style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 22, color: stockColor)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: stockColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(stockLabel, style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: stockColor)),
          ),
        ]),

        if (isWide) ...[
          const SizedBox(width: 20),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(AppFormatters.currency(item.price * item.stockQuantity),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('Stock Value', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ],
      ]))));
  }

  void _showItemDetail(BuildContext context, Item item) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary))),
        const SizedBox(width: 10),
        Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoRow('Category', item.category ?? 'N/A'),
        _infoRow('Unit', item.unit),
        _infoRow('Sale Price', AppFormatters.currency(item.price)),
        _infoRow('Purchase Price', AppFormatters.currency(item.purchasePrice)),
        _infoRow('Tax Rate', '${item.taxRate}%'),
        const Divider(),
        _infoRow('Stock Qty', '${item.stockQuantity} ${item.unit}'),
        _infoRow('Stock Value', AppFormatters.currency(item.price * item.stockQuantity)),
        _infoRow('Purchase Value', AppFormatters.currency(item.purchasePrice * item.stockQuantity)),
        if (item.hsnCode != null && item.hsnCode!.isNotEmpty)
          _infoRow('HSN Code', item.hsnCode!),
        if (item.barcode != null && item.barcode!.isNotEmpty)
          _infoRow('Barcode', item.barcode!),
        if (item.description != null && item.description!.isNotEmpty) ...[
          const Divider(),
          const Text('Description:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(item.description!, style: const TextStyle(fontSize: 12)),
        ],
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]));
  }
}


