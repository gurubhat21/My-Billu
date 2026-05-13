import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Represents one customizable shortcut
class ShortcutBinding {
  final String id;
  final String label;
  final int screenIndex;
  String keyLabel;
  bool ctrl;
  bool shift;
  bool alt;
  LogicalKeyboardKey key;

  ShortcutBinding({
    required this.id,
    required this.label,
    required this.screenIndex,
    required this.keyLabel,
    required this.key,
    this.ctrl = true,
    this.shift = false,
    this.alt = false,
  });

  SingleActivator toActivator() => SingleActivator(key, control: ctrl, shift: shift, alt: alt);

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'screenIndex': screenIndex,
    'keyLabel': keyLabel,
    'keyId': key.keyId,
    'ctrl': ctrl,
    'shift': shift,
    'alt': alt,
  };

  factory ShortcutBinding.fromMap(Map<String, dynamic> m) {
    final keyId = m['keyId'] as int;
    final logicalKey = LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey.keyA;
    return ShortcutBinding(
      id: m['id'] as String,
      label: m['label'] as String,
      screenIndex: m['screenIndex'] as int,
      keyLabel: m['keyLabel'] as String,
      key: logicalKey,
      ctrl: m['ctrl'] as bool? ?? true,
      shift: m['shift'] as bool? ?? false,
      alt: m['alt'] as bool? ?? false,
    );
  }

  String get displayString {
    final parts = <String>[];
    if (ctrl) parts.add('Ctrl');
    if (alt) parts.add('Alt');
    if (shift) parts.add('Shift');
    parts.add(keyLabel.toUpperCase());
    return parts.join(' + ');
  }
}

/// Default shortcuts
List<ShortcutBinding> getDefaultShortcuts() => [
  ShortcutBinding(id: 'dashboard', label: 'Dashboard', screenIndex: 0, keyLabel: 'D', key: LogicalKeyboardKey.keyD),
  ShortcutBinding(id: 'new_bill', label: 'New Bill / Sales', screenIndex: 1, keyLabel: 'N', key: LogicalKeyboardKey.keyN),
  ShortcutBinding(id: 'history', label: 'Payments / History', screenIndex: 3, keyLabel: 'H', key: LogicalKeyboardKey.keyH),
  ShortcutBinding(id: 'items', label: 'Items', screenIndex: 4, keyLabel: 'I', key: LogicalKeyboardKey.keyI),
  ShortcutBinding(id: 'customers', label: 'Customers', screenIndex: 6, keyLabel: 'U', key: LogicalKeyboardKey.keyU),
  ShortcutBinding(id: 'reports', label: 'Reports', screenIndex: 9, keyLabel: 'R', key: LogicalKeyboardKey.keyR),
  ShortcutBinding(id: 'settings', label: 'Settings', screenIndex: 15, keyLabel: ',', key: LogicalKeyboardKey.comma),
  ShortcutBinding(id: 'purchase', label: 'Purchase', screenIndex: 2, keyLabel: 'P', key: LogicalKeyboardKey.keyP),
  ShortcutBinding(id: 'stock', label: 'Stock', screenIndex: 5, keyLabel: 'K', key: LogicalKeyboardKey.keyK),
  ShortcutBinding(id: 'suppliers', label: 'Suppliers', screenIndex: 13, keyLabel: 'L', key: LogicalKeyboardKey.keyL),
  ShortcutBinding(id: 'quotations', label: 'Quotations', screenIndex: 7, keyLabel: 'Q', key: LogicalKeyboardKey.keyQ),
  ShortcutBinding(id: 'expenses', label: 'Expenses', screenIndex: 8, keyLabel: 'E', key: LogicalKeyboardKey.keyE),
];

/// Load shortcuts from settings
Future<List<ShortcutBinding>> loadShortcuts(AppState appState) async {
  try {
    final json = await appState.getSetting('keyboard_shortcuts');
    if (json != null && json.isNotEmpty) {
      final list = jsonDecode(json) as List;
      return list.map((e) => ShortcutBinding.fromMap(e as Map<String, dynamic>)).toList();
    }
  } catch (_) {}
  return getDefaultShortcuts();
}

