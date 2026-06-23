import 'package:delime/data/app_repository.dart';
import 'package:delime/data/database.dart';
import 'package:delime/models/attachment.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:delime/models/settlement_record.dart';
import 'package:delime/models/trip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/sample_data.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late AppRepository repo;
  const tripId = 'trip';

  setUp(() async {
    db = AppDatabase(path: inMemoryDatabasePath);
    repo = AppRepository(db);
    await repo.insertTrip(sampleTrip); // id == 'trip'
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedPeople() async {
    await repo.insertPerson(
      const Person(id: 'a', name: 'Amy', colorValue: 1),
      tripId,
    );
    await repo.insertPerson(
      const Person(id: 'b', name: 'bob', colorValue: 2),
      tripId,
    );
    await repo.insertPerson(
      const Person(id: 'c', name: 'Cara', colorValue: 3),
      tripId,
    );
  }

  group('trips', () {
    test('inserts, reads (newest first), updates and deletes', () async {
      final second = sampleTrip.copyWith(name: 'Italy').toMap();
      second['id'] = 'trip2';
      second['updated_at'] = 99;
      await repo.insertTrip(Trip.fromMap(second));

      final trips = await repo.getTrips();
      expect(trips.map((t) => t.id), ['trip2', 'trip']);

      await repo.updateTrip(
        trips.last.copyWith(name: 'Greece 2.0', status: TripStatus.archived),
      );
      final updated = (await repo.getTrips()).firstWhere((t) => t.id == tripId);
      expect(updated.name, 'Greece 2.0');
      expect(updated.status, TripStatus.archived);

      await repo.deleteTrip('trip2');
      expect((await repo.getTrips()).map((t) => t.id), [tripId]);
    });

    test('deleting a trip cascades to its people and purchases', () async {
      await seedPeople();
      await repo.savePurchase(
        const Purchase(
          id: 'x',
          name: 'X',
          totalCents: 100,
          createdAt: 1,
          payers: [Contribution(personId: 'a', amountCents: 100)],
          splits: [Contribution(personId: 'a', amountCents: 100)],
        ),
        tripId,
      );
      await repo.deleteTrip(tripId);
      expect(await repo.getPeople(tripId), isEmpty);
      expect(await repo.getPurchases(tripId), isEmpty);
    });
  });

  group('people', () {
    test('inserts and reads back, sorted case-insensitively by name', () async {
      await seedPeople();
      final people = await repo.getPeople(tripId);
      expect(people.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('scopes people to their trip', () async {
      await repo.insertTrip(
        Trip.fromMap({...sampleTrip.toMap(), 'id': 't2', 'name': 'Other'}),
      );
      await seedPeople();
      await repo.insertPerson(
        const Person(id: 'z', name: 'Zed', colorValue: 9),
        't2',
      );
      expect((await repo.getPeople(tripId)).map((p) => p.id), ['a', 'b', 'c']);
      expect((await repo.getPeople('t2')).map((p) => p.id), ['z']);
    });

    test('updates an existing person', () async {
      await repo.insertPerson(
        const Person(id: 'a', name: 'Amy', colorValue: 1),
        tripId,
      );
      await repo.updatePerson(
        const Person(id: 'a', name: 'Amelia', colorValue: 9),
      );
      final people = await repo.getPeople(tripId);
      expect(people.single.name, 'Amelia');
      expect(people.single.colorValue, 9);
    });

    test('deletes a person', () async {
      await seedPeople();
      await repo.deletePerson('b');
      final people = await repo.getPeople(tripId);
      expect(people.map((p) => p.id), ['a', 'c']);
    });
  });

  group('purchases', () {
    Purchase taxiPaidBy(String payer) => Purchase(
      id: 'taxi',
      name: 'Taxi',
      totalCents: 600,
      createdAt: 10,
      category: 'Transport',
      payers: [Contribution(personId: payer, amountCents: 600)],
      splits: const [
        Contribution(personId: 'a', amountCents: 300),
        Contribution(personId: 'b', amountCents: 300),
      ],
    );

    test('saves and reconstructs payers, splits and category', () async {
      await seedPeople();
      await repo.savePurchase(taxiPaidBy('a'), tripId);

      final purchases = await repo.getPurchases(tripId);
      expect(purchases, hasLength(1));
      final taxi = purchases.single;
      expect(taxi.name, 'Taxi');
      expect(taxi.category, 'Transport');
      expect(taxi.payers.single.personId, 'a');
      expect(taxi.payers.single.amountCents, 600);
      expect(taxi.splits.map((c) => c.personId), containsAll(['a', 'b']));
      expect(taxi.splitsTotal, 600);
    });

    test('orders purchases newest-first', () async {
      await seedPeople();
      await repo.savePurchase(taxiPaidBy('a'), tripId);
      await repo.savePurchase(
        const Purchase(
          id: 'food',
          name: 'Food',
          totalCents: 200,
          createdAt: 99,
          payers: [Contribution(personId: 'a', amountCents: 200)],
          splits: [Contribution(personId: 'a', amountCents: 200)],
        ),
        tripId,
      );
      final purchases = await repo.getPurchases(tripId);
      expect(purchases.map((p) => p.id), ['food', 'taxi']);
    });

    test('re-saving replaces child rows instead of duplicating them', () async {
      await seedPeople();
      await repo.savePurchase(taxiPaidBy('a'), tripId);
      // Edit: now bob paid, split unchanged.
      await repo.savePurchase(taxiPaidBy('b'), tripId);

      final taxi = (await repo.getPurchases(tripId)).single;
      expect(taxi.payers, hasLength(1));
      expect(taxi.payers.single.personId, 'b');
      expect(taxi.splits, hasLength(2));
    });

    test('deleting a purchase cascades to its payers and splits', () async {
      await seedPeople();
      await repo.savePurchase(taxiPaidBy('a'), tripId);
      expect(await repo.personUsageCount('a'), 1);

      await repo.deletePurchase('taxi');
      expect(await repo.getPurchases(tripId), isEmpty);
      expect(await repo.personUsageCount('a'), 0);
      expect(await repo.personUsageCount('b'), 0);
    });
  });

  group('settlements', () {
    test('inserts, reads newest-first by trip, and deletes', () async {
      await seedPeople();
      await repo.insertSettlement(
        const SettlementRecord(
          id: 's1',
          tripId: tripId,
          fromPersonId: 'b',
          toPersonId: 'a',
          amountCents: 300,
          settledAt: 1,
        ),
      );
      await repo.insertSettlement(
        const SettlementRecord(
          id: 's2',
          tripId: tripId,
          fromPersonId: 'c',
          toPersonId: 'a',
          amountCents: 100,
          note: 'cash',
          settledAt: 2,
        ),
      );
      final records = await repo.getSettlements(tripId);
      expect(records.map((r) => r.id), ['s2', 's1']);
      expect(records.first.note, 'cash');

      await repo.deleteSettlement('s1');
      expect((await repo.getSettlements(tripId)).map((r) => r.id), ['s2']);
    });

    test('cascades when its trip is deleted', () async {
      await repo.insertSettlement(
        const SettlementRecord(
          id: 's1',
          tripId: tripId,
          fromPersonId: 'b',
          toPersonId: 'a',
          amountCents: 300,
          settledAt: 1,
        ),
      );
      await repo.deleteTrip(tripId);
      expect(await repo.getSettlements(tripId), isEmpty);
    });
  });

  group('attachments', () {
    Future<void> seedPurchase() async {
      await seedPeople();
      await repo.savePurchase(
        const Purchase(
          id: 'pur',
          name: 'Hotel',
          totalCents: 100,
          createdAt: 1,
          payers: [Contribution(personId: 'a', amountCents: 100)],
          splits: [Contribution(personId: 'a', amountCents: 100)],
        ),
        tripId,
      );
    }

    test('inserts and reads by purchase and by trip', () async {
      await seedPurchase();
      await repo.insertAttachment(
        const Attachment(
          id: 'att1',
          purchaseId: 'pur',
          filePath: '/r/1.jpg',
          createdAt: 1,
        ),
      );
      expect(await repo.getAttachmentsForPurchase('pur'), hasLength(1));
      expect((await repo.getAttachments(tripId)).single.filePath, '/r/1.jpg');
    });

    test('deletes individually and cascades with the purchase', () async {
      await seedPurchase();
      await repo.insertAttachment(
        const Attachment(
          id: 'att1',
          purchaseId: 'pur',
          filePath: '/r/1.jpg',
          createdAt: 1,
        ),
      );
      await repo.insertAttachment(
        const Attachment(
          id: 'att2',
          purchaseId: 'pur',
          filePath: '/r/2.jpg',
          createdAt: 2,
        ),
      );
      await repo.deleteAttachment('att1');
      expect(await repo.getAttachmentsForPurchase('pur'), hasLength(1));

      await repo.deletePurchase('pur');
      expect(await repo.getAttachments(tripId), isEmpty);
    });
  });

  group('personUsageCount', () {
    test('counts a purchase once even if used as payer and in split', () async {
      await seedPeople();
      await repo.savePurchase(
        const Purchase(
          id: 'x',
          name: 'X',
          totalCents: 100,
          createdAt: 1,
          payers: [Contribution(personId: 'a', amountCents: 100)],
          splits: [Contribution(personId: 'a', amountCents: 100)],
        ),
        tripId,
      );
      expect(await repo.personUsageCount('a'), 1);
    });

    test('is zero for an unused person', () async {
      await seedPeople();
      expect(await repo.personUsageCount('c'), 0);
    });
  });
}
