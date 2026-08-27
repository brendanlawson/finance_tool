import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/transaction_repository.dart';
import 'transaction_providers.dart';

/// Drives the Fast Add form (§9): a single `submit` call, exposed as
/// `AsyncValue<void>` so the form can show a spinner on `isLoading` and a
/// message on `hasError` without the screen owning any of that state
/// itself. On success there is deliberately no manual list refresh here —
/// [transactionsProvider]/[walletsProvider] pick up the new row on their
/// own because they are streams (§20).
class FastAddController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> submit(NewTransactionInput input) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(transactionRepositoryProvider).createTransaction(input);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
}

final fastAddControllerProvider =
    NotifierProvider<FastAddController, AsyncValue<void>>(FastAddController.new);
