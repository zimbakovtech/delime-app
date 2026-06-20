import 'package:delime/models/person.dart';
import 'package:delime/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('PersonAvatar renders the person initials', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PersonAvatar(
          person: Person(id: '1', name: 'John Doe', colorValue: 0xFF34D399),
        ),
      ),
    );
    expect(find.text('JD'), findsOneWidget);
  });

  testWidgets('AvatarCluster shows a +N chip when over the max', (
    tester,
  ) async {
    final people = List.generate(
      6,
      (i) => Person(id: '$i', name: 'P$i', colorValue: 0xFF60A5FA),
    );
    await tester.pumpWidget(_wrap(AvatarCluster(people: people, max: 4)));
    // 6 people, max 4 shown -> overflow chip "+2".
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('AvatarCluster without overflow shows no chip', (tester) async {
    final people = List.generate(
      2,
      (i) => Person(id: '$i', name: 'P$i', colorValue: 0xFF60A5FA),
    );
    await tester.pumpWidget(_wrap(AvatarCluster(people: people, max: 4)));
    expect(find.textContaining('+'), findsNothing);
  });
}
