import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../../core/utils/local_date.dart';
import '../../../settings/application/profile_providers.dart';
import '../../../wallets/application/wallet_providers.dart';
import '../../../wallets/domain/wallet_entity.dart';
import '../../application/debt_providers.dart';
import '../../domain/debt_entity.dart';
import '../../domain/debt_repository.dart';

/// Creating a debt (§6). Interest rate, due date, and installment
/// schedule live under an "Optional details" section — filling them in
/// isn't required to record a debt, matching the fast-entry philosophy
/// (§9) applied here too: the required fields (name, amount) come first.
class CreateDebtSheet extends ConsumerStatefulWidget {
  const CreateDebtSheet({super.key});

  @override
  ConsumerState<CreateDebtSheet> createState() => _CreateDebtSheetState();
}

class _CreateDebtSheetState extends ConsumerState<CreateDebtSheet> {
  final _nameController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _principalController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _installmentAmountController = TextEditingController();
  final _notesController = TextEditingController();

  DebtType _type = DebtType.personalLoan;
  String? _disbursementWalletId;
  bool _recordDisbursement = false;
  LocalDate? _dueDate;
  String? _interestPeriod;
  InstallmentFrequency? _installmentFrequency;

  @override
  void dispose() {
    _nameController.dispose();
    _counterpartyController.dispose();
    _principalController.dispose();
    _interestRateController.dispose();
    _installmentAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final baseCurrency = ref.watch(profileProvider).value?.baseCurrency ?? 'VND';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New debt', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DebtType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final t in DebtType.values)
                  DropdownMenuItem(value: t, child: Text(t.storageValue.replaceAll('_', ' '))),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _counterpartyController,
              decoration: const InputDecoration(labelText: 'Lender / borrower (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _principalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Principal ($baseCurrency)'),
            ),
            const SizedBox(height: 12),
            if (wallets.isNotEmpty)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _recordDisbursement,
                title: const Text('Cash moved through a wallet today'),
                subtitle: const Text('Leave off if you already had this debt before using the app'),
                onChanged: (value) => setState(() => _recordDisbursement = value ?? false),
              ),
            if (_recordDisbursement)
              DropdownButtonFormField<String>(
                initialValue: _disbursementWalletId,
                decoration: const InputDecoration(labelText: 'Wallet'),
                items: [
                  for (final w in wallets) DropdownMenuItem(value: w.id, child: Text(w.name)),
                ],
                onChanged: (value) => setState(() => _disbursementWalletId = value),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Optional details'),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date'),
                  subtitle: Text(_dueDate?.value ?? 'Not set'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate?.toDateTime() ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _dueDate = LocalDate.fromDateTime(picked));
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _interestRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Interest rate (%/period)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _interestPeriod,
                        decoration: const InputDecoration(labelText: 'Per'),
                        items: const [
                          DropdownMenuItem(value: 'monthly', child: Text('Month')),
                          DropdownMenuItem(value: 'yearly', child: Text('Year')),
                        ],
                        onChanged: (value) => setState(() => _interestPeriod = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _installmentAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Installment ($baseCurrency)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<InstallmentFrequency?>(
                        initialValue: _installmentFrequency,
                        decoration: const InputDecoration(labelText: 'Frequency'),
                        items: const [
                          DropdownMenuItem(value: InstallmentFrequency.weekly, child: Text('Weekly')),
                          DropdownMenuItem(value: InstallmentFrequency.biweekly, child: Text('Biweekly')),
                          DropdownMenuItem(value: InstallmentFrequency.monthly, child: Text('Monthly')),
                        ],
                        onChanged: (value) => setState(() => _installmentFrequency = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                if (_nameController.text.trim().isEmpty || _principalController.text.trim().isEmpty) {
                  return;
                }
                final principal = Money.parse(_principalController.text, baseCurrency);
                final ratePercent = double.tryParse(_interestRateController.text.trim());
                final installmentText = _installmentAmountController.text.trim();
                await ref.read(debtRepositoryProvider).createDebt(
                      NewDebtInput(
                        name: _nameController.text,
                        type: _type,
                        counterpartyName: _counterpartyController.text.trim().isEmpty
                            ? null
                            : _counterpartyController.text.trim(),
                        originalPrincipal: principal,
                        interestRateBps: ratePercent == null ? null : (ratePercent * 100).round(),
                        interestPeriod: ratePercent == null ? null : _interestPeriod,
                        startDate: LocalDate.today(),
                        dueDate: _dueDate,
                        installmentAmount:
                            installmentText.isEmpty ? null : Money.parse(installmentText, baseCurrency),
                        installmentFrequency: installmentText.isEmpty ? null : _installmentFrequency,
                        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                        disbursementWalletId:
                            _recordDisbursement ? _disbursementWalletId : null,
                      ),
                    );
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
