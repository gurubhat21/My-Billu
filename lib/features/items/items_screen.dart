import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/item.dart';
import '../../core/models/purchase.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/excel_importer.dart';
import '../../core/database/excel_exporter.dart';
import '../../widgets/common_widgets.dart';
import '../../core/utils/validators.dart';

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
                          OutlinedButton.icon(
                            onPressed: () => _importFromExcel(context),
                            icon: const Icon(Icons.upload_file, size: 20),
                            label: Text(isWide ? 'Import Excel' : 'Import'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _exportToExcel(context, appState.items),
                            icon: const Icon(Icons.download, size: 20),
                            label: Text(isWide ? 'Export Excel' : 'Export'),
                          ),
                          const SizedBox(width: 8),
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
    final purchasePriceCtrl =
        TextEditingController(text: item != null && item.purchasePrice > 0 ? item.purchasePrice.toStringAsFixed(2) : '');
    final taxCtrl =
        TextEditingController(text: item?.taxRate.toStringAsFixed(1) ?? '18.0');
    final stockCtrl =
        TextEditingController(text: item?.stockQuantity.toString() ?? '0');
    final hsnCtrl = TextEditingController(text: item?.hsnCode ?? '');
    final categoryCtrl = TextEditingController(text: item?.category ?? '');
    String unit = item?.unit ?? 'pcs';

    // Margin controllers
    final marginCtrl = TextEditingController();
    bool marginIsPercent = true; // true = %, false = ₹
    bool _isUpdating = false; // prevent circular updates

    // Initialize margin from stored margin % or calculate from prices
    if (item != null && item.marginPercent > 0) {
      marginCtrl.text = item.marginPercent.toStringAsFixed(1);
    } else if (item != null && item.purchasePrice > 0 && item.price > 0) {
      final marginAmt = item.price - item.purchasePrice;
      if (marginAmt > 0) {
        final marginPct = (marginAmt / item.purchasePrice) * 100;
        marginCtrl.text = marginPct.toStringAsFixed(1);
      }
    }

    void recalcFromMargin(StateSetter setDialogState) {
      if (_isUpdating) return;
      _isUpdating = true;
      final pp = double.tryParse(purchasePriceCtrl.text) ?? 0;
      final marginVal = double.tryParse(marginCtrl.text) ?? 0;
      if (pp > 0 && marginVal > 0) {
        double sellingPrice;
        if (marginIsPercent) {
          sellingPrice = pp + (pp * marginVal / 100);
        } else {
          sellingPrice = pp + marginVal;
        }
        priceCtrl.text = sellingPrice.toStringAsFixed(2);
      }
      setDialogState(() {});
      _isUpdating = false;
    }

    void recalcFromSellingPrice(StateSetter setDialogState) {
      if (_isUpdating) return;
      _isUpdating = true;
      final pp = double.tryParse(purchasePriceCtrl.text) ?? 0;
      final sp = double.tryParse(priceCtrl.text) ?? 0;
      if (pp > 0 && sp > pp) {
        final marginAmt = sp - pp;
        if (marginIsPercent) {
          marginCtrl.text = ((marginAmt / pp) * 100).toStringAsFixed(1);
        } else {
          marginCtrl.text = marginAmt.toStringAsFixed(2);
        }
      } else if (pp > 0 && sp <= pp) {
        marginCtrl.text = '0';
      }
      setDialogState(() {});
      _isUpdating = false;
    }

    void recalcFromPurchasePrice(StateSetter setDialogState) {
      if (_isUpdating) return;
      final marginVal = double.tryParse(marginCtrl.text) ?? 0;
      if (marginVal > 0) {
        recalcFromMargin(setDialogState);
      } else {
        recalcFromSellingPrice(setDialogState);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Calculate live margin display
          final pp = double.tryParse(purchasePriceCtrl.text) ?? 0;
          final sp = double.tryParse(priceCtrl.text) ?? 0;
          final marginAmt = sp > pp && pp > 0 ? sp - pp : 0.0;
          final marginPct = pp > 0 && marginAmt > 0 ? (marginAmt / pp) * 100 : 0.0;

          return AlertDialog(
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
                            controller: purchasePriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Purchase Price (₹)',
                              prefixIcon: Icon(Icons.shopping_cart_outlined),
                              hintText: 'Cost price',
                            ),
                            onChanged: (_) => recalcFromPurchasePrice(setDialogState),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sales Price (₹) *',
                              prefixIcon: Icon(Icons.currency_rupee),
                              hintText: 'Selling price',
                            ),
                            onChanged: (_) => recalcFromSellingPrice(setDialogState),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Margin row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.trending_up, size: 16, color: AppColors.success),
                              const SizedBox(width: 6),
                              const Text('Margin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              const Spacer(),
                              // Toggle button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        if (!marginIsPercent) {
                                          // Convert amount to percent
                                          final ppVal = double.tryParse(purchasePriceCtrl.text) ?? 0;
                                          final amtVal = double.tryParse(marginCtrl.text) ?? 0;
                                          marginIsPercent = true;
                                          if (ppVal > 0 && amtVal > 0) {
                                            marginCtrl.text = ((amtVal / ppVal) * 100).toStringAsFixed(1);
                                          }
                                          setDialogState(() {});
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: marginIsPercent ? AppColors.success.withValues(alpha: 0.2) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('%', style: TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 14,
                                          color: marginIsPercent ? AppColors.success : Colors.white54)),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        if (marginIsPercent) {
                                          // Convert percent to amount
                                          final ppVal = double.tryParse(purchasePriceCtrl.text) ?? 0;
                                          final pctVal = double.tryParse(marginCtrl.text) ?? 0;
                                          marginIsPercent = false;
                                          if (ppVal > 0 && pctVal > 0) {
                                            marginCtrl.text = (ppVal * pctVal / 100).toStringAsFixed(2);
                                          }
                                          setDialogState(() {});
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: !marginIsPercent ? AppColors.success.withValues(alpha: 0.2) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('₹', style: TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 14,
                                          color: !marginIsPercent ? AppColors.success : Colors.white54)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: marginCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: marginIsPercent ? 'Margin %' : 'Margin ₹',
                              prefixIcon: Icon(marginIsPercent ? Icons.percent : Icons.currency_rupee, size: 18),
                              hintText: marginIsPercent ? 'e.g. 20' : 'e.g. 100',
                              isDense: true,
                            ),
                            onChanged: (_) => recalcFromMargin(setDialogState),
                          ),
                          if (pp > 0 && sp > pp) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: AppColors.success),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Margin: ${marginPct.toStringAsFixed(1)}% = ${AppFormatters.currency(marginAmt)}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
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
                        const SizedBox(width: 12),
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
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
              if (isEditing) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showItemPurchaseHistory(context, item);
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Purchase History'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context, item);
                  },
                  child: const Text('Delete',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
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
                  // Duplicate detection (only when adding new)
                  if (!isEditing) {
                    final appState = context.read<AppState>();
                    final existingNames = appState.items.map((i) => i.name).toList();
                    final dupError = Validators.checkDuplicateItem(nameCtrl.text, existingNames);
                    if (dupError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Row(children: [
                          const Icon(Icons.warning_amber, color: Colors.white), const SizedBox(width: 8),
                          Expanded(child: Text(dupError)),
                        ]), backgroundColor: AppColors.warning));
                      return;
                    }
                  }
                  // Calculate margin % to store
                  final ppSave = double.tryParse(purchasePriceCtrl.text) ?? 0;
                  final spSave = double.tryParse(priceCtrl.text) ?? 0;
                  double savedMarginPct = 0;
                  if (ppSave > 0 && spSave > ppSave) {
                    savedMarginPct = ((spSave - ppSave) / ppSave) * 100;
                  }
                  final newItem = isEditing
                      ? item.copyWith(
                          name: nameCtrl.text.trim(),
                          price: spSave,
                          purchasePrice: ppSave,
                          marginPercent: savedMarginPct,
                          taxRate: double.tryParse(taxCtrl.text) ?? 18.0,
                          stockQuantity: int.tryParse(stockCtrl.text) ?? 0,
                          hsnCode: hsnCtrl.text.trim(),
                          category: categoryCtrl.text.trim(),
                          unit: unit,
                        )
                      : Item(
                          name: nameCtrl.text.trim(),
                          price: spSave,
                          purchasePrice: ppSave,
                          marginPercent: savedMarginPct,
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
          );
        },
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

  void _showItemPurchaseHistory(BuildContext context, Item item) {
    final appState = context.read<AppState>();
    final List<_ItemPurchaseRecord> records = [];
    for (final purchase in appState.purchases) {
      for (final pi in purchase.items) {
        if (pi.itemId == item.id) {
          records.add(_ItemPurchaseRecord(
            date: purchase.createdAt, supplier: purchase.supplierName,
            purchaseNumber: purchase.purchaseNumber, unitCost: pi.unitCost,
            quantity: pi.quantity, total: pi.total,
          ));
        }
      }
    }
    double? lowestPrice, highestPrice;
    int totalQty = 0; double totalSpent = 0;
    for (final r in records) {
      if (lowestPrice == null || r.unitCost < lowestPrice) lowestPrice = r.unitCost;
      if (highestPrice == null || r.unitCost > highestPrice) highestPrice = r.unitCost;
      totalQty += r.quantity;
      totalSpent += r.total;
    }

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.history, color: AppColors.primary, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, style: const TextStyle(fontSize: 16)),
          Text('Purchase History', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w400)),
        ])),
      ]),
      content: SizedBox(width: 520, child: records.isEmpty
        ? const Padding(padding: EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_outlined, size: 48, color: AppColors.accent),
              SizedBox(height: 12),
              Text('No purchase records', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('This item has not been purchased yet', style: TextStyle(fontSize: 12)),
            ]))
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Summary
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
              child: Row(children: [
                _phStatChip('Purchases', '${records.length}', Icons.shopping_cart, AppColors.primary),
                _phStatChip('Total Qty', '$totalQty', Icons.inventory, AppColors.accent),
                _phStatChip('Spent', AppFormatters.currency(totalSpent), Icons.currency_rupee, AppColors.success),
              ])),
            const SizedBox(height: 12),
            // Price range
            if (lowestPrice != null && highestPrice != null)
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  _phPriceTag('Lowest', AppFormatters.currency(lowestPrice), AppColors.success),
                  Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                  _phPriceTag('Highest', AppFormatters.currency(highestPrice), AppColors.error),
                  Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                  _phPriceTag('Sell Price', AppFormatters.currency(item.price), AppColors.primary),
                ])),
            const SizedBox(height: 16),
            // Records
            ...records.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final prevCost = i + 1 < records.length ? records[i + 1].unitCost : null;
              final diff = prevCost != null ? r.unitCost - prevCost : null;
              return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.purchaseNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('${AppFormatters.date(r.date)} · ${r.supplier}',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(AppFormatters.currency(r.unitCost),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
                      Text('× ${r.quantity}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                    ]),
                  ]),
                  if (diff != null && diff != 0)
                    Padding(padding: const EdgeInsets.only(top: 6),
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (diff > 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(diff > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 12,
                            color: diff > 0 ? AppColors.error : AppColors.success),
                          const SizedBox(width: 4),
                          Text('${diff > 0 ? '+' : ''}${AppFormatters.currency(diff)} (${(diff / prevCost! * 100).toStringAsFixed(1)}%) from previous',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: diff > 0 ? AppColors.error : AppColors.success)),
                        ]))),
                ]));
            }),
          ]))),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Widget _phStatChip(String label, String value, IconData icon, Color color) {
    return Expanded(child: Column(children: [
      Icon(icon, size: 16, color: color), const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
    ]));
  }

  Widget _phPriceTag(String label, String value, Color color) {
    return Expanded(child: Column(children: [
      Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
    ]));
  }

  Future<void> _importFromExcel(BuildContext context) async {
    try {
      final items = await ExcelImporter.importItems();
      if (items == null) return; // User cancelled
      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No items found in the Excel file')),
          );
        }
        return;
      }

      final appState = context.read<AppState>();
      int count = 0;
      for (final item in items) {
        await appState.addItem(item);
        count++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text('Successfully imported $count items!'),
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

  Future<void> _exportToExcel(BuildContext context, List<Item> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to export')),
      );
      return;
    }
    try {
      await ExcelExporter.exportItems(items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Items exported successfully!'),
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
}

class _ItemPurchaseRecord {
  final DateTime date;
  final String supplier;
  final String purchaseNumber;
  final double unitCost;
  final int quantity;
  final double total;

  _ItemPurchaseRecord({
    required this.date, required this.supplier, required this.purchaseNumber,
    required this.unitCost, required this.quantity, required this.total,
  });
}


