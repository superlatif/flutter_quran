class AyahComment {
  final int surahId;
  final int ayahId;
  final String comment;
  final DateTime updatedAt;

  const AyahComment({
    required this.surahId,
    required this.ayahId,
    required this.comment,
    required this.updatedAt,
  });

  factory AyahComment.fromMap(Map<String, dynamic> map) {
    return AyahComment(
      surahId: (map['surah_id'] as num).toInt(),
      ayahId: (map['ayah_id'] as num).toInt(),
      comment: map['comment'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
