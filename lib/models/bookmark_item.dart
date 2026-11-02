/// Model untuk tabel `bookmark_items` (detail ayat pada suatu bookmark node).
class BookmarkItem {
  final int id;
  final int nodeId;
  final int surahId;
  final int ayahId;
  final int pageNumber;
  final DateTime createdAt;

  const BookmarkItem({
    required this.id,
    required this.nodeId,
    required this.surahId,
    required this.ayahId,
    required this.pageNumber,
    required this.createdAt,
  });

  factory BookmarkItem.fromMap(Map<String, dynamic> map) {
    return BookmarkItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      nodeId: (map['node_id'] as num?)?.toInt() ?? 0,
      surahId: (map['surah_id'] as num?)?.toInt() ?? 0,
      ayahId: (map['ayah_id'] as num?)?.toInt() ?? 0,
      pageNumber: (map['page_number'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'node_id': nodeId,
      'surah_id': surahId,
      'ayah_id': ayahId,
      'page_number': pageNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'BookmarkItem(id: $id, nodeId: $nodeId, surahId: $surahId, ayahId: $ayahId)';

  String get surahName => 'Surah $surahId';
  String get ayahLabel => 'Ayat $ayahId';
}
