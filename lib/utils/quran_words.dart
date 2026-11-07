import 'package:qcf_quran_plus/qcf_quran_plus.dart';

final RegExp _symbolOnlyWord = RegExp(
  r'^[\d٠-٩۩۞ۤ\u06D6-\u06DC\u06DE\u06E4\u06E9]+$',
);

/// Memecah teks ayat menjadi kata-kata logis dengan indeks yang sama seperti
/// yang dipakai `QuranSurahListView` pada callback `onWordTap`.
List<String> getAyahWords(int surah, int ayah) {
  final String text = getVerse(surah, ayah).replaceAll('\n', ' ').trim();
  return text
      .split(RegExp(r'\s+'))
      .where(
        (String word) => word.isNotEmpty && !_symbolOnlyWord.hasMatch(word),
      )
      .toList();
}
