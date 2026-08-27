import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../categories/application/category_providers.dart';
import '../../../categories/domain/category_entity.dart';
import '../../application/transaction_providers.dart';
import '../../domain/transaction_entity.dart';
import '../../domain/transaction_repository.dart';
import '../../domain/transaction_type.dart';
import 'tag_picker.dart';

/// Edit or delete an already-recorded transaction. Only wallet/type/debt
/// are fixed at creation time (see TransactionUpdateInput's doc) —
/// amount, category, date, and note can all be changed here.
class EditTransactionSheet extends ConsumerStatefulWidget {
  const EditTransactionSheet({super.key, required this.transaction});

  final TransactionEntity transaction;

  @override
  ConsumerState<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<EditTransactionSheet> {
  late final _amountController =
      TextEditingController(text: widget.transaction.amount.toDecimalString());
  late final _noteController = TextEditingController(text: widget.transaction.note ?? '');
  late String? _categoryId = widget.transaction.categoryId;
  late DateTime _occurredAt = widget.transaction.occurredAtLocalDate.toDateTime();
  late Set<String> _tagIds = {...widget.transaction.tagIds};
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final isTransfer = tx.type == TransactionType.transfer;
    final categories = isTransfer
        ? const <Category>[]
        : ref
                .watch(categoriesProvider(
                  tx.type == TransactionType.income ? CategoryType.income : CategoryType.expense,
                ))
                .value ??
            const <Category>[];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit transaction', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Amount (${tx.amount.currencyCode})'),
          ),
          if (!isTransfer) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
          ],
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(
              '${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-${_occurredAt.day.toString().padLeft(2, '0')}',
            ),
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
          const SizedBox(height: 4),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 16),
          TagPicker(
            selectedTagIds: _tagIds,
            onChanged: (tags) => setState(() => _tagIds = tags),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _delete,
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  child: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final amount = Money.parse(_amountController.text, widget.transaction.amount.currencyCode);
      final note = _noteController.text.trim();
      await ref.read(transactionRepositoryProvider).updateTransaction(
            widget.transaction.id,
            TransactionUpdateInput(
              amount: amount,
              categoryId: _categoryId,
              occurredAt: _occurredAt,
              note: note.isEmpty ? null : note,
              clearNote: note.isEmpty,
              tagIds: _tagIds,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(transactionRepositoryProvider).deleteTransaction(widget.transaction.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
        setState(() => _busy = false);
      }
    }
  }
}
