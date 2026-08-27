import 'package:meta/meta.dart';

import '../../../core/money/money.dart';

enum WalletAccountType { cash, bank, eWallet, savings, credit, other }

/// A wallet/account the user tracks money in or out of.
///
/// [currentBalance] is a read model, not something callers construct by
/// hand outside the data layer: it always equals [initialBalance] plus the
/// net effect of every non-deleted ledger transaction against this wallet
/// (see WalletBalanceRules). Nothing in the domain or presentation layer
/// should ever compute a balance itself.
@immutable
class Wallet {
  final String id;
  final String name;
  final WalletAccountType accountType;
  final Money initialBalance;
  final Money currentBalance;
  final bool archived;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Wallet({
    required this.id,
    required this.name,
    required this.accountType,
    required this.initialBalance,
    required this.currentBalance,
    required this.archived,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  String get currencyCode => initialBalance.currencyCode;

  /// Field-preserving copy. Note: passing `null` for [name] etc. means
  /// "keep the current value", not "clear it" — every field here is
  /// non-nullable on the entity itself, so that limitation never bites.
  Wallet copyWith({
    String? name,
    WalletAccountType? accountType,
    Money? currentBalance,
    bool? archived,
    int? revision,
    DateTime? updatedAt,
  }) {
    return Wallet(
      id: id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      initialBalance: initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      archived: archived ?? this.archived,
      revision: revision ?? this.revision,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Wallet &&
      other.id == id &&
      other.name == name &&
      other.accountType == accountType &&
      other.initialBalance == initialBalance &&
      other.currentBalance == currentBalance &&
      other.archived == archived &&
      other.revision == revision &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        accountType,
        initialBalance,
        currentBalance,
        archived,
        revision,
        updatedAt,
      );
}
