import 'package:delime/models/purchase.dart';
import 'package:delime/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_repository.dart';

void main() {
  late FakeRepository repo;
  late AppState state;

  setUp(() async {
    repo = FakeRepository();
    state = AppState(repo);
    await state.load();
  });

  test('starts empty and not loading after load', () {
    expect(state.loading, isFalse);
    expect(state.people, isEmpty);
    expect(state.purchases, isEmpty);
  });

  group('people', () {
    test('adds a person with a trimmed name', () async {
      await state.addPerson('  Marc  ');
      expect(state.people.single.name, 'Marc');
    });

    test('assigns distinct colours to consecutive people', () async {
      await state.addPerson('A');
      await state.addPerson('B');
      final colours = state.people.map((p) => p.colorValue).toSet();
      expect(colours, hasLength(2));
    });

    test('personById resolves a known id and null otherwise', () async {
      await state.addPerson('Solo');
      final id = state.people.single.id;
      expect(state.personById(id)?.name, 'Solo');
      expect(state.personById('missing'), isNull);
    });

    test('updatePerson persists changes', () async {
      await state.addPerson('Old');
      final person = state.people.single;
      await state.updatePerson(person.copyWith(name: 'New'));
      expect(state.people.single.name, 'New');
    });

    test('deletes an unused person', () async {
      await state.addPerson('Temp');
      await state.deletePerson(state.people.single.id);
      expect(state.people, isEmpty);
    });

    test('blocks deleting a person used in a purchase', () async {
      await state.addPerson('Payer');
      final payer = state.people.single;
      await state.savePurchase(
        Purchase(
          id: state.newPurchaseId(),
          name: 'Coffee',
          totalCents: 300,
          createdAt: 1,
          payers: [Contribution(personId: payer.id, amountCents: 300)],
          splits: [Contribution(personId: payer.id, amountCents: 300)],
        ),
      );

      expect(
        () => state.deletePerson(payer.id),
        throwsA(
          isA<AppStateException>().having(
            (e) => e.message,
            'message',
            contains('1 purchase'),
          ),
        ),
      );
      expect(state.people, hasLength(1));
    });
  });

  group('purchases and derived data', () {
    test('newPurchaseId returns unique ids', () {
      expect(state.newPurchaseId(), isNot(state.newPurchaseId()));
    });

    test('saving a purchase drives balances and settlements', () async {
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

      final johnBalance = state.balances.firstWhere(
        (b) => b.personId == john.id,
      );
      expect(johnBalance.netCents, 500);

      final settlements = state.settlements;
      expect(settlements, hasLength(1));
      expect(settlements.single.fromPersonId, eve.id);
      expect(settlements.single.toPersonId, john.id);
      expect(settlements.single.amountCents, 500);
    });

    test('deletePurchase clears derived balances', () async {
      await state.addPerson('A');
      await state.addPerson('B');
      final a = state.people.firstWhere((p) => p.name == 'A');
      final b = state.people.firstWhere((p) => p.name == 'B');
      final id = state.newPurchaseId();
      await state.savePurchase(
        Purchase(
          id: id,
          name: 'X',
          totalCents: 200,
          createdAt: 1,
          payers: [Contribution(personId: a.id, amountCents: 200)],
          splits: [
            Contribution(personId: a.id, amountCents: 100),
            Contribution(personId: b.id, amountCents: 100),
          ],
        ),
      );
      expect(state.settlements, hasLength(1));

      await state.deletePurchase(id);
      expect(state.purchases, isEmpty);
      expect(state.settlements, isEmpty);
      expect(state.balances.every((bal) => bal.isSettled), isTrue);
    });
  });
}
