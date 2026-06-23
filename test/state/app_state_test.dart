import 'package:delime/models/balance.dart';
import 'package:delime/models/purchase.dart';
import 'package:delime/models/trip.dart';
import 'package:delime/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_receipt_store.dart';
import '../helpers/fake_repository.dart';

void main() {
  late FakeRepository repo;
  late AppState state;

  /// Creates a trip and opens it, returning its id.
  Future<String> openTrip(AppState s, {String name = 'Greece'}) async {
    final trip = await s.addTrip(
      name: name,
      type: TripType.vacation,
      coverColor: 0xFF34D399,
    );
    await s.selectTrip(trip.id);
    return trip.id;
  }

  setUp(() async {
    repo = FakeRepository();
    state = AppState(repo);
    await state.load();
    await openTrip(state);
  });

  test('starts empty and not loading after load', () async {
    final fresh = AppState(FakeRepository());
    await fresh.load();
    expect(fresh.loading, isFalse);
    expect(fresh.trips, isEmpty);
    expect(fresh.currentTrip, isNull);
    expect(fresh.people, isEmpty);
    expect(fresh.purchases, isEmpty);
  });

  group('trips', () {
    test('addTrip creates an active trip and lands in the active list', () {
      expect(state.trips, hasLength(1));
      expect(state.activeTrips, hasLength(1));
      expect(state.archivedTrips, isEmpty);
      expect(state.currentTrip?.name, 'Greece');
    });

    test('archiving moves a trip to the archived section', () async {
      final trip = state.currentTrip!;
      await state.setTripStatus(trip, TripStatus.archived);
      expect(state.activeTrips, isEmpty);
      expect(state.archivedTrips, hasLength(1));
    });

    test('editing trip name persists', () async {
      final trip = state.currentTrip!;
      await state.saveTripEdits(trip.copyWith(name: 'Italy'));
      expect(state.currentTrip?.name, 'Italy');
    });

    test('deleting the current trip closes it and removes its data', () async {
      await state.addPerson('Solo');
      final id = state.currentTrip!.id;
      await state.deleteTrip(id);
      expect(state.trips, isEmpty);
      expect(state.currentTrip, isNull);
      expect(state.people, isEmpty);
    });

    test('summary tracks member count and outstanding amount', () async {
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
      final summary = state.summaryFor(state.currentTrip!.id);
      expect(summary.memberCount, 2);
      expect(summary.totalSpentCents, 1000);
      expect(summary.outstandingCents, 500);
    });
  });

  group('trip isolation', () {
    test('people and purchases do not leak across trips', () async {
      await state.addPerson('Alice');
      final second = await openTrip(state, name: 'Ski');
      expect(state.people, isEmpty); // second trip starts empty
      await state.addPerson('Bob');
      expect(state.people.single.name, 'Bob');

      // Switch back to the first trip.
      await state.selectTrip(state.trips.firstWhere((t) => t.id != second).id);
      expect(state.people.single.name, 'Alice');
    });
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

  group('settle up', () {
    Future<List<String>> seedDinner() async {
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
      return [john.id, eve.id];
    }

    test('marking settled records a payment and zeroes balances', () async {
      final ids = await seedDinner();
      final eve = ids[1];
      final suggestion = state.settlements.single;
      await state.markSettled(suggestion);

      expect(state.settlementHistory, hasLength(1));
      expect(state.settlementHistory.single.fromPersonId, eve);
      expect(state.settlements, isEmpty); // nothing left outstanding
      expect(state.balances.every((b) => b.isSettled), isTrue);
    });

    test('deleting a settlement restores the outstanding balance', () async {
      await seedDinner();
      await state.markSettled(state.settlements.single);
      expect(state.settlements, isEmpty);

      await state.deleteSettlement(state.settlementHistory.single.id);
      expect(state.settlements, hasLength(1));
    });

    test(
      'simplify toggle switches between minimizer and direct pairs',
      () async {
        // John pays a lunch for John+Eve+Marc; Eve pays a taxi for Eve+Marc.
        await state.addPerson('John');
        await state.addPerson('Eve');
        await state.addPerson('Marc');
        final john = state.people.firstWhere((p) => p.name == 'John');
        final eve = state.people.firstWhere((p) => p.name == 'Eve');
        final marc = state.people.firstWhere((p) => p.name == 'Marc');

        await state.savePurchase(
          Purchase(
            id: state.newPurchaseId(),
            name: 'Lunch',
            totalCents: 900,
            createdAt: 1,
            payers: [Contribution(personId: john.id, amountCents: 900)],
            splits: [
              Contribution(personId: john.id, amountCents: 300),
              Contribution(personId: eve.id, amountCents: 300),
              Contribution(personId: marc.id, amountCents: 300),
            ],
          ),
        );
        await state.savePurchase(
          Purchase(
            id: state.newPurchaseId(),
            name: 'Taxi',
            totalCents: 400,
            createdAt: 2,
            payers: [Contribution(personId: eve.id, amountCents: 400)],
            splits: [
              Contribution(personId: eve.id, amountCents: 200),
              Contribution(personId: marc.id, amountCents: 200),
            ],
          ),
        );

        // Every plan, simplified or direct, must zero the balances out.
        void expectZeroing(List<Settlement> settlements) {
          final net = {for (final b in state.balances) b.personId: b.netCents};
          for (final s in settlements) {
            net[s.fromPersonId] = net[s.fromPersonId]! + s.amountCents;
            net[s.toPersonId] = net[s.toPersonId]! - s.amountCents;
          }
          expect(net.values.every((v) => v == 0), isTrue);
        }

        state.simplifyDebts = true;
        final simplified = state.settlements;
        expectZeroing(simplified);

        state.simplifyDebts = false;
        final direct = state.settlements;
        expectZeroing(direct);

        // Direct keeps Marc→Eve separate; simplified may reroute through John.
        expect(
          direct.any(
            (s) => s.fromPersonId == marc.id && s.toPersonId == eve.id,
          ),
          isTrue,
        );
      },
    );
  });

  group('attachments', () {
    test('addReceipt imports the file and records it', () async {
      final store = FakeReceiptStore();
      final s = AppState(repo, receipts: store);
      await s.load();
      final tripId = await openTrip(s);
      await s.addPerson('A');
      final pid = s.newPurchaseId();
      final a = s.people.single;
      await s.savePurchase(
        Purchase(
          id: pid,
          name: 'Hotel',
          totalCents: 100,
          createdAt: 1,
          payers: [Contribution(personId: a.id, amountCents: 100)],
          splits: [Contribution(personId: a.id, amountCents: 100)],
        ),
      );

      await s.addReceipt(pid, '/tmp/photo.jpg');
      expect(store.imported, ['/tmp/photo.jpg']);
      expect(s.attachmentsFor(pid), hasLength(1));

      await s.removeReceipt(s.attachmentsFor(pid).single);
      expect(store.deleted, hasLength(1));
      expect(s.attachmentsFor(pid), isEmpty);
      expect(tripId, isNotEmpty);
    });
  });
}
