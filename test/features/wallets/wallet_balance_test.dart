import 'package:finance_tool/core/database/database.dart';
import 'package:finance_tool/core/errors/app_failure.dart';
import 'package:finance_tool/core/money/money.dart';
import 'package:finance_tool/features/transactions/data/drift_transaction_repository.dart';
import 'package:finance_tool/features/transactions/domain/transaction_repository.dart';
import 'package:finance_tool/features/transactions/domain/transaction_type.dart';
import 'package:finance_tool/features/wallets/data/drift_wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils/fixtures.dart';
import '../../test_utils/test_database.dart';

void main() {
  group('Wallet balance accounting (§7/§8)', () {
    late AppDatabase db;
    late DriftWalletRepository wallets;
    late DriftTransactionRepository transactions;

    tearDown(() => db.close());

    setUp(() {
      db = createTestDatabase();
      wallets = DriftWalletRepository(db);
      transactions = DriftTransactionRepository(db);
    });

    test('income increases the wallet balance by the exact amount', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 100000);
      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.income,
        walletId: wallet.id,
        amount: Money(minorUnits: 50000, currencyCode: testCurrency),
      ));

      final updated = await wallets.watchWallet(wallet.id).first;
      expect(updated!.currentBalance.minorUnits, 150000);
    });

    test('expense decreases the wallet balance by the exact amount', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 100000);
      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.expense,
        walletId: wallet.id,
        amount: Money(minorUnits: 30000, currencyCode: testCurrency),
      ));

      final updated = await wallets.watchWallet(wallet.id).first;
      expect(updated!.currentBalance.minorUnits, 70000);
    });

    test('transfer moves money between wallets without touching a third wallet', () async {
      final from = await createTestWallet(wallets, name: 'Bank', initialBalanceMinor: 200000);
      final to = await createTestWallet(wallets, name: 'Cash', initialBalanceMinor: 10000);

      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.transfer,
        walletId: from.id,
        destinationWalletId: to.id,
        amount: Money(minorUnits: 50000, currencyCode: testCurrency),
      ));

      final fromAfter = await wallets.watchWallet(from.id).first;
      final toAfter = await wallets.watchWallet(to.id).first;
      expect(fromAfter!.currentBalance.minorUnits, 150000);
      expect(toAfter!.currentBalance.minorUnits, 60000);
    });

    test('a transfer to the same wallet is rejected before touching the balance', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 100000);
      await expectLater(
        transactions.createTransaction(NewTransactionInput(
          type: TransactionType.transfer,
          walletId: wallet.id,
          destinationWalletId: wallet.id,
          amount: Money(minorUnits: 1000, currencyCode: testCurrency),
        )),
        throwsA(isA<ValidationFailure>()),
      );
      final unchanged = await wallets.watchWallet(wallet.id).first;
      expect(unchanged!.currentBalance.minorUnits, 100000);
    });

    test('deleting a transaction reverses its balance effect exactly', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 100000);
      final tx = await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.expense,
        walletId: wallet.id,
        amount: Money(minorUnits: 40000, currencyCode: testCurrency),
      ));

      var current = await wallets.watchWallet(wallet.id).first;
      expect(current!.currentBalance.minorUnits, 60000);

      await transactions.deleteTransaction(tx.id);

      current = await wallets.watchWallet(wallet.id).first;
      expect(current!.currentBalance.minorUnits, 100000);
    });

    test('editing a transaction amount adjusts the balance by the delta, not the new total', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 100000);
      final tx = await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.expense,
        walletId: wallet.id,
        amount: Money(minorUnits: 20000, currencyCode: testCurrency),
      ));
      // balance: 80000

      await transactions.updateTransaction(
        tx.id,
        TransactionUpdateInput(amount: Money(minorUnits: 50000, currencyCode: testCurrency)),
      );

      final current = await wallets.watchWallet(wallet.id).first;
      expect(current!.currentBalance.minorUnits, 50000);
    });

    test('zero-amount income/expense is rejected', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 100000);
      await expectLater(
        transactions.createTransaction(NewTransactionInput(
          type: TransactionType.expense,
          walletId: wallet.id,
          amount: Money.zero(testCurrency),
        )),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('recomputeBalance rebuilds the same total the ledger already produced', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 100000);
      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.income,
        walletId: wallet.id,
        amount: Money(minorUnits: 25000, currencyCode: testCurrency),
      ));
      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.expense,
        walletId: wallet.id,
        amount: Money(minorUnits: 15000, currencyCode: testCurrency),
      ));

      final recomputed = await wallets.recomputeBalance(wallet.id);
      final cached = await wallets.watchWallet(wallet.id).first;
      expect(recomputed.minorUnits, cached!.currentBalance.minorUnits);
      expect(recomputed.minorUnits, 110000);
    });
  });
}
