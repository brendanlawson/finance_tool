import '../../../core/money/money.dart';
import '../../debts/domain/debt_entity.dart';
import '../../wallets/domain/wallet_entity.dart';

/// Net worth = Assets − Liabilities (§7).
///
/// Assets are the balances of non-archived wallets plus the remaining
/// principal of any [DebtType.lentToPerson] debt (money someone else owes
/// the user). Liabilities are the remaining principal of every other debt
/// type. A wallet's balance is never itself treated as reduced by an
/// unrelated liability — each debt is counted once, as a liability, not
/// netted against the wallet the borrowed cash happened to land in.
///
/// Money of different currencies is never summed together (that throws in
/// [Money]), so totals are kept per currency. V1 assumes a single primary
/// currency in practice (§27) and the dashboard surfaces [byCurrency] for
/// that primary code; a true multi-currency net worth would additionally
/// require FX rates, which is out of scope here by design.
class NetWorth {
  final Map<String, Money> assetsByCurrency;
  final Map<String, Money> liabilitiesByCurrency;

  const NetWorth({required this.assetsByCurrency, required this.liabilitiesByCurrency});

  Money? forCurrency(String currencyCode) {
    final assets = assetsByCurrency[currencyCode] ?? Money.zero(currencyCode);
    final liabilities = liabilitiesByCurrency[currencyCode] ?? Money.zero(currencyCode);
    return assets - liabilities;
  }

  Set<String> get currencies => {...assetsByCurrency.keys, ...liabilitiesByCurrency.keys};

  factory NetWorth.compute({required List<Wallet> wallets, required List<Debt> debts}) {
    final assets = <String, Money>{};
    final liabilities = <String, Money>{};

    void addTo(Map<String, Money> bucket, Money amount) {
      final existing = bucket[amount.currencyCode] ?? Money.zero(amount.currencyCode);
      bucket[amount.currencyCode] = existing + amount;
    }

    for (final wallet in wallets) {
      if (wallet.archived) continue;
      addTo(assets, wallet.currentBalance);
    }

    for (final debt in debts) {
      if (debt.currentPrincipal.isZero) continue;
      if (debt.type.isAssetNotLiability) {
        addTo(assets, debt.currentPrincipal);
      } else {
        addTo(liabilities, debt.currentPrincipal);
      }
    }

    return NetWorth(assetsByCurrency: assets, liabilitiesByCurrency: liabilities);
  }
}
