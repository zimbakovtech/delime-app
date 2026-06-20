import 'package:delime/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders title and message', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const EmptyState(
          icon: Icons.group_outlined,
          title: 'No people',
          message: 'Add someone to begin.',
        ),
      ),
    );
    expect(find.text('No people'), findsOneWidget);
    expect(find.text('Add someone to begin.'), findsOneWidget);
  });

  testWidgets('shows no action button when no callback is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EmptyState(
          icon: Icons.group_outlined,
          title: 'No people',
          message: 'x',
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('action button is shown and invokes the callback', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(
        EmptyState(
          icon: Icons.add,
          title: 'No people',
          message: 'x',
          actionLabel: 'Add person',
          onAction: () => tapped++,
        ),
      ),
    );
    expect(find.text('Add person'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(tapped, 1);
  });
}
