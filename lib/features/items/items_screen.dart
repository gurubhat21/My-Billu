import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/item.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final items = _searchQuery.isEmpty
            ? appState.items
            : appState.items
                .where((i) =>
                    i.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (i.category ?? '')
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(isWide ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Item Catalog',
                              style:
                                  Theme.of(context).textTheme.headlineLarge,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showItemDialog(context),
                            icon: const Icon(Icons.add, size: 20),
                            label: Text(isWide ? 'Add Item' : 'Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search Bar
                      TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText: 'Search items...',
                          prefixIcon:
                              Icon(Icons.search, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),

                // Items List
                Expanded(
                  child: items.isEmpty
                      ? EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No items yet',
                          subtitle:
                              'Add your products and services to start billing',
                          actionLabel: 'Add First Item',
                          onAction: () => _showItemDialog(context),
                        )
                      : isWide
                          ? _buildGridView(context, items)
                          : _buildListView(context, items),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context, List<Item> items) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        childAspectRatio: 1.4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItemCard(context, items[index]),
    );
  }

  Widget _buildListView(BuildContext context, List<Item> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _buildItemTile(context, items[index]),
    );
  }

  Widget _buildItemCard(BuildContext context, Item item) {
    return GlassCard(
      onTap: () => _showItemDialog(context, item: item),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2,
                    size: 20, color: AppColors.primary),
              ),
              const Spacer(),
              _stockBadge(item.stockQuantity),
            ],
          ),
          const Spacer(),
          Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                AppFormatters.currency(item.price),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                ' / ${item.unit}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                'GST ${item.taxRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, Item item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () => _showItemDialog(context, item: item),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.category ?? "General"} · GST ${item.taxRate.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatters.currency(item.price),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                _stockBadge(item.stockQuantity),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockBadge(int qty) {
    final color =
        qty > 10 ? AppColors.success : (qty > 0 ? AppColors.warning : AppColors.error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        qty > 0 ? 'Stock: $qty' : 'Out of Stock',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showItemDialog(BuildContext context, {Item? item}) {
    final isEditing = item != null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final priceCtrl =
        TextEditingController(text: item?.price.toStringAsFixed(2) ?? '');
    final taxCtrl =
        TextEditingController(text: item?.taxRate.toStringAsFixed(1) ?? '18.0');
    final stockCtrl =
        TextEditingController(text: item?.stockQuantity.toString() ?? '0');
    final hsnCtrl = TextEditingController(text: item?.hsnCode ?? '');
    final categoryCtrl = TextEditingController(text: item?.category ?? '');
    String unit = item?.unit ?? 'pcs';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Item' : 'Add New Item'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: taxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'GST %',
                          prefixIcon: Icon(Icons.percent),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock Qty',
                          prefixIcon: Icon(Icons.inventory),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatefulBuilder(
                        builder: (context, setDropState) {
                          return DropdownButtonFormField<String>(
                            initialValue: unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              prefixIcon: Icon(Icons.straighten),
                            ),
                            items: ['pcs', 'kg', 'ltr', 'mtr', 'box', 'set']
                                .map((u) => DropdownMenuItem(
                                    value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) {
                              setDropState(() => unit = v!);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hsnCtrl,
                  decoration: const InputDecoration(
                    labelText: 'HSN Code',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
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
                _confirmDelete(context, item);
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
              if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and price are required')),
                );
                return;
              }
              final newItem = isEditing
                  ? item.copyWith(
                      name: nameCtrl.text.trim(),
                      price: double.tryParse(priceCtrl.text) ?? 0,
                      taxRate: double.tryParse(taxCtrl.text) ?? 18.0,
                      stockQuantity: int.tryParse(stockCtrl.text) ?? 0,
                      hsnCode: hsnCtrl.text.trim(),
                      category: categoryCtrl.text.trim(),
                      unit: unit,
                    )
                  : Item(
                      name: nameCtrl.text.trim(),
                      price: double.tryParse(priceCtrl.text) ?? 0,
                      taxRate: double.tryParse(taxCtrl.text) ?? 18.0,
                      stockQuantity: int.tryParse(stockCtrl.text) ?? 0,
                      hsnCode: hsnCtrl.text.trim(),
                      category: categoryCtrl.text.trim(),
                      unit: unit,
                    );

              final appState = context.read<AppState>();
              if (isEditing) {
                appState.updateItem(newItem);
              } else {
                appState.addItem(newItem);
              }
              Navigator.pop(ctx);
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              context.read<AppState>().deleteItem(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
