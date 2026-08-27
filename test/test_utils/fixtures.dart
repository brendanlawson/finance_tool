import 'package:finance_tool/core/money/money.dart';
import 'package:finance_tool/features/categories/data/drift_category_repository.dart';
import 'package:finance_tool/features/categories/domain/category_entity.dart';
import 'package:finance_tool/features/categories/domain/category_repository.dart';
import 'package:finance_tool/features/wallets/data/drift_wallet_repository.dart';
import 'package:finance_tool/features/wallets/domain/wallet_entity.dart';
import 'package:finance_tool/features/wallets/domain/wallet_repository.dart';

const testCurrency = 'VND';

Future<Wallet> createTestWallet(
  DriftWalletRepository repo, {
  String name = 'Cash',
  int initialBalanceMinor = 0,
}) {
  return repo.createWallet(NewWalletInput(
    name: name,
    accountType: WalletAccountType.cash,
    initialBalance: Money(minorUnits: initialBalanceMinor, currencyCode: testCurrency),
  ));
}

Future<Category> createTestCategory(
  DriftCategoryRepository repo, {
  String name = 'Groceries',
  CategoryType type = CategoryType.expense,
}) {
  return repo.createCategory(NewCategoryInput(name: name, type: type));
}
