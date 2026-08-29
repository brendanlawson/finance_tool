import '../../../core/money/money.dart';
import '../../../core/utils/local_date.dart';
import 'debt_entity.dart';
import 'debt_payment_entity.dart';

class NewDebtInput {
  final String name;
  final DebtType type;
  final String? counterpartyName;
  final Money originalPrincipal;
  final int? interestRateBps;
  final String? interestPeriod;
  final LocalDate startDate;
  final LocalDate? dueDate;
  final Money? installmentAmount;
  final InstallmentFrequency? installmentFrequency;
  final String? notes;

  /// If set, [DebtRepository.createDebt] also records a linked ledger
  /// transaction moving [originalPrincipal] in or out of this wallet — see
  /// the method doc for exactly when to set this vs. leave it null.
  final String? disbursementWalletId;
  final DateTime? disbursementOccurredAt;

  const NewDebtInput({
    required this.name,
    required this.type,
    this.counterpartyName,
    required this.originalPrincipal,
    this.interestRateBps,
    this.interestPeriod,
    required this.startDate,
    this.dueDate,
    this.installmentAmount,
    this.installmentFrequency,
    this.notes,
    this.disbursementWalletId,
    this.disbursementOccurredAt,
  });
}

class RecordDebtPaymentInput {
  final String debtId;
  final String walletId;
  final Money amount;
  final Money principalPortion;
  final DateTime? paidAt;
  final String? note;

  const RecordDebtPaymentInput({
    required this.debtId,
    required this.walletId,
    required this.amount,
    required this.principalPortion,
    this.paidAt,
    this.note,
  });
}

abstract interface class DebtRepository {
  /// Creates the debt record. Set [NewDebtInput.disbursementWalletId] only
  /// when the borrowed/lent cash is genuinely moving through a tracked
  /// wallet *today* — e.g. taking out a new loan that lands in a bank
  /// account, or lending cash out of one right now. Leave it null when
  /// recording a debt that already existed before the user started using
  /// the app (a loan taken out last year): there is no cash movement to
  /// log today, and creating one would double-count money that already
  /// arrived long ago.
  Future<Debt> createDebt(NewDebtInput input);

  /// Records a payment: inserts the linked ledger transaction, the
  /// [DebtPayment] annotation row, and updates the debt's cached
  /// `currentPrincipal`, all inside one database transaction. If the
  /// payment's principal portion would take the remaining balance below
  /// zero (overpayment, §26), the cached balance is clamped to zero and
  /// the debt is marked paid off rather than going negative — see the
  /// implementation doc for the exact rule.
  Future<DebtPayment> recordPayment(RecordDebtPaymentInput input);

  /// Reverses a payment: soft-deletes its linked transaction, reverses the
  /// wallet effect, adds the principal portion back to the debt's
  /// remaining balance (un-clamping `paidOff` back to `active` if it had
  /// flipped), and removes the [DebtPayment] row. Atomic with all of the
  /// above.
  Future<void> deletePayment(String paymentId);

  /// Manual status change — e.g. archiving a debt you no longer want on
  /// the active list, or marking one defaulted. Does not touch
  /// `currentPrincipal` or any ledger row; it is purely a label change.
  Future<void> setStatus(String debtId, DebtStatus status);

  Future<Money> getRemainingBalance(String debtId);

  Stream<Debt?> watchDebt(String debtId);

  Stream<List<Debt>> watchDebts({DebtStatus? status});

  Stream<List<DebtPayment>> watchDebtPayments(String debtId);
}
