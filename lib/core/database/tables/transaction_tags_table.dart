import 'package:drift/drift.dart';

import 'tags_table.dart';
import 'transactions_table.dart';

/// Many-to-many join between [Transactions] and [Tags]. Cascade-deleting
/// here is safe even though transactions themselves are soft-deleted
/// elsewhere: this table only needs cleanup when a transaction or tag is
/// actually hard-deleted (e.g. tag cleanup, or a restore that replaces the
/// whole database), never as part of normal soft-delete.
@DataClassName('TransactionTagRow')
class TransactionTags extends Table {
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {transactionId, tagId};
}
