import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Owns the single SQLite connection and the schema.
class AppDatabase {
  /// [path] overrides the on-disk location — used by tests to point at an
  /// in-memory database. Production code uses [instance], which stores the
  /// database in the platform's default databases directory.
  AppDatabase({String? path}) : _overridePath = path;

  static final AppDatabase instance = AppDatabase();

  static const _dbName = 'delime.db';
  static const _dbVersion = 2;
  static const _uuid = Uuid();

  /// Name given to the trip auto-created when migrating a pre-trips database.
  @visibleForTesting
  static const defaultTripName = 'My Trip';

  final String? _overridePath;
  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final path = _overridePath ?? p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Closes the underlying connection. Mainly useful for tests.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ---- Fresh install (v2 schema) ---------------------------------------

  Future<void> _onCreate(Database db, int version) async {
    await _createTrips(db);

    await db.execute('''
      CREATE TABLE people (
        id      TEXT PRIMARY KEY,
        name    TEXT NOT NULL,
        color   INTEGER NOT NULL,
        trip_id TEXT NOT NULL REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE purchases (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        total      INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        category   TEXT NOT NULL DEFAULT 'Other',
        trip_id    TEXT NOT NULL REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await _createPayersAndSplits(db);
    await _createSettlements(db);
    await _createAttachments(db);
  }

  // ---- Migrations (forward-only, lossless) -----------------------------

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrateV1ToV2(db);
    }
  }

  /// Turns the single implicit ledger into a multi-trip schema. Every existing
  /// person and purchase is moved into one auto-created default trip — no data
  /// is dropped or altered beyond gaining a [trip_id].
  Future<void> _migrateV1ToV2(Database db) async {
    await _createTrips(db);

    final tripId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('trips', {
      'id': tripId,
      'name': defaultTripName,
      'type': 'other',
      'base_currency': 'EUR',
      'start_date': null,
      'end_date': null,
      'cover_color': _defaultCoverColor,
      'cover_photo_path': null,
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    });

    // SQLite permits ALTER TABLE ADD COLUMN to introduce a foreign key only
    // when the new column defaults to NULL; we add it, then backfill.
    await db.execute(
      'ALTER TABLE people ADD COLUMN trip_id TEXT '
      'REFERENCES trips (id) ON DELETE CASCADE',
    );
    await db.update('people', {'trip_id': tripId});

    await db.execute(
      'ALTER TABLE purchases ADD COLUMN trip_id TEXT '
      'REFERENCES trips (id) ON DELETE CASCADE',
    );
    await db.execute(
      "ALTER TABLE purchases ADD COLUMN category TEXT NOT NULL DEFAULT 'Other'",
    );
    await db.update('purchases', {'trip_id': tripId});

    await _createSettlements(db);
    await _createAttachments(db);
  }

  // ---- Shared DDL ------------------------------------------------------

  /// Teal from the avatar palette — a sensible default trip cover colour.
  static const int _defaultCoverColor = 0xFF34D399;

  Future<void> _createTrips(Database db) async {
    await db.execute('''
      CREATE TABLE trips (
        id               TEXT PRIMARY KEY,
        name             TEXT NOT NULL,
        type             TEXT NOT NULL,
        base_currency    TEXT NOT NULL DEFAULT 'EUR',
        start_date       INTEGER,
        end_date         INTEGER,
        cover_color      INTEGER NOT NULL,
        cover_photo_path TEXT,
        status           TEXT NOT NULL DEFAULT 'active',
        created_at       INTEGER NOT NULL,
        updated_at       INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createPayersAndSplits(Database db) async {
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

  Future<void> _createSettlements(Database db) async {
    await db.execute('''
      CREATE TABLE settlements (
        id          TEXT PRIMARY KEY,
        trip_id     TEXT NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
        from_person TEXT NOT NULL,
        to_person   TEXT NOT NULL,
        amount      INTEGER NOT NULL,
        note        TEXT,
        settled_at  INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createAttachments(Database db) async {
    await db.execute('''
      CREATE TABLE attachments (
        id          TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL REFERENCES purchases (id) ON DELETE CASCADE,
        file_path   TEXT NOT NULL,
        created_at  INTEGER NOT NULL
      )
    ''');
  }
}
