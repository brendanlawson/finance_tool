import 'package:finance_tool/core/money/money.dart';
import 'package:finance_tool/core/utils/local_date.dart';
import 'package:finance_tool/features/backup/data/drift_backup_repository.dart';
import 'package:finance_tool/features/debts/data/drift_debt_repository.dart';
import 'package:finance_tool/features/debts/domain/debt_entity.dart';
import 'package:finance_tool/features/debts/domain/debt_repository.dart';
import 'package:finance_tool/features/transactions/data/drift_transaction_repository.dart';
import 'package:finance_tool/features/transactions/domain/transaction_repository.dart';
import 'package:finance_tool/features/transactions/domain/transaction_type.dart';
import 'package:finance_tool/features/wallets/data/drift_wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils/fake_path_provider.dart';
import '../../test_utils/fixtures.dart';
import '../../test_utils/test_database.dart';

const _passphrase = 'correct horse battery staple';

void main() {
  // DriftBackupRepository's encrypted-container helpers call
  // path_provider's getTemporaryDirectory() — there is no platform behind
  // that plugin channel at all under plain `flutter_test`, so it needs a
  // fake implementation installed, not just the test binding initialized.
  TestWidgetsFlutterBinding.ensureInitialized();
  FakePathProviderPlatform.install();

  group('Backup export -> restore round trip (§13/§15)', () {
    test(
        'export -> destroy current data -> restore reproduces the same wallet/debt state',
        () async {
      final db = createTestDatabase();
      final wallets = DriftWalletRepository(db);
      final transactions = DriftTransactionRepository(db);
      final debts = DriftDebtRepository(db);
      final backup = DriftBackupRepository(db, wallets);

      final wallet = await createTestWallet(wallets, initialBalanceMinor: 1000000);
      await transactions.createTransaction(NewTransactionInput(
        type: TransactionType.expense,
        walletId: wallet.id,
        amount: Money(minorUnits: 150000, currencyCode: testCurrency),
      ));
      final debt = await debts.createDebt(NewDebtInput(
        name: 'Loan',
        type: DebtType.personalLoan,
        originalPrincipal: Money(minorUnits: 5000000, currencyCode: testCurrency),
        startDate: LocalDate.today(),
        disbursementWalletId: wallet.id,
      ));
      await debts.recordPayment(RecordDebtPaymentInput(
        debtId: debt.id,
        walletId: wallet.id,
        amount: Money(minorUnits: 500000, currencyCode: testCurrency),
        principalPortion: Money(minorUnits: 500000, currencyCode: testCurrency),
      ));

      final walletBalanceBefore = (await wallets.watchWallet(wallet.id).first)!.currentBalance;
      final debtBalanceBefore = (await debts.watchDebt(debt.id).first)!.currentPrincipal;
      final transactionCountBefore =
          (await transactions.watchTransactions(walletId: wallet.id).first).length;

      // Export an encrypted backup through the real container format.
      final export = await backup.exportEncryptedBackup(_passphrase);
      final preview = await backup.validateBackupFile(export.bytes, _passphrase);

      // "Application data is removed" (§34 step 14): wipe every table
      // directly, bypassing the repositories entirely, so this test does
      // not rely on any repository-level delete method to simulate loss.
      await db.transaction(() async {
        await db.delete(db.transactionTags).go();
        await db.delete(db.debtPayments).go();
        await db.delete(db.transactions).go();
        await db.delete(db.debts).go();
        await db.delete(db.categories).go();
        await db.delete(db.wallets).go();
        await db.delete(db.tags).go();
        await db.delete(db.appSettings).go();
        await db.delete(db.profiles).go();
      });
      expect(await wallets.watchWallets(includeArchived: true).first, isEmpty);

      await backup.restoreFromBackup(preview);

      final walletAfter = (await wallets.watchWallet(wallet.id).first)!;
      final debtAfter = (await debts.watchDebt(debt.id).first)!;
      final transactionsAfter = await transactions.watchTransactions(walletId: wallet.id).first;

      expect(walletAfter.currentBalance, walletBalanceBefore);
      expect(debtAfter.currentPrincipal, debtBalanceBefore);
      expect(transactionsAfter.length, transactionCountBefore);
    });

    test('validateBackupFile rejects a wrong passphrase without touching the database', () async {
      final db = createTestDatabase();
      final wallets = DriftWalletRepository(db);
      final backup = DriftBackupRepository(db, wallets);
      await createTestWallet(wallets);

      final export = await backup.exportEncryptedBackup(_passphrase);

      await expectLater(
        backup.validateBackupFile(export.bytes, 'wrong passphrase'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
