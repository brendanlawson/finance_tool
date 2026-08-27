import 'package:flutter/material.dart';

import '../../../wallets/domain/wallet_entity.dart';

class WalletBalancesList extends StatelessWidget {
  const WalletBalancesList({super.key, required this.wallets});

  final List<Wallet> wallets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wallets', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            if (wallets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No wallets yet.', style: theme.textTheme.bodyMedium),
              )
            else
              for (final wallet in wallets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(_iconFor(wallet.accountType), size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(wallet.name, overflow: TextOverflow.ellipsis)),
                      Text(
                        wallet.currentBalance.format(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(WalletAccountType type) => switch (type) {
        WalletAccountType.cash => Icons.payments_outlined,
        WalletAccountType.bank => Icons.account_balance_outlined,
        WalletAccountType.eWallet => Icons.smartphone_outlined,
        WalletAccountType.savings => Icons.savings_outlined,
        WalletAccountType.credit => Icons.credit_card_outlined,
        WalletAccountType.other => Icons.wallet_outlined,
      };
}
