import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import '../../../core/utils/local_date.dart';

/// Annotates the [transactionId] ledger entry as a payment toward
/// [debtId]. Always created and deleted together with that transaction in
/// one DB transaction — see DriftDebtRepository.recordPayment /
/// deletePayment. There is deliberately no `walletId` or `currency` field
/// here: those live on the transaction, which is the single source of
/// truth for what actually happened to a wallet's balance.
@immutable
class DebtPayment {
  final String id;
  final String debtId;
  final String transactionId;
  final Money amount;
  final Money principalPortion;
  final Money interestPortion;
  final LocalDate paidAtLocalDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.transactionId,
    required this.amount,
    required this.principalPortion,
    required this.interestPortion,
    required this.paidAtLocalDate,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) =>
      other is DebtPayment &&
      other.id == id &&
      other.debtId == debtId &&
      other.transactionId == transactionId &&
      other.amount == amount &&
      other.principalPortion == principalPortion &&
      other.interestPortion == interestPortion &&
      other.paidAtLocalDate == paidAtLocalDate;

  @override
  int get hashCode => Object.hash(
        id,
        debtId,
        transactionId,
        amount,
        principalPortion,
        interestPortion,
        paidAtLocalDate,
      );
}
