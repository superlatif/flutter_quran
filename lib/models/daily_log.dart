/// Model untuk tabel `daily_logs` pada database lokal aplikasi Alquran.
///
/// Menyimpan titik akhir bacaan harian (SurahID + AyahID) per tanggal.
class DailyLog {
  final String date;
  final int surahId;
  final int ayahId;
  final DateTime? updatedAt;

  const DailyLog({
    required this.date,
    required this.surahId,
    required this.ayahId,
    this.updatedAt,
  });

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      date: (map['date'] as String?) ?? '',
      surahId: (map['surah_id'] as num?)?.toInt() ?? 0,
      ayahId: (map['ayah_id'] as num?)?.toInt() ?? 0,
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'surah_id': surahId,
      'ayah_id': ayahId,
      'updated_at':
          updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  DailyLog copyWith({
    String? date,
    int? surahId,
    int? ayahId,
    DateTime? updatedAt,
  }) {
    return DailyLog(
      date: date ?? this.date,
      surahId: surahId ?? this.surahId,
      ayahId: ayahId ?? this.ayahId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Apakah titik akhir bacaan hari ini merupakan khatam
  /// (penyelesaian dari Al-Fatihah sampai An-Nas ayat 6)?
  bool get isKhatam => surahId == 114 && ayahId == 6;

  /// Apakah hari ini belum memiliki log bacaan.
  bool get isEmpty => surahId == 0 && ayahId == 0;

  @override
  String toString() =>
      'DailyLog(date: $date, surahId: $surahId, ayahId: $ayahId)';
}
