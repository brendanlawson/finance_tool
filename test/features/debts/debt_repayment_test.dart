import 'package:finance_tool/core/errors/app_failure.dart';
import 'package:finance_tool/core/money/money.dart';
import 'package:finance_tool/core/utils/local_date.dart';
import 'package:finance_tool/features/debts/data/drift_debt_repository.dart';
import 'package:finance_tool/features/debts/domain/debt_entity.dart';
import 'package:finance_tool/features/debts/domain/debt_repository.dart';
import 'package:finance_tool/features/wallets/data/drift_wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils/fixtures.dart';
import '../../test_utils/test_database.dart';

void main() {
  group('Debt repayment accounting (§6/§26)', () {
    late DriftWalletRepository wallets;
    late DriftDebtRepository debts;

    setUp(() {
      final db = createTestDatabase();
      wallets = DriftWalletRepository(db);
      debts = DriftDebtRepository(db);
    });

    test('borrowing with disbursement credits the wallet and sets remaining balance', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 0);
      final debt = await debts.createDebt(NewDebtInput(
        name: 'Personal loan',
        type: DebtType.personalLoan,
        originalPrincipal: Money(minorUnits: 23000000, currencyCode: testCurrency),
        startDate: LocalDate.today(),
        disbursementWalletId: wallet.id,
      ));

      final walletAfter = await wallets.watchWallet(wallet.id).first;
      expect(walletAfter!.currentBalance.minorUnits, 23000000);
      expect(debt.currentPrincipal.minorUnits, 23000000);
    });

    test('recording a payment reduces remaining principal and debits the wallet', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 5000000);
      final debt = await debts.createDebt(NewDebtInput(
        name: 'Online loan',
        type: DebtType.onlineLoan,
        originalPrincipal: Money(minorUnits: 23000000, currencyCode: testCurrency),
        startDate: LocalDate.today(),
      ));

      await debts.recordPayment(RecordDebtPaymentInput(
        debtId: debt.id,
        walletId: wallet.id,
        amount: Money(minorUnits: 2300000, currencyCode: testCurrency),
        principalPortion: Money(minorUnits: 2300000, currencyCode: testCurrency),
      ));

      final walletAfter = await wallets.watchWallet(wallet.id).first;
      final debtAfter = await debts.watchDebt(debt.id).first;
      expect(walletAfter!.currentBalance.minorUnits, 5000000 - 2300000);
      expect(debtAfter!.currentPrincipal.minorUnits, 23000000 - 2300000);
      expect(debtAfter.status, DebtStatus.active);
    });

    test('a payment that exactly settles the debt flips status to paidOff', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 5000000);
      final debt = await debts.createDebt(NewDebtInput(
        name: 'Small loan',
        type: DebtType.creditLoan,
        originalPrincipal: Money(minorUnits: 100000, currencyCode: testCurrency),
        startDate: LocalDate.today(),
      ));

      await debts.recordPayment(RecordDebtPaymentInput(
        debtId: debt.id,
        walletId: wallet.id,
        amount: Money(minorUnits: 100000, currencyCode: testCurrency),
        principalPortion: Money(minorUnits: 100000, currencyCode: testCurrency),
      ));

      final debtAfter = await debts.watchDebt(debt.id).first;
      expect(debtAfter!.status, DebtStatus.paidOff);
      expect(debtAfter.currentPrincipal.isZero, isTrue);
    });

    test('overpayment clamps remaining balance at zero instead of going negative', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 5000000);
      final debt = await debts.createDebt(NewDebtInput(
        name: 'Almost paid loan',
        type: DebtType.creditLoan,
        originalPrincipal: Money(minorUnits: 100000, currencyCode: testCurrency),
        startDate: LocalDate.today(),
      ));

      await debts.recordPayment(RecordDebtPaymentInput(
        debtId: debt.id,
        walletId: wallet.id,
        amount: Money(minorUnits: 150000, currencyCode: testCurrency),
        principalPortion: Money(minorUnits: 150000, currencyCode: testCurrency),
      ));

      final debtAfter = await debts.watchDebt(debt.id).first;
      expect(debtAfter!.currentPrincipal.minorUnits, 0);
      expect(debtAfter.status, DebtStatus.paidOff);
      // The wallet still loses the full amount actually paid, overpayment or not.
      final walletAfter = await wallets.watchWallet(wallet.id).first;
      expect(walletAfter!.currentBalance.minorUnits, 5000000 - 150000);
    });

    test('a fully paid-off debt rejects further payments', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 5000000);
      final debt = await debts.createDebt(NewDebtInput(
        name: 'Loan',
        type: DebtType.creditLoan,
        originalPrincipal: Money(minorUnits: 100000, currencyCode: testCurrency),
        startDate: LocalDate.today(),
      ));
      await debts.recordPayment(RecordDebtPaymentInput(
        debtId: debt.id,
        walletId: wallet.id,
        amount: Money(minorUnits: 100000, currencyCode: testCurrency),
        principalPortion: Money(minorUnits: 100000, currencyCode: testCurrency),
      ));

      await expectLater(
        debts.recordPayment(RecordDebtPaymentInput(
          debtId: debt.id,
          walletId: wallet.id,
          amount: Money(minorUnits: 1000, currencyCode: testCurrency),
          principalPortion: Money(minorUnits: 1000, currencyCode: testCurrency),
        )),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('deleting a payment restores the wallet balance and remaining principal', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 5000000);
      final debt = await debts.createDebt(NewDebtInput(
        name: 'Loan',
        type: DebtType.creditLoan,
        originalPrincipal: Money(minorUnits: 500000, currencyCode: testCurrency),
        startDate: LocalDate.today(),
      ));
      final payment = await debts.recordPayment(RecordDebtPaymentInput(
        debtId: debt.id,
        walletId: wallet.id,
        amount: Money(minorUnits: 200000, currencyCode: testCurrency),
        principalPortion: Money(minorUnits: 200000, currencyCode: testCurrency),
      ));

      await debts.deletePayment(payment.id);

      final walletAfter = await wallets.watchWallet(wallet.id).first;
      final debtAfter = await debts.watchDebt(debt.id).first;
      expect(walletAfter!.currentBalance.minorUnits, 5000000);
      expect(debtAfter!.currentPrincipal.minorUnits, 500000);
      expect(debtAfter.status, DebtStatus.active);
    });

    test('lending money out debits the wallet, and repayment credits it back', () async {
      final wallet = await createTestWallet(wallets, initialBalanceMinor: 1000000);
      final debt = await debts.createDebt(NewDebtInput(
        name: 'Lent to a friend',
        type: DebtType.lentToPerson,
        originalPrincipal: Money(minorUnits: 300000, currencyCode: testCurrency),
        startDate: LocalDate.today(),
        disbursementWalletId: wallet.id,
      ));
      final afterLending = await wallets.watchWallet(wallet.id).first;
      expect(afterLending!.currentBalance.minorUnits, 700000);

      await debts.recordPayment(RecordDebtPaymentInput(
        debtId: debt.id,
        walletId: wallet.id,
        amount: Money(minorUnits: 300000, currencyCode: testCurrency),
        principalPortion: Money(minorUnits: 300000, currencyCode: testCurrency),
      ));
      final afterRepayment = await wallets.watchWallet(wallet.id).first;
      expect(afterRepayment!.currentBalance.minorUnits, 1000000);
    });
  });
}
