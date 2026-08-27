import 'package:finance_tool/core/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/test_database.dart';

void main() {
  group('Database init/migration (§10/§11)', () {
    test('a freshly created database is stamped with the current schema version', () async {
      final db = createTestDatabase();
      final rows = await db.customSelect('PRAGMA user_version;').get();
      expect(rows.single.data['user_version'], db.schemaVersion);
    });

    test('foreign key enforcement is genuinely active on every connection', () async {
      // SQLite does not enforce foreign keys unless PRAGMA foreign_keys=ON
      // is set per-connection (see AppDatabase._applyConnectionSetup).
      // Inserting directly against the table — bypassing
      // TransactionRepository's own app-level existence check — is what
      // actually proves the *database* itself is rejecting this, not just
      // the repository being careful.
      final db = createTestDatabase();
      await expectLater(
        db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: 'tx-1',
                transactionType: 'income',
                walletId: 'does-not-exist',
                amountMinor: 1000,
                currencyCode: 'VND',
                occurredAtUtc: 0,
                occurredAtLocalDate: '2025-01-01',
                createdAt: 0,
                updatedAt: 0,
              ),
            ),
        throwsException,
      );
    });
  });
}
