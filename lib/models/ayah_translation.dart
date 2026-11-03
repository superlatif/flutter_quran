class AyahTranslation {
  final int surahId;
  final int ayahId;
  final String translation;
  final DateTime updatedAt;

  const AyahTranslation({
    required this.surahId,
    required this.ayahId,
    required this.translation,
    required this.updatedAt,
  });

  factory AyahTranslation.fromMap(Map<String, dynamic> map) {
    return AyahTranslation(
      surahId: (map['surah_id'] as num).toInt(),
      ayahId: (map['ayah_id'] as num).toInt(),
      translation: map['translation'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
