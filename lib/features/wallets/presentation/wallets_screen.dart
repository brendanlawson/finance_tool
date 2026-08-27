import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../settings/application/profile_providers.dart';
import '../application/wallet_providers.dart';
import '../domain/wallet_entity.dart';
import '../domain/wallet_repository.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(allWalletsIncludingArchivedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallets')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateWalletSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: wallets.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No wallets yet. Tap + to add one.'))
            : ListView(
                children: [
                  for (final w in list)
                    ListTile(
                      leading: Icon(w.archived ? Icons.archive_outlined : Icons.wallet_outlined),
                      title: Text(w.name),
                      subtitle: Text(w.accountType.name),
                      trailing: Text(w.currentBalance.format()),
                      onTap: () => _showManageSheet(context, ref, w),
                    ),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Could not load: $error')),
      ),
    );
  }

  void _showManageSheet(BuildContext context, WidgetRef ref, Wallet wallet) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(wallet.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(wallet.archived ? 'Unarchive' : 'Archive'),
              onTap: () async {
                final repo = ref.read(walletRepositoryProvider);
                if (wallet.archived) {
                  await repo.unarchiveWallet(wallet.id);
                } else {
                  await repo.archiveWallet(wallet.id);
                }
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateWalletSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    var type = WalletAccountType.cash;
    final baseCurrency = ref.read(profileProvider).value?.baseCurrency ?? 'VND';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New wallet', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<WalletAccountType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in WalletAccountType.values)
                      DropdownMenuItem(value: t, child: Text(t.name)),
                  ],
                  onChanged: (value) => setState(() => type = value ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Starting balance ($baseCurrency)'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final balance = Money.parse(
                      balanceController.text.trim().isEmpty ? '0' : balanceController.text,
                      baseCurrency,
                    );
                    await ref.read(walletRepositoryProvider).createWallet(
                          NewWalletInput(
                            name: nameController.text,
                            accountType: type,
                            initialBalance: balance,
                          ),
                        );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
