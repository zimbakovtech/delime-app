import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single SQLite connection and the schema.
class AppDatabase {
  /// [path] overrides the on-disk location — used by tests to point at an
  /// in-memory database. Production code uses [instance], which stores the
  /// database in the platform's default databases directory.
  AppDatabase({String? path}) : _overridePath = path;

  static final AppDatabase instance = AppDatabase();

  static const _dbName = 'delime.db';
  static const _dbVersion = 1;

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
    );
  }

  /// Closes the underlying connection. Mainly useful for tests.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onCreate(Database db, int version) async {
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
}
