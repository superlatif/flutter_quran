import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/bookmark_item.dart';
import '../models/bookmark_node.dart';
import '../models/ayah_comment.dart';
import '../models/ayah_translation.dart';
import '../models/daily_log.dart';

/// Service singleton untuk koneksi database lokal (SQLite) aplikasi Alquran.
///
/// Tabel:
/// - `daily_logs`      : log bacaan harian
/// - `bookmark_nodes`  : pohon hierarki bookmark (kategori -> sub-kategori -> ayat)
/// - `bookmark_items`  : ayat-ayat yang tersimpan dalam bookmark
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    final Database? existing = _database;
    if (existing != null) {
      return existing;
    }

    final String databasesPath = await getDatabasesPath();
    final Database db = await openDatabase(
      join(databasesPath, 'alquran.db'),
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    _database = db;
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE daily_logs (
        date TEXT PRIMARY KEY,
        surah_id INTEGER NOT NULL,
        ayah_id INTEGER NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmark_nodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER,
        name TEXT NOT NULL,
        depth INTEGER NOT NULL CHECK (depth IN (1, 2, 3))
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmark_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        node_id INTEGER NOT NULL,
        surah_id INTEGER NOT NULL,
        ayah_id INTEGER NOT NULL,
        page_number INTEGER NOT NULL,
        created_at TEXT,
        FOREIGN KEY (node_id) REFERENCES bookmark_nodes(id) ON DELETE CASCADE
      )
    ''');
    await _createUniqueBookmarkItemIndex(db);

    await _createAyahCommentsTable(db);
    await _createAyahTranslationsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAyahCommentsTable(db);
    }
    if (oldVersion < 3) {
      await _removeDuplicateBookmarkItems(db);
      await _createUniqueBookmarkItemIndex(db);
    }
    if (oldVersion < 4) {
      await _createAyahTranslationsTable(db);
    }
  }

  Future<void> _removeDuplicateBookmarkItems(DatabaseExecutor db) async {
    await db.execute('''
      DELETE FROM bookmark_items
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM bookmark_items
        GROUP BY node_id, surah_id, ayah_id
      )
    ''');
  }

  Future<void> _createUniqueBookmarkItemIndex(DatabaseExecutor db) async {
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_bookmark_items_unique_ayah
      ON bookmark_items (node_id, surah_id, ayah_id)
    ''');
  }

  Future<void> _createAyahCommentsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE ayah_comments (
        surah_id INTEGER NOT NULL,
        ayah_id INTEGER NOT NULL,
        comment TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (surah_id, ayah_id)
      )
    ''');
  }

  Future<void> _createAyahTranslationsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE ayah_translations (
        surah_id INTEGER NOT NULL,
        ayah_id INTEGER NOT NULL,
        translation TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (surah_id, ayah_id)
      )
    ''');
  }

  // ============================================================
  // Daily Logs
  // ============================================================

  Future<DailyLog?> getDailyLog(String date) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'daily_logs',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return DailyLog.fromMap(rows.first);
  }

  Future<DailyLog?> getTodaysLog() {
    return getDailyLog(_today());
  }

  String _today() {
    final DateTime now = DateTime.now();
    return _formatDate(now);
  }

  static String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-'
        '${twoDigits(date.month)}-${twoDigits(date.day)}';
  }

  Future<void> upsertDailyLog({
    required String date,
    required int surahId,
    required int ayahId,
  }) async {
    final Database db = await database;
    await db.insert('daily_logs', <String, dynamic>{
      'date': date,
      'surah_id': surahId,
      'ayah_id': ayahId,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DailyLog>> getDailyLogs() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'daily_logs',
      orderBy: 'date DESC',
    );

    return rows
        .map((Map<String, dynamic> row) => DailyLog.fromMap(row))
        .toList();
  }

  // ============================================================
  // Bookmark Nodes (Tree)
  // ============================================================

  Future<List<BookmarkNode>> getNodes() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'bookmark_nodes',
      orderBy: 'id ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => BookmarkNode.fromMap(row))
        .toList();
  }

  Future<List<BookmarkNode>> getChildren(int? parentId) async {
    final Database db = await database;

    if (parentId == null) {
      return getNodes();
    }

    final List<Map<String, dynamic>> rows = await db.query(
      'bookmark_nodes',
      where: 'parent_id IS ?',
      whereArgs: [parentId],
      orderBy: 'id ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => BookmarkNode.fromMap(row))
        .toList();
  }

  Future<BookmarkNode> createNode({
    int? parentId,
    required String name,
    required int depth,
  }) async {
    final Database db = await database;
    final int id = await db.insert('bookmark_nodes', <String, dynamic>{
      'parent_id': parentId,
      'name': name,
      'depth': depth,
    });

    return BookmarkNode(id: id, parentId: parentId, name: name, depth: depth);
  }

  Future<void> updateNode(int id, String name) async {
    final Database db = await database;
    await db.update(
      'bookmark_nodes',
      <String, dynamic>{'name': name},
      where: 'id = ?',
      whereArgs: <int>[id],
    );
  }

  Future<void> deleteNode(int id) async {
    final Database db = await database;
    await db.delete(
      'bookmark_nodes',
      where: 'id = ?',
      whereArgs: <int>[id],
      // Children first, then the node itself (tree structure).
    );

    await db.execute('DELETE FROM bookmark_items WHERE node_id = ?', <int>[id]);

    await db.execute('DELETE FROM bookmark_nodes WHERE parent_id = ?', <int>[
      id,
    ]);
  }

  // ============================================================
  // Bookmark Items (Ayat)
  // ============================================================

  Future<List<BookmarkItem>> getItemsByNode(int nodeId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'bookmark_items',
      where: 'node_id = ?',
      whereArgs: <int>[nodeId],
      orderBy: 'id ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => BookmarkItem.fromMap(row))
        .toList();
  }

  Future<List<BookmarkItem>> getAllItems() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'bookmark_items',
      orderBy: 'id ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => BookmarkItem.fromMap(row))
        .toList();
  }

  Future<bool> createItem({
    required int nodeId,
    required int surahId,
    required int ayahId,
    required int pageNumber,
  }) async {
    final Database db = await database;
    return db.transaction<bool>((Transaction transaction) async {
      final List<Map<String, Object?>> existingItems = await transaction.query(
        'bookmark_items',
        columns: <String>['id'],
        where: 'node_id = ? AND surah_id = ? AND ayah_id = ?',
        whereArgs: <int>[nodeId, surahId, ayahId],
        limit: 1,
      );
      if (existingItems.isNotEmpty) {
        return false;
      }

      await transaction.insert('bookmark_items', <String, dynamic>{
        'node_id': nodeId,
        'surah_id': surahId,
        'ayah_id': ayahId,
        'page_number': pageNumber,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    });
  }

  Future<void> deleteItem(int id) async {
    final Database db = await database;
    await db.delete('bookmark_items', where: 'id = ?', whereArgs: <int>[id]);
  }

  // ============================================================
  // Ayah Comments
  // ============================================================

  Future<AyahComment?> getAyahComment({
    required int surahId,
    required int ayahId,
  }) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'ayah_comments',
      where: 'surah_id = ? AND ayah_id = ?',
      whereArgs: <int>[surahId, ayahId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return AyahComment.fromMap(rows.first);
  }

  Future<void> upsertAyahComment({
    required int surahId,
    required int ayahId,
    required String comment,
  }) async {
    final Database db = await database;
    await db.insert('ayah_comments', <String, dynamic>{
      'surah_id': surahId,
      'ayah_id': ayahId,
      'comment': comment,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ============================================================
  // Ayah Translations
  // ============================================================

  Future<List<AyahTranslation>> getAyahTranslations({
    required int surahId,
  }) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'ayah_translations',
      where: 'surah_id = ?',
      whereArgs: <int>[surahId],
      orderBy: 'ayah_id ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => AyahTranslation.fromMap(row))
        .toList();
  }

  Future<void> upsertAyahTranslation({
    required int surahId,
    required int ayahId,
    required String translation,
  }) async {
    final Database db = await database;
    await db.insert('ayah_translations', <String, dynamic>{
      'surah_id': surahId,
      'ayah_id': ayahId,
      'translation': translation,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
