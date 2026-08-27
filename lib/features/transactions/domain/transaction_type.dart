/// Mirrors the CHECK constraint on transactions.transaction_type — see
/// lib/core/database/tables/transactions_table.dart. The accounting effect
/// of each value is centralized in WalletBalanceRules, not scattered
/// across UI code, so "what does an expense do to a balance" has exactly
/// one answer in the codebase.
enum TransactionType {
  income,
  expense,
  transfer,
  debtPayment,
  debtBorrowing,
  adjustment,
}

extension TransactionTypeStorage on TransactionType {
  /// The exact string stored in `transactions.transaction_type`.
  String get storageValue => switch (this) {
        TransactionType.income => 'income',
        TransactionType.expense => 'expense',
        TransactionType.transfer => 'transfer',
        TransactionType.debtPayment => 'debt_payment',
        TransactionType.debtBorrowing => 'debt_borrowing',
        TransactionType.adjustment => 'adjustment',
      };

  static TransactionType fromStorage(String value) => switch (value) {
        'income' => TransactionType.income,
        'expense' => TransactionType.expense,
        'transfer' => TransactionType.transfer,
        'debt_payment' => TransactionType.debtPayment,
        'debt_borrowing' => TransactionType.debtBorrowing,
        'adjustment' => TransactionType.adjustment,
        _ => throw ArgumentError('Unknown transaction_type: $value'),
      };
}
