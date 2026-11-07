/// Jenis catatan yang dapat dilampirkan pada sebuah ayat.
enum VerseNoteType {
  explanation('explanation', 'Penjelasan'),
  hadis('hadis', 'Hadis'),
  general('general', 'Umum');

  const VerseNoteType(this.value, this.label);

  final String value;
  final String label;

  static VerseNoteType fromValue(String? value) {
    return VerseNoteType.values.firstWhere(
      (VerseNoteType type) => type.value == value,
      orElse: () => VerseNoteType.general,
    );
  }
}

/// Catatan per ayat yang mendukung teks Pegon dan Latin.
class VerseNote {
  const VerseNote({
    this.id,
    required this.surah,
    required this.ayah,
    required this.noteType,
    this.contentPegon,
    this.contentLatin,
    this.reference,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final int surah;
  final int ayah;
  final VerseNoteType noteType;
  final String? contentPegon;
  final String? contentLatin;
  final String? reference;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasContent =>
      (contentPegon != null && contentPegon!.trim().isNotEmpty) ||
      (contentLatin != null && contentLatin!.trim().isNotEmpty);

  VerseNote copyWith({
    int? id,
    int? surah,
    int? ayah,
    VerseNoteType? noteType,
    String? contentPegon,
    String? contentLatin,
    String? reference,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VerseNote(
      id: id ?? this.id,
      surah: surah ?? this.surah,
      ayah: ayah ?? this.ayah,
      noteType: noteType ?? this.noteType,
      contentPegon: contentPegon ?? this.contentPegon,
      contentLatin: contentLatin ?? this.contentLatin,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory VerseNote.fromMap(Map<String, dynamic> map) {
    return VerseNote(
      id: (map['id'] as num?)?.toInt(),
      surah: (map['surah'] as num).toInt(),
      ayah: (map['ayah'] as num).toInt(),
      noteType: VerseNoteType.fromValue(map['note_type'] as String?),
      contentPegon: map['content_pegon'] as String?,
      contentLatin: map['content_latin'] as String?,
      reference: map['reference'] as String?,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'surah': surah,
      'ayah': ayah,
      'note_type': noteType.value,
      'content_pegon': contentPegon,
      'content_latin': contentLatin,
      'reference': reference,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toExportMap() {
    return <String, dynamic>{
      'surah': surah,
      'ayah': ayah,
      'note_type': noteType.value,
      'content_pegon': contentPegon,
      'content_latin': contentLatin,
      'reference': reference,
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
