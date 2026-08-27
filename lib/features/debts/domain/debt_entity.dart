import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import '../../../core/utils/local_date.dart';

enum DebtType {
  personalLoan,
  onlineLoan,
  creditLoan,
  borrowedFromPerson,
  lentToPerson,
}

extension DebtTypeStorage on DebtType {
  String get storageValue => switch (this) {
        DebtType.personalLoan => 'personal_loan',
        DebtType.onlineLoan => 'online_loan',
        DebtType.creditLoan => 'credit_loan',
        DebtType.borrowedFromPerson => 'borrowed_from_person',
        DebtType.lentToPerson => 'lent_to_person',
      };

  static DebtType fromStorage(String value) => switch (value) {
        'personal_loan' => DebtType.personalLoan,
        'online_loan' => DebtType.onlineLoan,
        'credit_loan' => DebtType.creditLoan,
        'borrowed_from_person' => DebtType.borrowedFromPerson,
        'lent_to_person' => DebtType.lentToPerson,
        _ => throw ArgumentError('Unknown debt_type: $value'),
      };

  /// Whether this debt type means money is owed *to* the user (an asset,
  /// contributing positively to net worth) rather than *by* the user (a
  /// liability, contributing negatively). Only `lentToPerson` is an asset.
  bool get isAssetNotLiability => this == DebtType.lentToPerson;
}

enum DebtStatus { active, paidOff, defaulted, archived }

extension DebtStatusStorage on DebtStatus {
  String get storageValue => switch (this) {
        DebtStatus.active => 'active',
        DebtStatus.paidOff => 'paid_off',
        DebtStatus.defaulted => 'defaulted',
        DebtStatus.archived => 'archived',
      };

  static DebtStatus fromStorage(String value) => switch (value) {
        'active' => DebtStatus.active,
        'paid_off' => DebtStatus.paidOff,
        'defaulted' => DebtStatus.defaulted,
        'archived' => DebtStatus.archived,
        _ => throw ArgumentError('Unknown debt status: $value'),
      };
}

enum InstallmentFrequency { weekly, biweekly, monthly, custom }

extension InstallmentFrequencyStorage on InstallmentFrequency {
  String get storageValue => name;
  static InstallmentFrequency fromStorage(String value) =>
      InstallmentFrequency.values.byName(value);
}

/// A liability owed by the user, or an asset (money lent out) owed to the
/// user — see [DebtType.isAssetNotLiability]. `currentPrincipal` is a
/// materialized cache of the append-only [DebtPayments]/ledger history;
/// see the class doc on the Debts table for the exact invariant and the
/// documented overpayment-clamping rule.
@immutable
class Debt {
  final String id;
  final String name;
  final DebtType type;
  final String? counterpartyName;
  final Money originalPrincipal;
  final Money currentPrincipal;
  final int? interestRateBps;
  final String? interestPeriod;
  final LocalDate startDate;
  final LocalDate? dueDate;
  final Money? installmentAmount;
  final InstallmentFrequency? installmentFrequency;
  final DebtStatus status;
  final String? notes;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Debt({
    required this.id,
    required this.name,
    required this.type,
    required this.counterpartyName,
    required this.originalPrincipal,
    required this.currentPrincipal,
    required this.interestRateBps,
    required this.interestPeriod,
    required this.startDate,
    required this.dueDate,
    required this.installmentAmount,
    required this.installmentFrequency,
    required this.status,
    required this.notes,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  String get currencyCode => originalPrincipal.currencyCode;

  Money get totalPaid => originalPrincipal - currentPrincipal;

  /// 0.0 to 1.0. `originalPrincipal` is asserted non-zero by the database
  /// CHECK constraint, so this never divides by zero.
  double get progressRatio =>
      (totalPaid.minorUnits / originalPrincipal.minorUnits).clamp(0.0, 1.0);

  bool get isSettled => status == DebtStatus.paidOff || currentPrincipal.isZero;

  Debt copyWith({
    Money? currentPrincipal,
    LocalDate? dueDate,
    DebtStatus? status,
    String? notes,
    int? revision,
    DateTime? updatedAt,
  }) {
    return Debt(
      id: id,
      name: name,
      type: type,
      counterpartyName: counterpartyName,
      originalPrincipal: originalPrincipal,
      currentPrincipal: currentPrincipal ?? this.currentPrincipal,
      interestRateBps: interestRateBps,
      interestPeriod: interestPeriod,
      startDate: startDate,
      dueDate: dueDate ?? this.dueDate,
      installmentAmount: installmentAmount,
      installmentFrequency: installmentFrequency,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      revision: revision ?? this.revision,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Debt &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.originalPrincipal == originalPrincipal &&
      other.currentPrincipal == currentPrincipal &&
      other.status == status &&
      other.revision == revision;

  @override
  int get hashCode =>
      Object.hash(id, name, type, originalPrincipal, currentPrincipal, status, revision);
}
