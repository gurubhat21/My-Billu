import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/audit_entry.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'package:intl/intl.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});
  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  String _filterEntity = 'all';
  String _filterAction = 'all';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      var entries = List<AuditEntry>.from(appState.auditLog);

      // Filters
      if (_filterEntity != 'all') {
        entries = entries.where((e) => e.entity.name == _filterEntity).toList();
      }
      if (_filterAction != 'all') {
        entries = entries.where((e) => e.action.name == _filterAction).toList();
      }
      if (_search.isNotEmpty) {
        entries = entries.where((e) =>
            e.entityName.toLowerCase().contains(_search.toLowerCase()) ||
            (e.details ?? '').toLowerCase().contains(_search.toLowerCase())).toList();
      }

      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Column(children: [
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.spaceBetween, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.history, color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Text('Audit Trail', style: Theme.of(context).textTheme.headlineLarge),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${entries.length} entries', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
              const SizedBox(width: 12),
              if (appState.auditLog.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _confirmClear(context, appState),
                  icon: const Icon(Icons.delete_sweep, size: 16),
                  label: const Text('Clear Log'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error)),
                ),
            ]),
          ]),
          const SizedBox(height: 14),

          // Filters row
          Wrap(spacing: 10, runSpacing: 8, children: [
            SizedBox(width: 200, child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
            _filterChip('All', 'all', _filterEntity, (v) => setState(() => _filterEntity = v)),
            _filterChip('Items', 'item', _filterEntity, (v) => setState(() => _filterEntity = v)),
            _filterChip('Customers', 'customer', _filterEntity, (v) => setState(() => _filterEntity = v)),
            _filterChip('Bills', 'bill', _filterEntity, (v) => setState(() => _filterEntity = v)),
            _filterChip('Purchases', 'purchase', _filterEntity, (v) => setState(() => _filterEntity = v)),
            _filterChip('Expenses', 'expense', _filterEntity, (v) => setState(() => _filterEntity = v)),
            const SizedBox(width: 10),
            _actionChip('All', 'all', _filterAction, (v) => setState(() => _filterAction = v)),
            _actionChip('Created', 'created', _filterAction, (v) => setState(() => _filterAction = v)),
            _actionChip('Updated', 'updated', _filterAction, (v) => setState(() => _filterAction = v)),
            _actionChip('Deleted', 'deleted', _filterAction, (v) => setState(() => _filterAction = v)),
          ]),
        ])),
        const SizedBox(height: 14),

        // Log entries
        Expanded(child: entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_toggle_off, size: 64, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 12),
              Text('No audit entries', style: TextStyle(color: Colors.white.withValues(alpha: 0.3)))]))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: entries.length,
              itemBuilder: (ctx, i) => _buildEntry(context, entries[i]))),
      ]);
    });
  }

  Widget _filterChip(String label, String value, String current, Function(String) onSelect) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6))),
      selected: selected,
      onSelected: (_) => onSelect(value),
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _actionChip(String label, String value, String current, Function(String) onSelect) {
    final selected = current == value;
    Color chipColor;
    switch (value) {
      case 'created': chipColor = AppColors.success; break;
      case 'updated': chipColor = AppColors.warning; break;
      case 'deleted': chipColor = AppColors.error; break;
      default: chipColor = AppColors.accent;
    }
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6))),
      selected: selected,
      onSelected: (_) => onSelect(value),
      selectedColor: chipColor,
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEntry(BuildContext context, AuditEntry entry) {
    IconData icon;
    Color color;
    switch (entry.action) {
      case AuditAction.created: icon = Icons.add_circle; color = AppColors.success; break;
      case AuditAction.updated: icon = Icons.edit; color = AppColors.warning; break;
      case AuditAction.deleted: icon = Icons.delete; color = AppColors.error; break;
    }

    IconData entityIcon;
    switch (entry.entity) {
      case AuditEntity.item: entityIcon = Icons.inventory_2; break;
      case AuditEntity.customer: entityIcon = Icons.people; break;
      case AuditEntity.supplier: entityIcon = Icons.local_shipping; break;
      case AuditEntity.bill: entityIcon = Icons.receipt_long; break;
      case AuditEntity.purchase: entityIcon = Icons.shopping_bag; break;
      case AuditEntity.expense: entityIcon = Icons.money_off; break;
      case AuditEntity.quotation: entityIcon = Icons.description; break;
      case AuditEntity.creditNote: entityIcon = Icons.assignment_return; break;
      case AuditEntity.purchaseReturn: entityIcon = Icons.keyboard_return; break;
      case AuditEntity.recurringBill: entityIcon = Icons.repeat; break;
      case AuditEntity.setting: entityIcon = Icons.settings; break;
    }

    final timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(entry.timestamp);

    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(padding: const EdgeInsets.all(14), child: Row(children: [
        // Action indicator
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),

        // Entity icon
        Icon(entityIcon, size: 16, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(width: 8),

        // Content
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(style: const TextStyle(fontSize: 13, fontFamily: 'Inter'), children: [
            TextSpan(text: entry.actionLabel, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            const TextSpan(text: ' '),
            TextSpan(text: entry.entityLabel, style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            const TextSpan(text: ': '),
            TextSpan(text: entry.entityName, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          ])),
          if (entry.details != null) ...[
            const SizedBox(height: 2),
            Text(entry.details!, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
          ],
        ])),

        // Timestamp
        Text(timeStr, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
      ])));
  }

  void _confirmClear(BuildContext context, AppState appState) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Clear Audit Log?'),
      content: const Text('This will permanently delete all audit trail entries.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () { appState.clearAuditLog(); Navigator.pop(ctx); },
          child: const Text('Clear All')),
      ],
    ));
  }
}


