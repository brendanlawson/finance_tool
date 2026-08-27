import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/database/app_settings_store.dart';
import '../../categories/application/category_providers.dart';
import '../../categories/domain/category_entity.dart';
import '../../wallets/application/wallet_providers.dart';
import '../../wallets/domain/wallet_entity.dart';
import '../application/fast_add_controller.dart';
import '../domain/transaction_repository.dart';
import '../domain/transaction_type.dart';
import 'widgets/tag_picker.dart';

/// The fast-entry flow from §9: Amount → Type → Wallet → Category → Save,
/// with every field past Amount/Type/Wallet optional so speed never
/// requires giving up correctness (the amount is still parsed exactly via
/// [Money.parse] against the selected wallet's currency, never as a
/// float).
class FastAddScreen extends ConsumerStatefulWidget {
  const FastAddScreen({super.key});

  @override
  ConsumerState<FastAddScreen> createState() => _FastAddScreenState();
}

class _FastAddScreenState extends ConsumerState<FastAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _walletId;
  String? _destinationWalletId;
  String? _categoryId;
  DateTime _occurredAt = DateTime.now();
  bool _defaultsLoaded = false;
  Set<String> _tagIds = {};

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultsOnce(List<Wallet> wallets) async {
    if (_defaultsLoaded) return;
    _defaultsLoaded = true;
    final store = ref.read(appSettingsStoreProvider);
    final lastWalletId = await store.getString(SettingsKeys.lastUsedWalletId);
    final lastCategoryId = await store.getString(SettingsKeys.lastUsedCategoryId);
    if (!mounted) return;
    setState(() {
      _walletId ??= (lastWalletId != null && wallets.any((w) => w.id == lastWalletId))
          ? lastWalletId
          : (wallets.isNotEmpty ? wallets.first.id : null);
      _categoryId ??= lastCategoryId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    if (wallets.isNotEmpty) {
      // Fire-and-forget: only sets state once, guarded by _defaultsLoaded.
      _loadDefaultsOnce(wallets);
    }
    final categories = ref.watch(categoriesProvider(
      _type == TransactionType.income ? CategoryType.income : CategoryType.expense,
    )).value ?? const <Category>[];
    final submitState = ref.watch(fastAddControllerProvider);

    final selectedWallet = wallets.where((w) => w.id == _walletId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: selectedWallet == null ? null : '${selectedWallet.currencyCode} ',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Enter an amount';
                if (selectedWallet == null) return null;
                try {
                  final money = Money.parse(value, selectedWallet.currencyCode);
                  if (_type != TransactionType.transfer && !money.isPositive) {
                    return 'Amount must be greater than zero';
                  }
                } catch (_) {
                  return 'Not a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
                ButtonSegment(value: TransactionType.income, label: Text('Income')),
                ButtonSegment(value: TransactionType.transfer, label: Text('Transfer')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() {
                _type = selection.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _walletId,
              decoration: InputDecoration(
                labelText: _type == TransactionType.transfer ? 'From wallet' : 'Wallet',
              ),
              items: [
                for (final w in wallets) DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (value) => setState(() => _walletId = value),
              validator: (value) => value == null ? 'Select a wallet' : null,
            ),
            if (_type == TransactionType.transfer) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _destinationWalletId,
                decoration: const InputDecoration(labelText: 'To wallet'),
                items: [
                  for (final w in wallets.where((w) => w.id != _walletId))
                    DropdownMenuItem(value: w.id, child: Text(w.name)),
                ],
                onChanged: (value) => setState(() => _destinationWalletId = value),
                validator: (value) => value == null ? 'Select a destination wallet' : null,
              ),
            ] else ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) => value == null ? 'Select a category' : null,
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text('${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-${_occurredAt.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _occurredAt,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _occurredAt = picked);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 16),
            TagPicker(
              selectedTagIds: _tagIds,
              onChanged: (tags) => setState(() => _tagIds = tags),
            ),
            const SizedBox(height: 24),
            if (submitState.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${submitState.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: submitState.isLoading ? null : () => _submit(selectedWallet),
              child: submitState.isLoading
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(Wallet? selectedWallet) async {
    if (!(_formKey.currentState?.validate() ?? false) || selectedWallet == null) return;

    final amount = Money.parse(_amountController.text, selectedWallet.currencyCode);
    final input = NewTransactionInput(
      type: _type,
      walletId: selectedWallet.id,
      destinationWalletId: _type == TransactionType.transfer ? _destinationWalletId : null,
      categoryId: _type == TransactionType.transfer ? null : _categoryId,
      amount: amount,
      occurredAt: _occurredAt,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      tagIds: _tagIds,
    );

    final ok = await ref.read(fastAddControllerProvider.notifier).submit(input);
    if (!mounted) return;
    if (ok) {
      final store = ref.read(appSettingsStoreProvider);
      unawaited(store.setString(SettingsKeys.lastUsedWalletId, selectedWallet.id));
      if (_categoryId != null) {
        unawaited(store.setString(SettingsKeys.lastUsedCategoryId, _categoryId!));
      }
      Navigator.of(context).pop();
    }
  }
}
