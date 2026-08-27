import '../../../core/database/database.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/local_date.dart';
import '../domain/debt_entity.dart';
import '../domain/debt_payment_entity.dart';

extension DebtRowMapper on DebtRow {
  Debt toDomain() {
    return Debt(
      id: id,
      name: name,
      type: DebtTypeStorage.fromStorage(debtType),
      counterpartyName: lenderOrBorrower,
      originalPrincipal: Money(minorUnits: originalPrincipalMinor, currencyCode: currencyCode),
      currentPrincipal: Money(minorUnits: currentPrincipalMinor, currencyCode: currencyCode),
      interestRateBps: interestRateBps,
      interestPeriod: interestPeriod,
      startDate: LocalDate.parse(startDate),
      dueDate: dueDate == null ? null : LocalDate.parse(dueDate!),
      installmentAmount: installmentAmountMinor == null
          ? null
          : Money(minorUnits: installmentAmountMinor!, currencyCode: currencyCode),
      installmentFrequency: installmentFrequency == null
          ? null
          : InstallmentFrequencyStorage.fromStorage(installmentFrequency!),
      status: DebtStatusStorage.fromStorage(status),
      notes: notes,
      revision: revision,
      createdAt: fromUtcMillis(createdAt),
      updatedAt: fromUtcMillis(updatedAt),
    );
  }
}

extension DebtPaymentRowMapper on DebtPaymentRow {
  DebtPayment toDomain(String currencyCode) {
    return DebtPayment(
      id: id,
      debtId: debtId,
      transactionId: transactionId,
      amount: Money(minorUnits: amountMinor, currencyCode: currencyCode),
      principalPortion: Money(minorUnits: principalPortionMinor, currencyCode: currencyCode),
      interestPortion: Money(minorUnits: interestPortionMinor, currencyCode: currencyCode),
      paidAtLocalDate: LocalDate.parse(paidAtLocalDate),
      createdAt: fromUtcMillis(createdAt),
      updatedAt: fromUtcMillis(updatedAt),
    );
  }
}
