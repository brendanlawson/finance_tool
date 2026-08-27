import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/drift_debt_repository.dart';
import '../domain/debt_entity.dart';
import '../domain/debt_payment_entity.dart';
import '../domain/debt_repository.dart';

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DriftDebtRepository(ref.watch(appDatabaseProvider));
});

final debtsProvider = StreamProvider.family<List<Debt>, DebtStatus?>((ref, status) {
  return ref.watch(debtRepositoryProvider).watchDebts(status: status);
});

final debtByIdProvider = StreamProvider.family<Debt?, String>((ref, id) {
  return ref.watch(debtRepositoryProvider).watchDebt(id);
});

final debtPaymentsProvider = StreamProvider.family<List<DebtPayment>, String>((ref, debtId) {
  return ref.watch(debtRepositoryProvider).watchDebtPayments(debtId);
});