/// Save shortcuts to settings
Future<void> saveShortcuts(AppState appState, List<ShortcutBinding> shortcuts) async {
  final json = jsonEncode(shortcuts.map((s) => s.toMap()).toList());
  await appState.saveSetting('keyboard_shortcuts', json);
}

// Map from readable key label to LogicalKeyboardKey
final _keyMap = <String, LogicalKeyboardKey>{
  'a': LogicalKeyboardKey.keyA, 'b': LogicalKeyboardKey.keyB, 'c': LogicalKeyboardKey.keyC,
  'd': LogicalKeyboardKey.keyD, 'e': LogicalKeyboardKey.keyE, 'f': LogicalKeyboardKey.keyF,
  'g': LogicalKeyboardKey.keyG, 'h': LogicalKeyboardKey.keyH, 'i': LogicalKeyboardKey.keyI,
  'j': LogicalKeyboardKey.keyJ, 'k': LogicalKeyboardKey.keyK, 'l': LogicalKeyboardKey.keyL,
  'm': LogicalKeyboardKey.keyM, 'n': LogicalKeyboardKey.keyN, 'o': LogicalKeyboardKey.keyO,
  'p': LogicalKeyboardKey.keyP, 'q': LogicalKeyboardKey.keyQ, 'r': LogicalKeyboardKey.keyR,
  's': LogicalKeyboardKey.keyS, 't': LogicalKeyboardKey.keyT, 'u': LogicalKeyboardKey.keyU,
  'v': LogicalKeyboardKey.keyV, 'w': LogicalKeyboardKey.keyW, 'x': LogicalKeyboardKey.keyX,
  'y': LogicalKeyboardKey.keyY, 'z': LogicalKeyboardKey.keyZ,
  '0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1, '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3, '4': LogicalKeyboardKey.digit4, '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6, '7': LogicalKeyboardKey.digit7, '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
  ',': LogicalKeyboardKey.comma, '.': LogicalKeyboardKey.period,
  '/': LogicalKeyboardKey.slash, ';': LogicalKeyboardKey.semicolon,
  '[': LogicalKeyboardKey.bracketLeft, ']': LogicalKeyboardKey.bracketRight,
  '-': LogicalKeyboardKey.minus, '=': LogicalKeyboardKey.equal,
  'f1': LogicalKeyboardKey.f1, 'f2': LogicalKeyboardKey.f2, 'f3': LogicalKeyboardKey.f3,
  'f4': LogicalKeyboardKey.f4, 'f5': LogicalKeyboardKey.f5, 'f6': LogicalKeyboardKey.f6,
  'f7': LogicalKeyboardKey.f7, 'f8': LogicalKeyboardKey.f8, 'f9': LogicalKeyboardKey.f9,
  'f10': LogicalKeyboardKey.f10, 'f11': LogicalKeyboardKey.f11, 'f12': LogicalKeyboardKey.f12,
};

/// Keyboard Shortcuts Editor Screen
class KeyboardShortcutsScreen extends StatefulWidget {
  const KeyboardShortcutsScreen({super.key});
  @override
  State<KeyboardShortcutsScreen> createState() => _KeyboardShortcutsScreenState();
}

