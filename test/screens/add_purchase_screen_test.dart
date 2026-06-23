import 'package:delime/models/trip.dart';
import 'package:delime/screens/add_purchase_screen.dart';
import 'package:delime/state/app_state.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_repository.dart';

Future<AppState> _stateWithPeople() async {
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
  return state;
}

Widget _wrap(AppState state) => MaterialApp(
  theme: AppTheme.dark(),
  home: ChangeNotifierProvider<AppState>.value(
    value: state,
    child: const AddPurchaseScreen(),
  ),
);

/// A tall surface so the whole form is laid out (no off-screen taps).
Future<void> _pumpTall(WidgetTester tester, AppState state) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrap(state));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers all four split strategies', (tester) async {
    final state = await _stateWithPeople();
    await _pumpTall(tester, state);

    expect(find.text('Equal'), findsOneWidget);
    expect(find.text('Exact'), findsOneWidget);
    expect(find.text('Percent'), findsOneWidget);
    expect(find.text('Shares'), findsOneWidget);
  });

  testWidgets('save is gated until the split reconciles', (tester) async {
    final state = await _stateWithPeople();
    await _pumpTall(tester, state);

    FilledButton saveButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save purchase'),
    );

    // Nothing entered yet.
    expect(saveButton().onPressed, isNull);

    // Name + amount with the default equal split → ready to save.
    await tester.enterText(find.byType(TextField).at(0), 'Dinner');
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.pumpAndSettle();
    expect(saveButton().onPressed, isNotNull);

    // Percent: seeded 50/50 totals 100% → still valid.
    await tester.tap(find.text('Percent'));
    await tester.pumpAndSettle();
    expect(saveButton().onPressed, isNotNull);

    // Break the percentages → save disabled again.
    await tester.enterText(find.byType(TextField).at(2), '10');
    await tester.pumpAndSettle();
    expect(saveButton().onPressed, isNull);
  });

  testWidgets('shares strategy resolves to exact euro amounts', (tester) async {
    final state = await _stateWithPeople();
    await _pumpTall(tester, state);

    await tester.enterText(find.byType(TextField).at(0), 'Taxi');
    await tester.enterText(find.byType(TextField).at(1), '9');
    await tester.tap(find.text('Shares'));
    await tester.pumpAndSettle();

    // Seeded 1×/1× of €9.00 → €4.50 each resolved share shown.
    expect(find.text('= €4.50'), findsNWidgets(2));

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save purchase'),
    );
    expect(save.onPressed, isNotNull);
  });
}
