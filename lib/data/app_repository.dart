import 'package:delime/data/database.dart';
import 'package:delime/models/attachment.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:delime/models/settlement_record.dart';
import 'package:delime/models/trip.dart';
import 'package:sqflite/sqflite.dart';

/// Data-access layer. All persistence goes through here; the rest of the app
/// never touches SQL directly. People, purchases, settlements and attachments
/// are scoped to a trip.
class AppRepository {
  AppRepository(this._dbProvider);

  final AppDatabase _dbProvider;

  Future<Database> get _db => _dbProvider.database;

  // ---- Trips -----------------------------------------------------------

  Future<List<Trip>> getTrips() async {
    final db = await _db;
    final rows = await db.query('trips', orderBy: 'updated_at DESC');
    return rows.map(Trip.fromMap).toList();
  }

  Future<void> insertTrip(Trip trip) async {
    final db = await _db;
    await db.insert('trips', trip.toMap());
  }

  Future<void> updateTrip(Trip trip) async {
    final db = await _db;
    await db.update(
      'trips',
      trip.toMap(),
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }

  /// Deletes a trip and everything that belongs to it (people, purchases,
  /// payers/splits, settlements, attachment rows) via cascading foreign keys.
  Future<void> deleteTrip(String id) async {
    final db = await _db;
    await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  // ---- People ----------------------------------------------------------

  Future<List<Person>> getPeople(String tripId) async {
    final db = await _db;
    final rows = await db.query(
      'people',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Person.fromMap).toList();
  }

  Future<void> insertPerson(Person person, String tripId) async {
    final db = await _db;
    await db.insert('people', {...person.toMap(), 'trip_id': tripId});
  }

  Future<void> updatePerson(Person person) async {
    final db = await _db;
    await db.update(
      'people',
      person.toMap(),
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  Future<void> deletePerson(String id) async {
    final db = await _db;
    await db.delete('people', where: 'id = ?', whereArgs: [id]);
  }

  /// Number of purchases that reference [personId] as a payer or in the split.
  Future<int> personUsageCount(String personId) async {
    final db = await _db;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c FROM (
        SELECT purchase_id FROM payers WHERE person_id = ?
        UNION
        SELECT purchase_id FROM splits WHERE person_id = ?
      )
    ''',
      [personId, personId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---- Purchases -------------------------------------------------------

  Future<List<Purchase>> getPurchases(String tripId) async {
    final db = await _db;
    final purchaseRows = await db.query(
      'purchases',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'created_at DESC',
    );
    final ids = purchaseRows.map((r) => r['id'] as String).toSet();
    final payerRows = await db.query('payers');
    final splitRows = await db.query('splits');

    List<Contribution> contributionsFor(
      List<Map<String, Object?>> rows,
      String purchaseId,
    ) {
      return rows
          .where((r) => r['purchase_id'] == purchaseId)
          .map(
            (r) => Contribution(
              personId: r['person_id'] as String,
              amountCents: r['amount'] as int,
            ),
          )
          .toList();
    }

    return purchaseRows.where((row) => ids.contains(row['id'])).map((row) {
      final id = row['id'] as String;
      return Purchase.fromMap(
        row,
        payers: contributionsFor(payerRows, id),
        splits: contributionsFor(splitRows, id),
      );
    }).toList();
  }

  Future<void> savePurchase(Purchase purchase, String tripId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('purchases', {
        ...purchase.toMap(),
        'trip_id': tripId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      // Replace child rows wholesale — simplest correct path for edits.
      await txn.delete(
        'payers',
        where: 'purchase_id = ?',
        whereArgs: [purchase.id],
      );
      await txn.delete(
        'splits',
        where: 'purchase_id = ?',
        whereArgs: [purchase.id],
      );

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

  // ---- Settlements -----------------------------------------------------

  Future<List<SettlementRecord>> getSettlements(String tripId) async {
    final db = await _db;
    final rows = await db.query(
      'settlements',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'settled_at DESC',
    );
    return rows.map(SettlementRecord.fromMap).toList();
  }

  Future<void> insertSettlement(SettlementRecord record) async {
    final db = await _db;
    await db.insert('settlements', record.toMap());
  }

  Future<void> deleteSettlement(String id) async {
    final db = await _db;
    await db.delete('settlements', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Attachments -----------------------------------------------------

  /// All receipt attachments for purchases in [tripId].
  Future<List<Attachment>> getAttachments(String tripId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT a.* FROM attachments a
      JOIN purchases p ON p.id = a.purchase_id
      WHERE p.trip_id = ?
      ORDER BY a.created_at ASC
    ''',
      [tripId],
    );
    return rows.map(Attachment.fromMap).toList();
  }

  Future<List<Attachment>> getAttachmentsForPurchase(String purchaseId) async {
    final db = await _db;
    final rows = await db.query(
      'attachments',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  Future<void> insertAttachment(Attachment attachment) async {
    final db = await _db;
    await db.insert('attachments', attachment.toMap());
  }

  Future<void> deleteAttachment(String id) async {
    final db = await _db;
    await db.delete('attachments', where: 'id = ?', whereArgs: [id]);
  }
}