class _KeyboardShortcutsScreenState extends State<KeyboardShortcutsScreen> {
  List<ShortcutBinding> _shortcuts = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final shortcuts = await loadShortcuts(appState);
    setState(() { _shortcuts = shortcuts; _loaded = true; });
  }

  Future<void> _save() async {
    final appState = context.read<AppState>();
    await saveShortcuts(appState, _shortcuts);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10),
          Text('Shortcuts saved! Restart app to apply.')]),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  Future<void> _resetDefaults() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reset Shortcuts?'),
      content: const Text('This will restore all shortcuts to their default values.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
      ],
    ));
    if (confirm == true) {
      setState(() => _shortcuts = getDefaultShortcuts());
      await _save();
    }
  }

  void _editShortcut(int index) {
    final sc = _shortcuts[index];
    showDialog(context: context, builder: (ctx) => _ShortcutRecorderDialog(
      shortcut: sc,
      onSave: (updatedKey, updatedLabel, ctrl, shift, alt) {
        setState(() {
          _shortcuts[index].key = updatedKey;
          _shortcuts[index].keyLabel = updatedLabel;
          _shortcuts[index].ctrl = ctrl;
          _shortcuts[index].shift = shift;
          _shortcuts[index].alt = alt;
        });
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_loaded) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyboard Shortcuts', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: _resetDefaults,
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Reset'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: _save,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Instructions
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                'Click the key button to record a new shortcut. Press the desired key combination.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54))),
            ])),
          const SizedBox(height: 24),

          // Shortcuts list
          ...List.generate(_shortcuts.length, (i) {
            final sc = _shortcuts[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
              ),
              child: Row(children: [
                Icon(_getIconForScreen(sc.screenIndex), size: 20,
                  color: isDark ? Colors.white54 : Colors.black45),
                const SizedBox(width: 12),
                Expanded(child: Text(sc.label, style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87))),
                // Editable key chip
                InkWell(
                  onTap: () => _editShortcut(i),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(sc.displayString, style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12, fontFamily: 'monospace',
                        color: AppColors.primary)),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 14, color: AppColors.primary),
                    ]),
                  ),
                ),
              ]),
            );
          }),

          const SizedBox(height: 20),
          // Add new shortcut button
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _addNewShortcut,
            icon: const Icon(Icons.add),
            label: const Text('Add New Shortcut'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3))),
          )),
        ]),
      ),
    );
  }

  void _addNewShortcut() {
    final screens = {
      0: 'Dashboard', 1: 'New Bill / Sales', 2: 'Purchase', 3: 'Payments / History',
      4: 'Items', 5: 'Stock', 6: 'Customers', 7: 'Quotations', 8: 'Expenses',
      9: 'Reports', 10: 'Credit Notes', 11: 'Purchase Returns', 12: 'Customer Ledger',
      13: 'Suppliers', 14: 'Recurring Bills', 15: 'Settings', 16: 'Audit Trail',
      17: 'Cash & Bank Book',
    };
    // Filter screens that already have shortcuts
    final usedScreens = _shortcuts.map((s) => s.screenIndex).toSet();
    final available = screens.entries.where((e) => !usedScreens.contains(e.key)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All screens already have shortcuts!'), backgroundColor: AppColors.warning));
      return;
    }

    showDialog(context: context, builder: (ctx) {
      int? selectedScreen;
      return StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Add Shortcut'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Select Screen'),
            items: available.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setDialogState(() => selectedScreen = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: selectedScreen == null ? null : () {
            final screenName = screens[selectedScreen!]!;
            Navigator.pop(ctx);
            // Add with default key (first available letter)
            final usedKeys = _shortcuts.map((s) => s.keyLabel.toLowerCase()).toSet();
            String defaultKey = screenName[0].toLowerCase();
            for (final c in screenName.toLowerCase().split('')) {
              if (!usedKeys.contains(c) && _keyMap.containsKey(c)) { defaultKey = c; break; }
            }
            final newSc = ShortcutBinding(
              id: screenName.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '_'),
              label: screenName,
              screenIndex: selectedScreen!,
              keyLabel: defaultKey,
              key: _keyMap[defaultKey] ?? LogicalKeyboardKey.keyA,
            );
            setState(() => _shortcuts.add(newSc));
            // Open editor for the new shortcut
            _editShortcut(_shortcuts.length - 1);
          }, child: const Text('Add')),
        ],
      ));
    });
  }

  IconData _getIconForScreen(int index) {
    const icons = {
      0: Icons.dashboard, 1: Icons.add_circle, 2: Icons.shopping_bag,
      3: Icons.receipt_long, 4: Icons.inventory_2, 5: Icons.warehouse,
      6: Icons.people, 7: Icons.description, 8: Icons.money_off,
      9: Icons.bar_chart, 10: Icons.assignment_return, 11: Icons.keyboard_return,
      12: Icons.account_balance_wallet, 13: Icons.local_shipping, 14: Icons.repeat,
      15: Icons.settings, 16: Icons.history, 17: Icons.account_balance_wallet,
    };
    return icons[index] ?? Icons.keyboard;
  }
}

