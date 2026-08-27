import '../../../core/database/database.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/local_date.dart';
import '../domain/wallet_entity.dart';

extension WalletRowMapper on WalletRow {
  Wallet toDomain() {
    return Wallet(
      id: id,
      name: name,
      accountType: WalletAccountType.values.byName(accountType),
      initialBalance: Money(minorUnits: initialBalanceMinor, currencyCode: currencyCode),
      currentBalance: Money(minorUnits: currentBalanceMinor, currencyCode: currencyCode),
      archived: archived,
      revision: revision,
      createdAt: fromUtcMillis(createdAt),
      updatedAt: fromUtcMillis(updatedAt),
    );
  }
}
