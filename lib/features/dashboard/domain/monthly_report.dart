import '../../../core/money/money.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';

/// Income/expense/cash-flow for one month, computed only from `income`
/// and `expense` rows — never `transfer`, `debt_payment`,
/// `debt_borrowing`, or `adjustment` (§7: a transfer is not income just
/// because money landed in a wallet, and borrowing is not income just
/// because cash increased).
class MonthlyCashFlow {
  final Money income;
  final Money expenses;

  const MonthlyCashFlow({required this.income, required this.expenses});

  Money get net => income - expenses;

  factory MonthlyCashFlow.compute(List<TransactionEntity> transactions, String currencyCode) {
    var income = Money.zero(currencyCode);
    var expenses = Money.zero(currencyCode);
    for (final tx in transactions) {
      if (tx.isDeleted || tx.amount.currencyCode != currencyCode) continue;
      switch (tx.type) {
        case TransactionType.income:
          income = income + tx.amount;
        case TransactionType.expense:
          expenses = expenses + tx.amount;
        case TransactionType.transfer:
        case TransactionType.debtPayment:
        case TransactionType.debtBorrowing:
        case TransactionType.adjustment:
          break;
      }
    }
    return MonthlyCashFlow(income: income, expenses: expenses);
  }
}

class CategoryBreakdownEntry {
  final String? categoryId;
  final Money total;
  const CategoryBreakdownEntry({required this.categoryId, required this.total});
}

/// Groups [transactions] of [type] by category for a spending/income
/// breakdown chart, sorted largest first. Uncategorized rows are grouped
/// under a `null` category id rather than dropped.
List<CategoryBreakdownEntry> computeCategoryBreakdown(
  List<TransactionEntity> transactions,
  String currencyCode, {
  required TransactionType type,
}) {
  final totals = <String?, Money>{};
  for (final tx in transactions) {
    if (tx.isDeleted || tx.type != type || tx.amount.currencyCode != currencyCode) continue;
    final existing = totals[tx.categoryId] ?? Money.zero(currencyCode);
    totals[tx.categoryId] = existing + tx.amount;
  }
  final entries = totals.entries
      .map((e) => CategoryBreakdownEntry(categoryId: e.key, total: e.value))
      .toList();
  entries.sort((a, b) => b.total.compareTo(a.total));
  return entries;
}
