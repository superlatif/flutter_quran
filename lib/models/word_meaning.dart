/// Makna per kata untuk satu ayat.
///
/// Satu baris merepresentasikan satu kata. Ketika beberapa kata digabung
/// (misalnya mudhof + mudhof ilaih), semua baris kata tersebut memiliki
/// [groupId] yang sama dan baris pertama menyimpan [wordsJoined] beserta
/// makna gabungannya.
class WordMeaning {
  const WordMeaning({
    this.id,
    required this.surah,
    required this.ayah,
    required this.wordIndex,
    this.groupId,
    this.wordsJoined,
    this.meaningPegon,
    this.meaningLatin,
    this.sourceType = 'user',
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final int surah;
  final int ayah;
  final int wordIndex;
  final String? groupId;
  final String? wordsJoined;
  final String? meaningPegon;
  final String? meaningLatin;
  final String sourceType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isGroupPrimary =>
      groupId != null && wordsJoined != null && wordsJoined!.isNotEmpty;

  bool get isGrouped => groupId != null;

  bool get hasMeaning =>
      (meaningPegon != null && meaningPegon!.trim().isNotEmpty) ||
      (meaningLatin != null && meaningLatin!.trim().isNotEmpty);

  List<int> get joinedWordIndices {
    final String? joined = wordsJoined;
    if (joined == null || joined.isEmpty) {
      return <int>[wordIndex];
    }
    return joined
        .split(',')
        .map((String value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toList()
      ..sort();
  }

  WordMeaning copyWith({
    int? id,
    int? surah,
    int? ayah,
    int? wordIndex,
    String? groupId,
    bool clearGroupId = false,
    String? wordsJoined,
    bool clearWordsJoined = false,
    String? meaningPegon,
    String? meaningLatin,
    String? sourceType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WordMeaning(
      id: id ?? this.id,
      surah: surah ?? this.surah,
      ayah: ayah ?? this.ayah,
      wordIndex: wordIndex ?? this.wordIndex,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      wordsJoined: clearWordsJoined ? null : (wordsJoined ?? this.wordsJoined),
      meaningPegon: meaningPegon ?? this.meaningPegon,
      meaningLatin: meaningLatin ?? this.meaningLatin,
      sourceType: sourceType ?? this.sourceType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WordMeaning.fromMap(Map<String, dynamic> map) {
    return WordMeaning(
      id: (map['id'] as num?)?.toInt(),
      surah: (map['surah'] as num).toInt(),
      ayah: (map['ayah'] as num).toInt(),
      wordIndex: (map['word_index'] as num).toInt(),
      groupId: map['group_id'] as String?,
      wordsJoined: map['words_joined'] as String?,
      meaningPegon: map['meaning_pegon'] as String?,
      meaningLatin: map['meaning_latin'] as String?,
      sourceType: (map['source_type'] as String?) ?? 'user',
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'surah': surah,
      'ayah': ayah,
      'word_index': wordIndex,
      'group_id': groupId,
      'words_joined': wordsJoined,
      'meaning_pegon': meaningPegon,
      'meaning_latin': meaningLatin,
      'source_type': sourceType,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Dipakai saat impor JSON: id lokal tidak dipertahankan agar tidak
  /// bertabrakan dengan data yang sudah ada.
  Map<String, dynamic> toExportMap() {
    return <String, dynamic>{
      'surah': surah,
      'ayah': ayah,
      'word_index': wordIndex,
      'group_id': groupId,
      'words_joined': wordsJoined,
      'meaning_pegon': meaningPegon,
      'meaning_latin': meaningLatin,
      'source_type': sourceType,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
