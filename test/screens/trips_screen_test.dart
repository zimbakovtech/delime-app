import 'package:delime/models/trip.dart';
import 'package:delime/screens/trips_screen.dart';
import 'package:delime/state/app_state.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:delime/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_repository.dart';

Widget _wrap(AppState state) => MaterialApp(
  theme: AppTheme.dark(),
  home: ChangeNotifierProvider<AppState>.value(
    value: state,
    child: const TripsScreen(),
  ),
);

void main() {
  testWidgets('shows the empty state when there are no trips', (tester) async {
    final state = AppState(FakeRepository());
    await state.load();
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.text('Start your first trip'), findsOneWidget);
    expect(find.byType(TripCard), findsNothing);
  });

  testWidgets('lists active trips and offers a new-trip action', (
    tester,
  ) async {
    final state = AppState(FakeRepository());
    await state.load();
    await state.addTrip(
      name: 'Greece',
      type: TripType.vacation,
      coverColor: 0xFF34D399,
    );
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.text('Greece'), findsOneWidget);
    expect(find.byType(TripCard), findsOneWidget);
    expect(find.text('New trip'), findsOneWidget);
  });

  testWidgets('separates archived trips into their own section', (
    tester,
  ) async {
    final state = AppState(FakeRepository());
    await state.load();
    await state.addTrip(
      name: 'Active One',
      type: TripType.event,
      coverColor: 0xFF60A5FA,
    );
    final archived = await state.addTrip(
      name: 'Old Trip',
      type: TripType.vacation,
      coverColor: 0xFFF472B6,
    );
    await state.setTripStatus(archived, TripStatus.archived);

    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('Old Trip'), findsOneWidget);
    expect(find.text('Active One'), findsOneWidget);
  });
}
