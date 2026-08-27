import 'package:finance_tool/app/app.dart';
import 'package:finance_tool/features/categories/application/category_providers.dart';
import 'package:finance_tool/features/categories/domain/category_entity.dart';
import 'package:finance_tool/features/dashboard/application/dashboard_providers.dart';
import 'package:finance_tool/features/debts/application/debt_providers.dart';
import 'package:finance_tool/features/debts/domain/debt_entity.dart';
import 'package:finance_tool/features/settings/application/profile_providers.dart';
import 'package:finance_tool/features/settings/domain/profile_entity.dart';
import 'package:finance_tool/features/transactions/application/transaction_providers.dart';
import 'package:finance_tool/features/transactions/domain/transaction_entity.dart';
import 'package:finance_tool/features/wallets/application/wallet_providers.dart';
import 'package:finance_tool/features/wallets/domain/wallet_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// These widget tests deliberately never touch a real [AppDatabase].
/// Drift's `.watch()` streams are driven by genuine (if brief) async
/// gaps — even over a same-isolate connection — and `flutter_test` runs
/// `testWidgets` bodies inside a `FakeAsync` zone that cannot fast-forward
/// through those the way it fast-forwards `Future.delayed`/`Timer`. The
/// robust fix used everywhere below is the standard Riverpod widget-test
/// pattern: override every leaf `StreamProvider` the screen depends on
/// with an already-resolved `Stream.value(...)`, so rendering depends on
/// nothing but ordinary widget-tree microtasks.
final _fakeProfile = Profile(
  id: 'p1',
  displayName: 'Me',
  baseCurrency: 'VND',
  locale: 'en',
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

// No explicit `List<Override>` annotation: `Override` isn't part of
// flutter_riverpod's public export surface (you're expected to build
// override lists via `.overrideWith(...)` and let inference handle the
// type, never spell the type name yourself).
// ignore: strict_top_level_inference
_baseOverrides() => [
      profileProvider.overrideWith((ref) => Stream.value(_fakeProfile)),
      walletsProvider.overrideWith((ref) => Stream.value(const <Wallet>[])),
      debtsProvider(null).overrideWith((ref) => Stream.value(const <Debt>[])),
      currentMonthTransactionsProvider
          .overrideWith((ref) => Stream.value(const <TransactionEntity>[])),
      recentTransactionsProvider.overrideWith((ref) => Stream.value(const <TransactionEntity>[])),
      categoriesProvider(null).overrideWith((ref) => Stream.value(const <Category>[])),
    ];

void main() {
  testWidgets('the app boots to the dashboard with no data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _baseOverrides(), child: const FinanceApp()),
    );
    // A handful of plain pumps rather than pumpAndSettle(): the dashboard
    // gates on profileProvider first and only then builds the widgets
    // that read the other overridden providers, so more than one
    // microtask/frame cycle is needed even with every stream already
    // resolved.
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Net worth'), findsOneWidget);
    expect(find.text('No wallets yet.'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between the four sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          transactionsProvider(const TransactionQuery(limit: 200))
              .overrideWith((ref) => Stream.value(const <TransactionEntity>[])),
        ],
        child: const FinanceApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Transactions'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No transactions yet.'), findsOneWidget);

    await tester.tap(find.text('Debts'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No debts yet. Tap + to add one.'), findsOneWidget);
  });
}
