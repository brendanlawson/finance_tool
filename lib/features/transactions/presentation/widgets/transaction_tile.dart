import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../domain/transaction_entity.dart';
import '../../domain/transaction_type.dart';
import 'edit_transaction_sheet.dart';

/// One ledger row, shared by the dashboard's recent-transactions card and
/// the full transaction list so the two never visually drift apart. Tapping
/// opens edit/delete — except for debt-linked rows, which are managed from
/// the Debts screen (see TransactionRepository's own rejection of edits to
/// those, which this UI mirrors rather than let people hit that error).
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

  final TransactionEntity transaction;

  bool get _isEditable =>
      transaction.type != TransactionType.debtPayment &&
      transaction.type != TransactionType.debtBorrowing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == TransactionType.income;
    final isExpense = transaction.type == TransactionType.expense;
    final color = isIncome
        ? theme.colorScheme.income
        : isExpense
            ? theme.colorScheme.expense
            : theme.colorScheme.onSurfaceVariant;
    final sign = isIncome ? '+' : (isExpense ? '-' : '');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(_iconFor(transaction.type), color: color, size: 20),
      ),
      title: Text(
        transaction.note?.isNotEmpty == true ? transaction.note! : _labelFor(transaction.type),
      ),
      subtitle: Text(DateFormat.yMMMd().format(transaction.occurredAtLocalDate.toDateTime())),
      trailing: Text(
        '$sign${transaction.amount.format()}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: _isEditable
          ? () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => EditTransactionSheet(transaction: transaction),
              )
          : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Manage this from the Debts screen.')),
              ),
    );
  }

  IconData _iconFor(TransactionType type) => switch (type) {
        TransactionType.income => Icons.arrow_downward,
        TransactionType.expense => Icons.arrow_upward,
        TransactionType.transfer => Icons.swap_horiz,
        TransactionType.debtPayment => Icons.call_made,
        TransactionType.debtBorrowing => Icons.call_received,
        TransactionType.adjustment => Icons.tune,
      };

  String _labelFor(TransactionType type) => switch (type) {
        TransactionType.income => 'Income',
        TransactionType.expense => 'Expense',
        TransactionType.transfer => 'Transfer',
        TransactionType.debtPayment => 'Debt payment',
        TransactionType.debtBorrowing => 'Debt borrowing',
        TransactionType.adjustment => 'Adjustment',
      };
}
