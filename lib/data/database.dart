import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single SQLite connection and the schema.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'delime.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
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
