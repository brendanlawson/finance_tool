import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/local_date.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_type.dart';

extension TransactionRowMapper on TransactionRow {
  TransactionEntity toDomain({required Set<String> tagIds}) {
    return TransactionEntity(
      id: id,
      type: TransactionTypeStorage.fromStorage(transactionType),
      walletId: walletId,
      destinationWalletId: destinationWalletId,
      categoryId: categoryId,
      amount: Money(minorUnits: amountMinor, currencyCode: currencyCode),
      occurredAtUtc: fromUtcMillis(occurredAtUtc),
      occurredAtLocalDate: LocalDate.parse(occurredAtLocalDate),
      note: note,
      debtId: debtId,
      tagIds: tagIds,
      revision: revision,
      createdAt: fromUtcMillis(createdAt),
      updatedAt: fromUtcMillis(updatedAt),
      deletedAt: deletedAt == null ? null : fromUtcMillis(deletedAt!),
    );
  }
}

TransactionsCompanion transactionInsertCompanion({
  required String id,
  required TransactionType type,
  required String walletId,
  required String? destinationWalletId,
  required String? categoryId,
  required Money amount,
  required DateTime occurredAtUtc,
  required LocalDate occurredAtLocalDate,
  required String? note,
  required String? debtId,
  required int nowMillis,
}) {
  return TransactionsCompanion.insert(
    id: id,
    transactionType: type.storageValue,
    walletId: walletId,
    destinationWalletId: Value(destinationWalletId),
    categoryId: Value(categoryId),
    amountMinor: amount.minorUnits,
    currencyCode: amount.currencyCode,
    occurredAtUtc: toUtcMillis(occurredAtUtc),
    occurredAtLocalDate: occurredAtLocalDate.value,
    note: Value(note),
    debtId: Value(debtId),
    createdAt: nowMillis,
    updatedAt: nowMillis,
  );
}
