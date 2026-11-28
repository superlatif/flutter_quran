// ignore: implementation_imports
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran2/services/ayah_text_formatter.dart';

bool _hasPrivateUseGlyph(String text) =>
    text.runes.any((r) => r >= 0xE000 && r <= 0xF8FF);

void main() {
  test('menyalin ayat memakai teks Arab Unicode, bukan glyph font mushaf', () async {
    await QuranRepository.instance.ensureLoaded(604);

    final ayah = QuranRepository.instance.pages
        .expand((page) => page.ayahs)
        .firstWhere(
          (item) => item.surahNumber == 2 && item.ayahNumber == 1,
        );

    final text = formatAyahForClipboard(ayah);

    expect(_hasPrivateUseGlyph(text), isFalse);
    expect(text.contains('الٓمٓ'), isTrue);
    expect(text.endsWith('Al-Baqarah (2:1)'), isTrue);
  });

  test('menggabungkan baris mushaf dan membuang nomor ayat ganda', () async {
    await QuranRepository.instance.ensureLoaded(604);

    final ayah = QuranRepository.instance.pages
        .expand((page) => page.ayahs)
        .firstWhere(
          (item) => item.surahNumber == 2 && item.ayahNumber == 2,
        );

    final text = formatAyahForClipboard(ayah);
    final body = text.split('\n\n').first;

    expect(_hasPrivateUseGlyph(text), isFalse);
    expect(body.contains('\n'), isFalse);
    expect(body.endsWith('٢'), isFalse);
    expect(body.contains('لِّلۡمُتَّقِينَ'), isTrue);
  });

  test('semua ayat menghasilkan teks tanpa glyph khusus font', () async {
    await QuranRepository.instance.ensureLoaded(604);

    for (final ayah in QuranRepository.instance.pages.expand((p) => p.ayahs)) {
      expect(_hasPrivateUseGlyph(formatAyahForClipboard(ayah)), isFalse,
          reason: '${ayah.surahNumber}:${ayah.ayahNumber}');
    }
  });
}
