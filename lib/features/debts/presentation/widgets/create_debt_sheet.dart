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

/// Creating a debt (§6). Interest rate and installment schedule are
/// modeled in the domain/database (see Debt/NewDebtInput) but not yet
/// exposed as fields here — a deliberate scope cut for this foundation,
/// not a data-model gap.
class CreateDebtSheet extends ConsumerStatefulWidget {
  const CreateDebtSheet({super.key});

  @override
  ConsumerState<CreateDebtSheet> createState() => _CreateDebtSheetState();
}

class _CreateDebtSheetState extends ConsumerState<CreateDebtSheet> {
  final _nameController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _principalController = TextEditingController();
  DebtType _type = DebtType.personalLoan;
  String? _disbursementWalletId;
  bool _recordDisbursement = false;

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
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
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
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (_nameController.text.trim().isEmpty || _principalController.text.trim().isEmpty) {
                  return;
                }
                final principal = Money.parse(_principalController.text, baseCurrency);
                await ref.read(debtRepositoryProvider).createDebt(
                      NewDebtInput(
                        name: _nameController.text,
                        type: _type,
                        counterpartyName: _counterpartyController.text.trim().isEmpty
                            ? null
                            : _counterpartyController.text.trim(),
                        originalPrincipal: principal,
                        startDate: LocalDate.today(),
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
