import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/bookmark_item.dart';
import '../models/bookmark_node.dart';
import '../models/ayah_comment.dart';
import '../models/ayah_translation.dart';
import '../models/daily_log.dart';
import '../models/verse_note.dart';
import '../models/word_meaning.dart';

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
      version: 5,
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
    await _createWordMeaningsTable(db);
    await _createVerseNotesTable(db);
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
    if (oldVersion < 5) {
      await _createWordMeaningsTable(db);
      await _createVerseNotesTable(db);
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

  Future<void> _createWordMeaningsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_word_meanings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah INTEGER NOT NULL,
        ayah INTEGER NOT NULL,
        word_index INTEGER NOT NULL,
        group_id TEXT,
        words_joined TEXT,
        meaning_pegon TEXT,
        meaning_latin TEXT,
        source_type TEXT NOT NULL DEFAULT 'user',
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_user_word_meanings_word
      ON user_word_meanings (surah, ayah, word_index)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_user_word_meanings_group
      ON user_word_meanings (group_id)
    ''');
  }

  Future<void> _createVerseNotesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_verse_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah INTEGER NOT NULL,
        ayah INTEGER NOT NULL,
        note_type TEXT NOT NULL CHECK(note_type IN ('explanation', 'hadis', 'general')),
        content_pegon TEXT,
        content_latin TEXT,
        reference TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_user_verse_notes_ayah
      ON user_verse_notes (surah, ayah)
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

  // ============================================================
  // Word Meanings (Makna Gandul)
  // ============================================================

  Future<List<WordMeaning>> getWordMeanings({
    required int surah,
    required int ayah,
  }) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'user_word_meanings',
      where: 'surah = ? AND ayah = ?',
      whereArgs: <int>[surah, ayah],
      orderBy: 'word_index ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => WordMeaning.fromMap(row))
        .toList();
  }

  Future<List<WordMeaning>> getWordMeaningsForSurah(int surah) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'user_word_meanings',
      where: 'surah = ?',
      whereArgs: <int>[surah],
      orderBy: 'ayah ASC, word_index ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => WordMeaning.fromMap(row))
        .toList();
  }

  Future<List<WordMeaning>> getAllWordMeanings() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'user_word_meanings',
      orderBy: 'surah ASC, ayah ASC, word_index ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => WordMeaning.fromMap(row))
        .toList();
  }

  /// Menyimpan makna satu kata tanpa mengubah status penggabungannya.
  Future<void> saveWordMeaning({
    required int surah,
    required int ayah,
    required int wordIndex,
    String? meaningPegon,
    String? meaningLatin,
    String sourceType = 'user',
  }) async {
    final Database db = await database;
    final String now = DateTime.now().toIso8601String();
    final List<Map<String, Object?>> existing = await db.query(
      'user_word_meanings',
      where: 'surah = ? AND ayah = ? AND word_index = ?',
      whereArgs: <int>[surah, ayah, wordIndex],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('user_word_meanings', <String, dynamic>{
        'surah': surah,
        'ayah': ayah,
        'word_index': wordIndex,
        'meaning_pegon': meaningPegon,
        'meaning_latin': meaningLatin,
        'source_type': sourceType,
        'created_at': now,
        'updated_at': now,
      });
      return;
    }

    await db.update(
      'user_word_meanings',
      <String, dynamic>{
        'meaning_pegon': meaningPegon,
        'meaning_latin': meaningLatin,
        'source_type': sourceType,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: <Object?>[existing.first['id']],
    );
  }

  Future<void> deleteWordMeaning({
    required int surah,
    required int ayah,
    required int wordIndex,
  }) async {
    final Database db = await database;
    await db.delete(
      'user_word_meanings',
      where: 'surah = ? AND ayah = ? AND word_index = ?',
      whereArgs: <int>[surah, ayah, wordIndex],
    );
  }

  /// Menggabungkan beberapa kata berurutan menjadi satu makna.
  ///
  /// Seluruh kata yang tergabung mendapat [WordMeaning.groupId] yang sama.
  /// Hanya baris kata pertama yang menyimpan [WordMeaning.wordsJoined] dan
  /// makna gabungan; baris lainnya menjadi penanda keanggotaan grup.
  Future<void> saveGroupedMeaning({
    required int surah,
    required int ayah,
    required List<int> wordIndices,
    String? meaningPegon,
    String? meaningLatin,
  }) async {
    final List<int> sortedIndices = <int>[...wordIndices]..sort();
    if (sortedIndices.length < 2) {
      throw ArgumentError('Makna gabungan membutuhkan minimal 2 kata.');
    }

    final Database db = await database;
    final String groupId = _generateGroupId();
    final String now = DateTime.now().toIso8601String();

    await db.transaction<void>((Transaction txn) async {
      // Lepaskan grup lama yang melibatkan salah satu kata terpilih agar tidak
      // menyisakan baris grup tanpa pemilik.
      for (final int wordIndex in sortedIndices) {
        final List<Map<String, Object?>> rows = await txn.query(
          'user_word_meanings',
          columns: <String>['group_id'],
          where: 'surah = ? AND ayah = ? AND word_index = ?',
          whereArgs: <int>[surah, ayah, wordIndex],
          limit: 1,
        );
        final String? oldGroupId = rows.isEmpty
            ? null
            : rows.first['group_id'] as String?;
        if (oldGroupId != null && oldGroupId.isNotEmpty) {
          await txn.update(
            'user_word_meanings',
            <String, dynamic>{'group_id': null, 'words_joined': null},
            where: 'surah = ? AND ayah = ? AND group_id = ?',
            whereArgs: <Object?>[surah, ayah, oldGroupId],
          );
        }
      }

      for (int i = 0; i < sortedIndices.length; i++) {
        final int wordIndex = sortedIndices[i];
        final bool isPrimary = i == 0;
        final Map<String, dynamic> values = <String, dynamic>{
          'group_id': groupId,
          'words_joined': isPrimary ? sortedIndices.join(',') : null,
          'meaning_pegon': isPrimary ? meaningPegon : null,
          'meaning_latin': isPrimary ? meaningLatin : null,
          'source_type': 'user',
          'updated_at': now,
        };

        final List<Map<String, Object?>> existing = await txn.query(
          'user_word_meanings',
          columns: <String>['id'],
          where: 'surah = ? AND ayah = ? AND word_index = ?',
          whereArgs: <int>[surah, ayah, wordIndex],
          limit: 1,
        );

        if (existing.isEmpty) {
          await txn.insert('user_word_meanings', <String, dynamic>{
            'surah': surah,
            'ayah': ayah,
            'word_index': wordIndex,
            'created_at': now,
            ...values,
          });
        } else {
          await txn.update(
            'user_word_meanings',
            values,
            where: 'id = ?',
            whereArgs: <Object?>[existing.first['id']],
          );
        }
      }
    });
  }

  /// Memisahkan makna gabungan kembali menjadi makna per kata.
  Future<void> ungroupMeaning({
    required int surah,
    required int ayah,
    required String groupId,
  }) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'user_word_meanings',
      where: 'surah = ? AND ayah = ? AND group_id = ?',
      whereArgs: <Object?>[surah, ayah, groupId],
      orderBy: 'word_index ASC',
    );
    if (rows.isEmpty) {
      return;
    }

    await db.transaction<void>((Transaction txn) async {
      await txn.update(
        'user_word_meanings',
        <String, dynamic>{'group_id': null, 'words_joined': null},
        where: 'surah = ? AND ayah = ? AND group_id = ?',
        whereArgs: <Object?>[surah, ayah, groupId],
      );
    });
  }

  /// Upsert untuk impor JSON berdasarkan kunci alami (surah, ayah, kata).
  Future<void> importWordMeaning(WordMeaning meaning) async {
    final Database db = await database;
    final String now = DateTime.now().toIso8601String();
    final List<Map<String, Object?>> existing = await db.query(
      'user_word_meanings',
      columns: <String>['id'],
      where: 'surah = ? AND ayah = ? AND word_index = ?',
      whereArgs: <int>[meaning.surah, meaning.ayah, meaning.wordIndex],
      limit: 1,
    );

    final Map<String, dynamic> values = <String, dynamic>{
      'surah': meaning.surah,
      'ayah': meaning.ayah,
      'word_index': meaning.wordIndex,
      'group_id': meaning.groupId,
      'words_joined': meaning.wordsJoined,
      'meaning_pegon': meaning.meaningPegon,
      'meaning_latin': meaning.meaningLatin,
      'source_type': meaning.sourceType,
      'updated_at': now,
    };

    if (existing.isEmpty) {
      await db.insert('user_word_meanings', <String, dynamic>{
        ...values,
        'created_at': meaning.createdAt?.toIso8601String() ?? now,
      });
    } else {
      await db.update(
        'user_word_meanings',
        values,
        where: 'id = ?',
        whereArgs: <Object?>[existing.first['id']],
      );
    }
  }

  String _generateGroupId() {
    final Random random = Random();
    final int randomPart = random.nextInt(0x7fffffff);
    return 'grp_${DateTime.now().microsecondsSinceEpoch}_$randomPart';
  }

  // ============================================================
  // Verse Notes (Catatan Ayat)
  // ============================================================

  Future<List<VerseNote>> getVerseNotes({
    required int surah,
    required int ayah,
  }) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'user_verse_notes',
      where: 'surah = ? AND ayah = ?',
      whereArgs: <int>[surah, ayah],
      orderBy: 'id ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => VerseNote.fromMap(row))
        .toList();
  }

  Future<List<VerseNote>> getVerseNotesForSurah(int surah) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'user_verse_notes',
      where: 'surah = ?',
      whereArgs: <int>[surah],
      orderBy: 'ayah ASC, id ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => VerseNote.fromMap(row))
        .toList();
  }

  Future<List<VerseNote>> getAllVerseNotes() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'user_verse_notes',
      orderBy: 'surah ASC, ayah ASC, id ASC',
    );

    return rows
        .map((Map<String, dynamic> row) => VerseNote.fromMap(row))
        .toList();
  }

  Future<int> saveVerseNote(VerseNote note) async {
    final Database db = await database;
    final String now = DateTime.now().toIso8601String();
    final int? noteId = note.id;

    if (noteId == null) {
      return db.insert('user_verse_notes', <String, dynamic>{
        'surah': note.surah,
        'ayah': note.ayah,
        'note_type': note.noteType.value,
        'content_pegon': note.contentPegon,
        'content_latin': note.contentLatin,
        'reference': note.reference,
        'created_at': note.createdAt?.toIso8601String() ?? now,
        'updated_at': now,
      });
    }

    await db.update(
      'user_verse_notes',
      <String, dynamic>{
        'note_type': note.noteType.value,
        'content_pegon': note.contentPegon,
        'content_latin': note.contentLatin,
        'reference': note.reference,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: <int>[noteId],
    );
    return noteId;
  }

  Future<void> deleteVerseNote(int id) async {
    final Database db = await database;
    await db.delete('user_verse_notes', where: 'id = ?', whereArgs: <int>[id]);
  }

  /// Menambahkan catatan hasil impor tanpa menimpa catatan lokal yang sudah
  /// ada. Duplikat persis akan dilewati.
  Future<bool> importVerseNote(VerseNote note) async {
    final Database db = await database;
    final String now = DateTime.now().toIso8601String();
    final List<Map<String, Object?>> duplicates = await db.query(
      'user_verse_notes',
      columns: <String>['id'],
      where:
          'surah = ? AND ayah = ? AND note_type = ? AND '
          'COALESCE(content_pegon, \'\') = ? AND '
          'COALESCE(content_latin, \'\') = ? AND '
          'COALESCE(reference, \'\') = ?',
      whereArgs: <Object?>[
        note.surah,
        note.ayah,
        note.noteType.value,
        note.contentPegon ?? '',
        note.contentLatin ?? '',
        note.reference ?? '',
      ],
      limit: 1,
    );
    if (duplicates.isNotEmpty) {
      return false;
    }

    await db.insert('user_verse_notes', <String, dynamic>{
      'surah': note.surah,
      'ayah': note.ayah,
      'note_type': note.noteType.value,
      'content_pegon': note.contentPegon,
      'content_latin': note.contentLatin,
      'reference': note.reference,
      'created_at': note.createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    });
    return true;
  }
}
