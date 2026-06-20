import 'package:delime/data/app_repository.dart';
import 'package:delime/data/database.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late AppRepository repo;

  setUp(() {
    db = AppDatabase(path: inMemoryDatabasePath);
    repo = AppRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedPeople() async {
    await repo.insertPerson(const Person(id: 'a', name: 'Amy', colorValue: 1));
    await repo.insertPerson(const Person(id: 'b', name: 'bob', colorValue: 2));
    await repo.insertPerson(const Person(id: 'c', name: 'Cara', colorValue: 3));
  }

  group('people', () {
    test('inserts and reads back, sorted case-insensitively by name', () async {
      await seedPeople();
      final people = await repo.getPeople();
      expect(people.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('updates an existing person', () async {
      await repo.insertPerson(
        const Person(id: 'a', name: 'Amy', colorValue: 1),
      );
      await repo.updatePerson(
        const Person(id: 'a', name: 'Amelia', colorValue: 9),
      );
      final people = await repo.getPeople();
      expect(people.single.name, 'Amelia');
      expect(people.single.colorValue, 9);
    });

    test('deletes a person', () async {
      await seedPeople();
      await repo.deletePerson('b');
      final people = await repo.getPeople();
      expect(people.map((p) => p.id), ['a', 'c']);
    });
  });

  group('purchases', () {
    Purchase taxiPaidBy(String payer) => Purchase(
      id: 'taxi',
      name: 'Taxi',
      totalCents: 600,
      createdAt: 10,
      payers: [Contribution(personId: payer, amountCents: 600)],
      splits: const [
        Contribution(personId: 'a', amountCents: 300),
        Contribution(personId: 'b', amountCents: 300),
      ],
    );

    test('saves and reconstructs payers and splits', () async {
      await seedPeople();
      await repo.savePurchase(taxiPaidBy('a'));

      final purchases = await repo.getPurchases();
      expect(purchases, hasLength(1));
      final taxi = purchases.single;
      expect(taxi.name, 'Taxi');
      expect(taxi.payers.single.personId, 'a');
      expect(taxi.payers.single.amountCents, 600);
      expect(taxi.splits.map((c) => c.personId), containsAll(['a', 'b']));
      expect(taxi.splitsTotal, 600);
    });

    test('orders purchases newest-first', () async {
      await seedPeople();
      await repo.savePurchase(taxiPaidBy('a'));
      await repo.savePurchase(
        const Purchase(
          id: 'food',
          name: 'Food',
          totalCents: 200,
          createdAt: 99,
          payers: [Contribution(personId: 'a', amountCents: 200)],
          splits: [Contribution(personId: 'a', amountCents: 200)],
        ),
      );
      final purchases = await repo.getPurchases();
      expect(purchases.map((p) => p.id), ['food', 'taxi']);
    });

    test('re-saving replaces child rows instead of duplicating them', () async {
      await seedPeople();
      await repo.savePurchase(taxiPaidBy('a'));
      // Edit: now bob paid, split unchanged.
      await repo.savePurchase(taxiPaidBy('b'));

      final taxi = (await repo.getPurchases()).single;
      expect(taxi.payers, hasLength(1));
      expect(taxi.payers.single.personId, 'b');
      expect(taxi.splits, hasLength(2));
    });

    test('deleting a purchase cascades to its payers and splits', () async {
      await seedPeople();
      await repo.savePurchase(taxiPaidBy('a'));
      expect(await repo.personUsageCount('a'), 1);

      await repo.deletePurchase('taxi');
      expect(await repo.getPurchases(), isEmpty);
      expect(await repo.personUsageCount('a'), 0);
      expect(await repo.personUsageCount('b'), 0);
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
      );
      expect(await repo.personUsageCount('a'), 1);
    });

    test('is zero for an unused person', () async {
      await seedPeople();
      expect(await repo.personUsageCount('c'), 0);
    });
  });
}
