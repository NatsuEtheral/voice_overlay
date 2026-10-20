import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/note.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'offline_notes.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            audioPath TEXT,
            tags TEXT,
            isPinned INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final maps = await db.query(
      'notes',
      orderBy: 'isPinned DESC, updatedAt DESC',
    );
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> searchNotes(String query) async {
    final db = await database;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getAllNotes();

    final maps = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ?',
      whereArgs: ['%$trimmed%', '%$trimmed%', '%$trimmed%'],
      orderBy: 'isPinned DESC, updatedAt DESC',
    );
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<void> insertNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> togglePin(String id, bool isPinned) async {
    final db = await database;
    await db.update(
      'notes',
      {'isPinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
