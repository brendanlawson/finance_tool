import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_lock_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../application/profile_providers.dart';

/// Common currency codes to pick from — not exhaustive, just enough that
/// picking a currency doesn't mean typing a raw ISO code from memory.
/// Any 3-letter code still works; this list is only what shows up first.
const _commonCurrencies = [
  'VND', 'USD', 'EUR', 'JPY', 'GBP', 'AUD', 'CAD', 'SGD', 'THB', 'KRW', //
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final pinSet = ref.watch(isPinSetProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profile.when(
        data: (p) => ListView(
          children: [
            ListTile(
              title: const Text('Name'),
              subtitle: Text(p.displayName),
              onTap: () => _editName(context, ref, p.displayName),
            ),
            ListTile(
              title: const Text('Currency'),
              subtitle: Text(p.baseCurrency),
              onTap: () => _editCurrency(context, ref, p.baseCurrency),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('App lock'),
              subtitle: Text(pinSet ? 'PIN is set' : 'Off'),
              onTap: () => pinSet ? _pinOptions(context, ref) : _setPin(context, ref),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Could not load: $error')),
      ),
    );
  }

  Future<void> _pinOptions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: const Text('Change PIN'),
              onTap: () => Navigator.of(context).pop('change'),
            ),
            ListTile(
              title: const Text('Turn off app lock'),
              onTap: () => Navigator.of(context).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'change') {
      await _setPin(context, ref);
    } else if (action == 'remove') {
      await ref.read(appLockServiceProvider).resetPin();
      ref.invalidate(isPinSetProvider);
    }
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set a PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (pin == null || pin.length < 4) return;
    await ref.read(appLockServiceProvider).setPin(pin);
    ref.invalidate(isPinSetProvider);
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == current) return;
    await ref.read(profileRepositoryProvider).updateProfile(displayName: name);
  }

  Future<void> _editCurrency(BuildContext context, WidgetRef ref, String current) async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Currency'),
        children: [
          for (final c in _commonCurrencies)
            SimpleDialogOption(onPressed: () => Navigator.of(context).pop(c), child: Text(c)),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(context).pop();
              final custom = await _promptCustomCurrency(context);
              if (custom != null) {
                await ref.read(profileRepositoryProvider).updateProfile(baseCurrency: custom);
              }
            },
            child: const Text('Other…'),
          ),
        ],
      ),
    );
    if (code == null || code == current) return;
    await ref.read(profileRepositoryProvider).updateProfile(baseCurrency: code);
  }

  Future<String?> _promptCustomCurrency(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Currency code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 3,
          decoration: const InputDecoration(hintText: 'e.g. VND, USD, EUR'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              Navigator.of(context).pop(code.length == 3 ? code : null);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