/// Dialog to record a new key combination
class _ShortcutRecorderDialog extends StatefulWidget {
  final ShortcutBinding shortcut;
  final void Function(LogicalKeyboardKey key, String label, bool ctrl, bool shift, bool alt) onSave;

  const _ShortcutRecorderDialog({required this.shortcut, required this.onSave});
  @override
  State<_ShortcutRecorderDialog> createState() => _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<_ShortcutRecorderDialog> {
  late bool _ctrl, _shift, _alt;
  late LogicalKeyboardKey _key;
  late String _keyLabel;
  bool _recording = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = widget.shortcut.ctrl;
    _shift = widget.shortcut.shift;
    _alt = widget.shortcut.alt;
    _key = widget.shortcut.key;
    _keyLabel = widget.shortcut.keyLabel;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String get _displayString {
    final parts = <String>[];
    if (_ctrl) parts.add('Ctrl');
    if (_alt) parts.add('Alt');
    if (_shift) parts.add('Shift');
    parts.add(_keyLabel.toUpperCase());
    return parts.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit: ${widget.shortcut.label}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        // Current binding
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _recording ? AppColors.error.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _recording ? AppColors.error : AppColors.primary, width: 2)),
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: _recording,
            onKeyEvent: _recording ? (event) {
              if (event is KeyDownEvent) {
                final key = event.logicalKey;
                // Ignore modifier-only presses
                if (key == LogicalKeyboardKey.controlLeft || key == LogicalKeyboardKey.controlRight ||
                    key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight ||
                    key == LogicalKeyboardKey.altLeft || key == LogicalKeyboardKey.altRight) {
                  return;
                }
                // Find human-readable label
                String label = key.keyLabel;
                for (final entry in _keyMap.entries) {
                  if (entry.value == key) { label = entry.key; break; }
                }
                setState(() {
                  _key = key;
                  _keyLabel = label;
                  _ctrl = HardwareKeyboard.instance.isControlPressed;
                  _shift = HardwareKeyboard.instance.isShiftPressed;
                  _alt = HardwareKeyboard.instance.isAltPressed;
                  _recording = false;
                });
              }
            } : null,
            child: Column(children: [
              Text(_recording ? 'Press a key combination...' : _displayString,
                style: TextStyle(
                  fontSize: _recording ? 14 : 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: _recording ? AppColors.error : AppColors.primary)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _recording ? AppColors.error : AppColors.primary),
                onPressed: () {
                  setState(() => _recording = !_recording);
                  if (_recording) _focusNode.requestFocus();
                },
                icon: Icon(_recording ? Icons.cancel : Icons.keyboard, size: 18),
                label: Text(_recording ? 'Cancel' : 'Record New Key'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // Modifier toggles
        Row(children: [
          _modifierChip('Ctrl', _ctrl, (v) => setState(() => _ctrl = v)),
          const SizedBox(width: 8),
          _modifierChip('Shift', _shift, (v) => setState(() => _shift = v)),
          const SizedBox(width: 8),
          _modifierChip('Alt', _alt, (v) => setState(() => _alt = v)),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_key, _keyLabel, _ctrl, _shift, _alt);
            Navigator.pop(context);
          },
          child: const Text('Apply')),
      ],
    );
  }

  Widget _modifierChip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12,
        color: value ? Colors.white : null)),
      selected: value,
      onSelected: onChanged,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
    );
  }
}


