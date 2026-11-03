import 'package:flutter_test/flutter_test.dart';
import 'package:quran2/models/quran_page_info.dart';

void main() {
  test('setiap halaman memiliki nama surah dan juz', () {
    for (int page = 1; page <= 604; page++) {
      final QuranPageInfo info = QuranPageInfo.forPage(page);

      expect(info.surahNames, isNotEmpty, reason: 'Halaman $page');
      expect(info.surahLabel, startsWith('Surah '), reason: 'Halaman $page');
      expect(info.juzLabel, isNotEmpty, reason: 'Halaman $page');
      expect(info.label, contains(' • Juz '), reason: 'Halaman $page');
    }
  });

  test('halaman pertama menampilkan Al Fatiha dan Juz 1', () {
    final QuranPageInfo info = QuranPageInfo.forPage(1);

    expect(info.surahNames, <String>['Al Fatiha']);
    expect(info.juzLabel, 'Juz 1');
    expect(info.label, 'Surah Al Fatiha • Juz 1');
  });

  test('halaman yang memuat beberapa surah menampilkan semuanya', () {
    final QuranPageInfo info = QuranPageInfo.forPage(604);

    expect(info.surahNames, <String>['Al Ikhlaas', 'Al Falaq', 'An Naas']);
    expect(info.juzLabel, 'Juz 30');
  });

  test('halaman yang melewati batas juz menampilkan rentang juz', () {
    final QuranPageInfo info =
        <QuranPageInfo>[
          for (int page = 1; page <= 604; page++) QuranPageInfo.forPage(page),
        ].firstWhere(
          (QuranPageInfo pageInfo) =>
              pageInfo.juzStart != null &&
              pageInfo.juzEnd != null &&
              pageInfo.juzStart != pageInfo.juzEnd,
        );

    expect(info.juzLabel, 'Juz ${info.juzStart}–${info.juzEnd}');
  });
}
