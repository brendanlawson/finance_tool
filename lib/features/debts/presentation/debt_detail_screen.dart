import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../wallets/application/wallet_providers.dart';
import '../../wallets/domain/wallet_entity.dart';
import '../application/debt_providers.dart';
import '../domain/debt_entity.dart';
import '../domain/debt_payment_entity.dart';
import '../domain/debt_repository.dart';

class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debt = ref.watch(debtByIdProvider(debtId));
    final payments = ref.watch(debtPaymentsProvider(debtId));

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.value?.name ?? 'Debt'),
        actions: [
          if (debt.value != null)
            PopupMenuButton<DebtStatus>(
              onSelected: (status) => ref.read(debtRepositoryProvider).setStatus(debtId, status),
              itemBuilder: (context) => [
                if (debt.value!.status != DebtStatus.active)
                  const PopupMenuItem(value: DebtStatus.active, child: Text('Mark active')),
                if (debt.value!.status != DebtStatus.archived)
                  const PopupMenuItem(value: DebtStatus.archived, child: Text('Archive')),
                if (debt.value!.status != DebtStatus.defaulted)
                  const PopupMenuItem(value: DebtStatus.defaulted, child: Text('Mark defaulted')),
              ],
            ),
        ],
      ),
      floatingActionButton: debt.value == null || debt.value!.isSettled
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showRecordPaymentSheet(context, ref),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Record payment'),
            ),
      body: debt.when(
        data: (d) {
          if (d == null) return const Center(child: Text('This debt no longer exists.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: d.progressRatio, minHeight: 8),
                      ),
                      const SizedBox(height: 12),
                      _Row(label: 'Original principal', value: d.originalPrincipal.format()),
                      _Row(label: 'Total paid', value: d.totalPaid.format()),
                      _Row(label: 'Remaining balance', value: d.currentPrincipal.format()),
                      if (d.dueDate != null) _Row(label: 'Due date', value: d.dueDate!.value),
                      _Row(label: 'Status', value: d.status.name),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Payment history', style: Theme.of(context).textTheme.titleMedium),
              payments.when(
                data: (list) => list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No payments recorded yet.'),
                      )
                    : Column(children: [for (final p in list) _PaymentTile(payment: p, debtId: debtId)]),
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Text('Could not load payments: $error'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Could not load: $error')),
      ),
    );
  }

  void _showRecordPaymentSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RecordPaymentSheet(debtId: debtId),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))],
      ),
    );
  }
}

class _PaymentTile extends ConsumerWidget {
  const _PaymentTile({required this.payment, required this.debtId});

  final DebtPayment payment;
  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.call_made),
      title: Text(payment.amount.format()),
      subtitle: Text(
        'Principal ${payment.principalPortion.format()} · '
        '${DateFormat.yMMMd().format(payment.paidAtLocalDate.toDateTime())}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => ref.read(debtRepositoryProvider).deletePayment(payment.id),
      ),
    );
  }
}

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  const _RecordPaymentSheet({required this.debtId});

  final String debtId;

  @override
  ConsumerState<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _amountController = TextEditingController();
  final _interestController = TextEditingController();
  String? _walletId;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final debt = ref.watch(debtByIdProvider(widget.debtId)).value;
    _walletId ??= wallets.isNotEmpty ? wallets.first.id : null;

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
          Text('Record payment', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Total amount paid',
              helperText: debt == null ? null : 'Remaining: ${debt.currentPrincipal.format()}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _interestController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Of which interest (optional)',
              helperText: 'Leave blank if this payment is 100% principal',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _walletId,
            decoration: const InputDecoration(labelText: 'From wallet'),
            items: [for (final w in wallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
            onChanged: (value) => setState(() => _walletId = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              if (debt == null || _walletId == null || _amountController.text.trim().isEmpty) {
                return;
              }
              final amount = Money.parse(_amountController.text, debt.currencyCode);
              final interestText = _interestController.text.trim();
              final interest =
                  interestText.isEmpty ? Money.zero(debt.currencyCode) : Money.parse(interestText, debt.currencyCode);
              if (interest > amount) {
                setState(() => _error = 'Interest cannot be more than the total amount.');
                return;
              }
              final principal = amount - interest;
              await ref.read(debtRepositoryProvider).recordPayment(
                    RecordDebtPaymentInput(
                      debtId: widget.debtId,
                      walletId: _walletId!,
                      amount: amount,
                      principalPortion: principal,
                    ),
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
