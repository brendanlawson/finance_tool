import 'package:finance_tool/core/errors/app_failure.dart';
import 'package:finance_tool/core/money/money.dart';
import 'package:finance_tool/core/utils/local_date.dart';
import 'package:finance_tool/features/transactions/data/drift_transaction_repository.dart';
import 'package:finance_tool/features/transactions/domain/transaction_repository.dart';
import 'package:finance_tool/features/transactions/domain/transaction_type.dart';
import 'package:finance_tool/features/wallets/data/drift_wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils/fixtures.dart';
import '../../test_utils/test_database.dart';

void main() {
  group('TransactionRepository monthly aggregates and date-range queries', () {
    late DriftWalletRepository wallets;
    late DriftTransactionRepository transactions;

    setUp(() {
      final db = createTestDatabase();
      wallets = DriftWalletRepository(db);
      transactions = DriftTransactionRepository(db);
    });

    test('getMonthlyIncome/getMonthlyExpenses only count income/expense, not transfers', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 1000000);
      final other = await createTestWallet(wallets, name: 'Savings');
      final now = DateTime.now();
      final monthKey = LocalDate.fromDateTime(now).monthKey;

      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.income,
        walletId: wallet.id,
        amount: Money(minorUnits: 200000, currencyCode: testCurrency),
        occurredAt: now,
      ));
      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.expense,
        walletId: wallet.id,
        amount: Money(minorUnits: 75000, currencyCode: testCurrency),
        occurredAt: now,
      ));
      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.transfer,
        walletId: wallet.id,
        destinationWalletId: other.id,
        amount: Money(minorUnits: 999999, currencyCode: testCurrency),
        occurredAt: now,
      ));

      final income = await transactions.getMonthlyIncome(monthKey, testCurrency);
      final expenses = await transactions.getMonthlyExpenses(monthKey, testCurrency);

      expect(income.minorUnits, 200000);
      expect(expenses.minorUnits, 75000);
    });

    test('getTransactionsByDateRange excludes rows outside the range', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 500000);
      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.expense,
        walletId: wallet.id,
        amount: Money(minorUnits: 1000, currencyCode: testCurrency),
        occurredAt: DateTime(2025, 1, 15),
      ));
      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.expense,
        walletId: wallet.id,
        amount: Money(minorUnits: 2000, currencyCode: testCurrency),
        occurredAt: DateTime(2025, 3, 1),
      ));

      final januaryOnly = await transactions.getTransactionsByDateRange(
        LocalDateRange.forMonth(2025, 1),
        walletId: wallet.id,
      );

      expect(januaryOnly, hasLength(1));
      expect(januaryOnly.single.amount.minorUnits, 1000);
    });

    test('deleted transactions are excluded from watchTransactions and monthly totals', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 500000);
      final now = DateTime.now();
      final monthKey = LocalDate.fromDateTime(now).monthKey;
      final tx = await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.expense,
        walletId: wallet.id,
        amount: Money(minorUnits: 5000, currencyCode: testCurrency),
        occurredAt: now,
      ));

      await transactions.deleteTransaction(tx.id);

      final expenses = await transactions.getMonthlyExpenses(monthKey, testCurrency);
      final list = await transactions.watchTransactions(walletId: wallet.id).first;
      expect(expenses.isZero, isTrue);
      expect(list, isEmpty);
    });

    test('debt-linked transaction types are rejected outside the Debts feature', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 500000);
      await expectLater(
        transactions.createTransaction(NewTransactionInput(
          type: TransactionType.debtPayment,
          walletId: wallet.id,
          amount: Money(minorUnits: 1000, currencyCode: testCurrency),
          debtId: 'irrelevant',
        )),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
