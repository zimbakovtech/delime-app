import 'package:delime/data/database.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:sqflite/sqflite.dart';

/// Data-access layer. All persistence goes through here; the rest of the app
/// never touches SQL directly.
class AppRepository {
  AppRepository(this._dbProvider);

  final AppDatabase _dbProvider;

  Future<Database> get _db => _dbProvider.database;

  // ---- People ----------------------------------------------------------

  Future<List<Person>> getPeople() async {
    final db = await _db;
    final rows = await db.query('people', orderBy: 'name COLLATE NOCASE');
    return rows.map(Person.fromMap).toList();
  }

  Future<void> insertPerson(Person person) async {
    final db = await _db;
    await db.insert('people', person.toMap());
  }

  Future<void> updatePerson(Person person) async {
    final db = await _db;
    await db.update('people', person.toMap(),
        where: 'id = ?', whereArgs: [person.id]);
  }

  Future<void> deletePerson(String id) async {
    final db = await _db;
    await db.delete('people', where: 'id = ?', whereArgs: [id]);
  }

  /// Number of purchases that reference [personId] as a payer or in the split.
  Future<int> personUsageCount(String personId) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM (
        SELECT purchase_id FROM payers WHERE person_id = ?
        UNION
        SELECT purchase_id FROM splits WHERE person_id = ?
      )
    ''', [personId, personId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---- Purchases -------------------------------------------------------

  Future<List<Purchase>> getPurchases() async {
    final db = await _db;
    final purchaseRows =
        await db.query('purchases', orderBy: 'created_at DESC');
    final payerRows = await db.query('payers');
    final splitRows = await db.query('splits');

    List<Contribution> contributionsFor(
        List<Map<String, Object?>> rows, String purchaseId) {
      return rows
          .where((r) => r['purchase_id'] == purchaseId)
          .map((r) => Contribution(
                personId: r['person_id'] as String,
                amountCents: r['amount'] as int,
              ))
          .toList();
    }

    return purchaseRows.map((row) {
      final id = row['id'] as String;
      return Purchase.fromMap(
        row,
        payers: contributionsFor(payerRows, id),
        splits: contributionsFor(splitRows, id),
      );
    }).toList();
  }

  Future<void> savePurchase(Purchase purchase) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'purchases',
        purchase.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Replace child rows wholesale — simplest correct path for edits.
      await txn
          .delete('payers', where: 'purchase_id = ?', whereArgs: [purchase.id]);
      await txn
          .delete('splits', where: 'purchase_id = ?', whereArgs: [purchase.id]);

      for (final c in purchase.payers) {
        await txn.insert('payers', {
          'purchase_id': purchase.id,
          'person_id': c.personId,
          'amount': c.amountCents,
        });
      }
      for (final c in purchase.splits) {
        await txn.insert('splits', {
          'purchase_id': purchase.id,
          'person_id': c.personId,
          'amount': c.amountCents,
        });
      }
    });
  }

  Future<void> deletePurchase(String id) async {
    final db = await _db;
    await db.delete('purchases', where: 'id = ?', whereArgs: [id]);
  }
}
