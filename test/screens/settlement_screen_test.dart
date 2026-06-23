import 'package:delime/models/purchase.dart';
import 'package:delime/models/trip.dart';
import 'package:delime/screens/settlement_screen.dart';
import 'package:delime/state/app_state.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_repository.dart';

/// Trip where Eve owes John €5.00 (John paid a €10 dinner split equally).
Future<AppState> _stateWithDebt() async {
  final state = AppState(FakeRepository());
  await state.load();
  final trip = await state.addTrip(
    name: 'Trip',
    type: TripType.vacation,
    coverColor: 0xFF34D399,
  );
  await state.selectTrip(trip.id);
  await state.addPerson('John');
  await state.addPerson('Eve');
  final john = state.people.firstWhere((p) => p.name == 'John');
  final eve = state.people.firstWhere((p) => p.name == 'Eve');
  await state.savePurchase(
    Purchase(
      id: state.newPurchaseId(),
      name: 'Dinner',
      totalCents: 1000,
      createdAt: 1,
      payers: [Contribution(personId: john.id, amountCents: 1000)],
      splits: [
        Contribution(personId: john.id, amountCents: 500),
        Contribution(personId: eve.id, amountCents: 500),
      ],
    ),
  );
  return state;
}

Widget _wrap(AppState state) => MaterialApp(
  theme: AppTheme.dark(),
  home: ChangeNotifierProvider<AppState>.value(
    value: state,
    child: const SettlementScreen(),
  ),
);

void main() {
  testWidgets('shows the simplify toggle and a settle action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = await _stateWithDebt();
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.text('Simplify debts'), findsOneWidget);
    expect(find.text('Mark settled'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('marking a payment settles the balance and logs history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = await _stateWithDebt();
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark settled'));
    await tester.pumpAndSettle();
    expect(find.text('Record payment'), findsOneWidget);

    await tester.tap(find.text('Mark as settled'));
    await tester.pumpAndSettle();

    expect(state.settlementHistory, hasLength(1));
    expect(state.settlements, isEmpty);
    expect(find.text('All square! 🎉'), findsOneWidget);
    // History tile: Eve paid John (the recorded payment).
    expect(find.text('Eve paid John'), findsOneWidget);
  });
}
