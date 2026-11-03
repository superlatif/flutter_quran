import 'package:qcf_quran_plus/qcf_quran_plus.dart';

/// Informasi surah dan juz yang ditampilkan pada header setiap lembar Mushaf.
class QuranPageInfo {
  const QuranPageInfo({
    required this.pageNumber,
    required this.surahNames,
    this.surahIds = const <int>[],
    this.juzStart,
    this.juzEnd,
  });

  /// Nomor halaman Mushaf (1–604).
  final int pageNumber;

  /// Nama surah yang muncul pada halaman ini, berurutan.
  final List<String> surahNames;

  /// Nomor surah yang muncul pada halaman ini, berurutan.
  final List<int> surahIds;

  /// Juz awal halaman, atau `null` jika tidak dapat ditentukan.
  final int? juzStart;

  /// Juz akhir halaman, atau `null` jika tidak dapat ditentukan.
  final int? juzEnd;

  /// Nomor surah pertama pada halaman ini, dipakai sebagai surah aktif.
  int? get primarySurahId => surahIds.isEmpty ? null : surahIds.first;

  String get surahLabel {
    if (surahNames.isEmpty) {
      return 'Surah tidak diketahui';
    }
    return 'Surah ${surahNames.join(', ')}';
  }

  String get juzLabel {
    final int? start = juzStart ?? juzEnd;
    final int? end = juzEnd ?? juzStart;
    if (start == null || end == null) {
      return '';
    }
    if (start == end) {
      return 'Juz $start';
    }
    return 'Juz $start–$end';
  }

  /// Label siap tampil, misalnya `Surah Al Fatiha • Juz 1`.
  String get label {
    final String juz = juzLabel;
    return juz.isEmpty ? surahLabel : '$surahLabel • $juz';
  }

  /// Membuat informasi halaman dari data Mushaf bawaan paket.
  factory QuranPageInfo.forPage(int pageNumber) {
    final List<dynamic> sections = getPageData(pageNumber);

    final List<int> surahIds = <int>[];
    for (final dynamic raw in sections) {
      final Map<dynamic, dynamic> section = raw as Map<dynamic, dynamic>;
      final int? surahId = (section['surah'] as num?)?.toInt();
      if (surahId != null && !surahIds.contains(surahId)) {
        surahIds.add(surahId);
      }
    }

    int? juzStart;
    int? juzEnd;
    if (sections.isNotEmpty) {
      final Map<dynamic, dynamic> first =
          sections.first as Map<dynamic, dynamic>;
      final Map<dynamic, dynamic> last = sections.last as Map<dynamic, dynamic>;

      final int firstSurah = (first['surah'] as num).toInt();
      final int firstAyah = (first['start'] as num).toInt();
      final int lastSurah = (last['surah'] as num).toInt();
      final int lastAyah = (last['end'] as num).toInt();

      final int start = getJuzNumber(firstSurah, firstAyah);
      final int end = getJuzNumber(lastSurah, lastAyah);
      juzStart = start > 0 ? start : null;
      juzEnd = end > 0 ? end : null;
    }

    return QuranPageInfo(
      pageNumber: pageNumber,
      surahIds: surahIds,
      surahNames: surahIds
          .map((int surahId) => getSurahName(surahId))
          .toList(growable: false),
      juzStart: juzStart,
      juzEnd: juzEnd,
    );
  }
}
