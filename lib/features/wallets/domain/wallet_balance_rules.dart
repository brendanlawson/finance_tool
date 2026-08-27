import '../../../core/money/money.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';

/// The signed effect a transaction has on one or more wallets' balances,
/// keyed by wallet id.
class WalletBalanceEffect {
  final Map<String, Money> walletDeltas;
  const WalletBalanceEffect(this.walletDeltas);

  WalletBalanceEffect negated() => WalletBalanceEffect(
        walletDeltas.map((walletId, delta) => MapEntry(walletId, -delta)),
      );
}

/// The single place the accounting rules from §7 of the design brief are
/// encoded. Every repository that mutates a wallet's `current_balance_minor`
/// (TransactionRepository on create/update/delete, DebtRepository on
/// borrow/repay) must go through here rather than re-deriving "does this
/// increase or decrease the balance" locally — that duplication is exactly
/// how a ledger and its cached balance drift apart.
abstract final class WalletBalanceRules {
  /// The effect of *applying* [tx] for the first time.
  ///
  /// [isAssetDebt] only matters for `debtBorrowing`/`debtPayment` and must
  /// be the linked debt's `DebtType.isAssetNotLiability` — the sign flips
  /// depending on which side of the debt the user is on:
  /// * Liability (a loan the user owes): borrowing puts cash *in* hand,
  ///   repaying takes cash *out*.
  /// * Asset (`lentToPerson`, money the user lent out): disbursing the
  ///   loan takes cash *out* of the user's wallet, and being repaid puts
  ///   cash back *in*. This is the exact opposite of the liability case,
  ///   which is why the transaction type alone is not enough information
  ///   — it is always paired with the debt it references.
  static WalletBalanceEffect deltaFor(TransactionEntity tx, {bool isAssetDebt = false}) {
    switch (tx.type) {
      case TransactionType.income:
        return WalletBalanceEffect({tx.walletId: tx.amount});

      case TransactionType.debtBorrowing:
        return WalletBalanceEffect({tx.walletId: isAssetDebt ? -tx.amount : tx.amount});

      case TransactionType.expense:
        return WalletBalanceEffect({tx.walletId: -tx.amount});

      case TransactionType.debtPayment:
        return WalletBalanceEffect({tx.walletId: isAssetDebt ? tx.amount : -tx.amount});

      case TransactionType.transfer:
        final destination = tx.destinationWalletId;
        assert(destination != null, 'transfer without a destination wallet');
        return WalletBalanceEffect({
          tx.walletId: -tx.amount,
          destination!: tx.amount,
        });

      case TransactionType.adjustment:
        // amount already carries its own sign for this one type — see the
        // Transactions table doc comment.
        return WalletBalanceEffect({tx.walletId: tx.amount});
    }
  }

  /// The effect of undoing [tx] (soft-deleting it, or replacing it with a
  /// different amount/type before re-applying the new one).
  static WalletBalanceEffect reversalFor(TransactionEntity tx, {bool isAssetDebt = false}) =>
      deltaFor(tx, isAssetDebt: isAssetDebt).negated();
}
