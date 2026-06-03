import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/subscription_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _subService = SubscriptionService();
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _loading = true);
    _clients = await _subService.getAllSubscriptions();
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredClients {
    var list = _clients;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) =>
        (c['email'] ?? '').toString().toLowerCase().contains(q) ||
        (c['displayName'] ?? '').toString().toLowerCase().contains(q) ||
        (c['deviceName'] ?? '').toString().toLowerCase().contains(q)
      ).toList();
    }
    if (_filterStatus != 'all') {
      list = list.where((c) => c['subscriptionStatus'] == _filterStatus).toList();
    }
    return list;
  }

  // Stats
  int get _totalClients => _clients.length;
  int get _activeClients => _clients.where((c) => c['subscriptionStatus'] == 'active').length;
  int get _trialClients => _clients.where((c) => c['subscriptionStatus'] == 'trial').length;
  int get _expiredClients => _clients.where((c) => c['subscriptionStatus'] == 'expired').length;
  int get _revokedClients => _clients.where((c) => c['subscriptionStatus'] == 'revoked').length;
  int get _expiringClients => _clients.where((c) {
    final ts = c['expiryDate'] as Timestamp?;
    if (ts == null) return false;
    final days = ts.toDate().difference(DateTime.now()).inDays;
    return days >= 0 && days <= 7 && c['subscriptionStatus'] != 'expired';
  }).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, size: 24),
          SizedBox(width: 10),
          Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClients,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : Column(children: [
            // Stats Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                _statCard('Total', _totalClients, Icons.people, AppColors.primary),
                _statCard('Active', _activeClients, Icons.check_circle, AppColors.success),
                _statCard('Trial', _trialClients, Icons.timer, AppColors.warning),
                _statCard('Expired', _expiredClients, Icons.cancel, AppColors.error),
                _statCard('Revoked', _revokedClients, Icons.block, Colors.red.shade900),
                if (_expiringClients > 0)
                  _statCard('Expiring Soon', _expiringClients, Icons.warning, Colors.orange),
              ]),
            ),

            // Search & Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by email, name, or device...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                )),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'trial', child: Text('Trial')),
                    DropdownMenuItem(value: 'expired', child: Text('Expired')),
                    DropdownMenuItem(value: 'revoked', child: Text('Revoked')),
                  ],
                  onChanged: (v) => setState(() => _filterStatus = v ?? 'all'),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Client List
            Expanded(child: _filteredClients.isEmpty
              ? Center(child: Text('No clients found',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4))))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredClients.length,
                  itemBuilder: (ctx, i) => _clientCard(_filteredClients[i]),
                ),
            ),
          ]),
    );
  }

  Widget _statCard(String label, int count, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
      ]),
    );
  }

  Widget _clientCard(Map<String, dynamic> client) {
    final email = client['email'] ?? '';
    final name = client['displayName'] ?? '';
    final status = client['subscriptionStatus'] ?? 'unknown';
    final deviceName = client['deviceName'] ?? 'Unknown';
    final deviceModel = client['deviceModel'] ?? '';
    final platform = client['platform'] ?? '';
    final expiryTs = client['expiryDate'] as Timestamp?;
    final expiryDate = expiryTs?.toDate();
    final lastOnlineTs = client['lastOnlineAt'] as Timestamp?;
    final registeredTs = client['registeredAt'] as Timestamp?;
    final notes = client['notes'] ?? '';
    final daysLeft = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : null;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'active':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'trial':
        statusColor = AppColors.warning;
        statusIcon = Icons.timer;
        break;
      case 'expired':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        break;
      case 'revoked':
        statusColor = Colors.red.shade900;
        statusIcon = Icons.block;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: Name, Email, Status
        Row(children: [
          CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.15),
            radius: 20,
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isNotEmpty ? name : email,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (name.isNotEmpty)
              Text(email, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
          ),
        ]),
        const SizedBox(height: 12),

        // Device & Expiry Info
        Wrap(spacing: 16, runSpacing: 8, children: [
          _infoChip(Icons.phone_android, '$deviceName ${deviceModel.isNotEmpty ? "($deviceModel)" : ""}'),
          _infoChip(Icons.computer, platform),
          if (expiryDate != null)
            _infoChip(Icons.event,
              'Expires: ${expiryDate.toIso8601String().split('T').first}'
              '${daysLeft != null ? " (${daysLeft}d)" : ""}',
              color: daysLeft != null && daysLeft <= 7 ? AppColors.warning : null),
          if (lastOnlineTs != null)
            _infoChip(Icons.access_time,
              'Last: ${_timeAgo(lastOnlineTs.toDate())}'),
          if (registeredTs != null)
            _infoChip(Icons.calendar_today,
              'Reg: ${registeredTs.toDate().toIso8601String().split('T').first}'),
        ]),

        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Notes: $notes', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4), fontStyle: FontStyle.italic)),
        ],

        const SizedBox(height: 12),
        // Action Buttons
        Wrap(spacing: 8, runSpacing: 8, children: [
          _actionBtn('Activate', Icons.check_circle, AppColors.success, () => _activateClient(email)),
          _actionBtn('Revoke', Icons.block, AppColors.error, () => _revokeClient(email)),
          _actionBtn('Expiry', Icons.date_range, AppColors.primary, () => _changeExpiry(email, expiryDate)),
          _actionBtn('Migrate', Icons.swap_horiz, Colors.blue, () => _migrateDevice(email)),
          _actionBtn('Notes', Icons.edit_note, Colors.teal, () => _editNotes(email, notes)),
          _actionBtn('Delete', Icons.delete, Colors.red.shade900, () => _deleteClient(email)),
        ]),
      ]),
    ));
  }

  Widget _infoChip(IconData icon, String text, {Color? color}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color ?? Colors.white.withValues(alpha: 0.4)),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: color ?? Colors.white.withValues(alpha: 0.5))),
    ]);
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  // ===== ADMIN ACTIONS =====

  Future<void> _activateClient(String email) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
      helpText: 'SET EXPIRY DATE',
    );
    if (picked == null) return;

    await _subService.activateSubscription(email, picked);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Activated $email until ${picked.toIso8601String().split('T').first}'),
        backgroundColor: AppColors.success,
      ));
    }
    _loadClients();
  }

  Future<void> _revokeClient(String email) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Revoke Subscription?'),
      content: Text('This will immediately block $email from using the app.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Revoke'),
        ),
      ],
    ));
    if (confirm != true) return;

    await _subService.revokeSubscription(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Revoked $email'),
        backgroundColor: AppColors.error,
      ));
    }
    _loadClients();
  }

  Future<void> _changeExpiry(String email, DateTime? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
      helpText: 'SET NEW EXPIRY DATE',
    );
    if (picked == null) return;

    await _subService.updateExpiry(email, picked);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('📅 Expiry updated for $email to ${picked.toIso8601String().split('T').first}'),
        backgroundColor: AppColors.primary,
      ));
    }
    _loadClients();
  }

  Future<void> _migrateDevice(String email) async {
    final reasonCtrl = TextEditingController(text: 'Lost/changed device');
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.swap_horiz, color: Colors.blue),
        SizedBox(width: 8),
        Text('Migrate Device'),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('This will unbind the current device from $email.\nThe user can then re-register on a new device.',
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
        const SizedBox(height: 12),
        TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Migrate'),
        ),
      ],
    ));
    if (confirm != true) return;

    await _subService.migrateDevice(email, reason: reasonCtrl.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('📱 Device unbound for $email. User can register new device.'),
        backgroundColor: Colors.blue,
      ));
    }
    _loadClients();
  }

  Future<void> _editNotes(String email, String currentNotes) async {
    final notesCtrl = TextEditingController(text: currentNotes);
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Admin Notes'),
      content: TextField(
        controller: notesCtrl,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Add notes about this client...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, notesCtrl.text),
          child: const Text('Save'),
        ),
      ],
    ));
    if (result == null) return;

    await _subService.updateNotes(email, result);
    _loadClients();
  }

  Future<void> _deleteClient(String email) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Client?'),
      content: Text('Permanently delete subscription record for $email?\nThis cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ));
    if (confirm != true) return;

    await _subService.deleteSubscription(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🗑️ Deleted $email'),
        backgroundColor: Colors.red.shade900,
      ));
    }
    _loadClients();
  }
}
