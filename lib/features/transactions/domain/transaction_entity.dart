import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import '../../../core/utils/local_date.dart';
import 'transaction_type.dart';

/// One ledger entry. `amount` is always a positive magnitude except for
/// `adjustment`, which may be negative — see the CHECK constraint and
/// class doc on the Transactions table for why, and
/// WalletBalanceRules.deltaFor for how that magnitude turns into a signed
/// wallet-balance effect.
@immutable
class TransactionEntity {
  final String id;
  final TransactionType type;
  final String walletId;
  final String? destinationWalletId;
  final String? categoryId;
  final Money amount;
  final DateTime occurredAtUtc;
  final LocalDate occurredAtLocalDate;
  final String? note;
  final String? debtId;
  final Set<String> tagIds;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const TransactionEntity({
    required this.id,
    required this.type,
    required this.walletId,
    required this.destinationWalletId,
    required this.categoryId,
    required this.amount,
    required this.occurredAtUtc,
    required this.occurredAtLocalDate,
    required this.note,
    required this.debtId,
    required this.tagIds,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  /// True for types that must be excluded from income/expense totals even
  /// though money moved — see §7: a transfer is neither income nor
  /// expense, and neither is drawing down or paying back a debt.
  bool get isCashFlowNeutral =>
      type == TransactionType.transfer ||
      type == TransactionType.debtBorrowing ||
      type == TransactionType.debtPayment;

  TransactionEntity copyWith({
    String? categoryId,
    Money? amount,
    DateTime? occurredAtUtc,
    LocalDate? occurredAtLocalDate,
    String? note,
    Set<String>? tagIds,
    int? revision,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return TransactionEntity(
      id: id,
      type: type,
      walletId: walletId,
      destinationWalletId: destinationWalletId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
      occurredAtLocalDate: occurredAtLocalDate ?? this.occurredAtLocalDate,
      note: note ?? this.note,
      debtId: debtId,
      tagIds: tagIds ?? this.tagIds,
      revision: revision ?? this.revision,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionEntity &&
      other.id == id &&
      other.type == type &&
      other.walletId == walletId &&
      other.destinationWalletId == destinationWalletId &&
      other.categoryId == categoryId &&
      other.amount == amount &&
      other.occurredAtUtc == occurredAtUtc &&
      other.occurredAtLocalDate == occurredAtLocalDate &&
      other.note == note &&
      other.debtId == debtId &&
      other.revision == revision &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
        id,
        type,
        walletId,
        destinationWalletId,
        categoryId,
        amount,
        occurredAtUtc,
        note,
        debtId,
        revision,
        deletedAt,
      );
}
