import 'dart:io';

import 'package:delime/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds the original v1 schema (no trips, no category) so we can populate it
/// and prove the v1→v2 upgrade preserves every row.
Future<void> _createV1Schema(Database db) async {
  await db.execute('''
    CREATE TABLE people (
      id    TEXT PRIMARY KEY,
      name  TEXT NOT NULL,
      color INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE purchases (
      id         TEXT PRIMARY KEY,
      name       TEXT NOT NULL,
      total      INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE payers (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      purchase_id TEXT NOT NULL,
      person_id   TEXT NOT NULL,
      amount      INTEGER NOT NULL,
      FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
      FOREIGN KEY (person_id)   REFERENCES people (id)
    )
  ''');
  await db.execute('''
    CREATE TABLE splits (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      purchase_id TEXT NOT NULL,
      person_id   TEXT NOT NULL,
      amount      INTEGER NOT NULL,
      FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
      FOREIGN KEY (person_id)   REFERENCES people (id)
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('delime_migration');
    dbPath = '${tempDir.path}/delime.db';
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> seedV1() async {
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _createV1Schema(db),
      ),
    );
    await db.insert('people', {'id': 'p1', 'name': 'John', 'color': 100});
    await db.insert('people', {'id': 'p2', 'name': 'Eve', 'color': 200});
    await db.insert('purchases', {
      'id': 'pur1',
      'name': 'Dinner',
      'total': 1000,
      'created_at': 42,
    });
    await db.insert('payers', {
      'purchase_id': 'pur1',
      'person_id': 'p1',
      'amount': 1000,
    });
    await db.insert('splits', {
      'purchase_id': 'pur1',
      'person_id': 'p1',
      'amount': 500,
    });
    await db.insert('splits', {
      'purchase_id': 'pur1',
      'person_id': 'p2',
      'amount': 500,
    });
    await db.close();
  }

  test('upgrades a populated v1 database to v2 with zero data loss', () async {
    await seedV1();

    final appDb = AppDatabase(path: dbPath);
    final db = await appDb.database; // triggers onUpgrade v1 -> v2

    // A single default trip was created.
    final trips = await db.query('trips');
    expect(trips, hasLength(1));
    expect(trips.single['name'], AppDatabase.defaultTripName);
    expect(trips.single['base_currency'], 'EUR');
    expect(trips.single['status'], 'active');
    final tripId = trips.single['id'] as String;

    // People preserved and assigned to the default trip.
    final people = await db.query('people', orderBy: 'name');
    expect(people.map((r) => r['name']), ['Eve', 'John']);
    expect(people.every((r) => r['trip_id'] == tripId), isTrue);
    expect(people.firstWhere((r) => r['id'] == 'p1')['color'], 100);

    // Purchases preserved, assigned to the trip, and defaulted to 'Other'.
    final purchases = await db.query('purchases');
    expect(purchases, hasLength(1));
    final dinner = purchases.single;
    expect(dinner['name'], 'Dinner');
    expect(dinner['total'], 1000);
    expect(dinner['created_at'], 42);
    expect(dinner['category'], 'Other');
    expect(dinner['trip_id'], tripId);

    // Payers and splits untouched.
    final payers = await db.query('payers');
    expect(payers, hasLength(1));
    expect(payers.single['amount'], 1000);
    final splits = await db.query('splits');
    expect(splits.map((r) => r['amount']), [500, 500]);

    // New tables exist and start empty.
    expect(await db.query('settlements'), isEmpty);
    expect(await db.query('attachments'), isEmpty);

    await appDb.close();
  });

  test('deleting the trip cascades to its people and purchases', () async {
    await seedV1();
    final appDb = AppDatabase(path: dbPath);
    final db = await appDb.database;
    final tripId = (await db.query('trips')).single['id'] as String;

    await db.delete('trips', where: 'id = ?', whereArgs: [tripId]);

    expect(await db.query('people'), isEmpty);
    expect(await db.query('purchases'), isEmpty);
    expect(await db.query('payers'), isEmpty);
    expect(await db.query('splits'), isEmpty);

    await appDb.close();
  });
}
