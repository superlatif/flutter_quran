/// Model untuk tabel `bookmark_nodes` (struktur pohon bookmark, hingga 3 kedalaman).
class BookmarkNode {
  final int id;
  final int? parentId;
  final String name;
  final int depth;

  const BookmarkNode({
    required this.id,
    required this.parentId,
    required this.name,
    required this.depth,
  });

  factory BookmarkNode.fromMap(Map<String, dynamic> map) {
    return BookmarkNode(
      id: (map['id'] as num?)?.toInt() ?? 0,
      parentId: (map['parent_id'] as num?)?.toInt(),
      name: (map['name'] as String?) ?? '',
      depth: (map['depth'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'parent_id': parentId, 'name': name, 'depth': depth};
  }

  BookmarkNode copyWith({String? name, int? depth}) {
    return BookmarkNode(
      id: id,
      parentId: parentId,
      name: name ?? this.name,
      depth: depth ?? this.depth,
    );
  }

  @override
  String toString() =>
      'BookmarkNode(id: $id, parentId: $parentId, name: $name, depth: $depth)';
}
