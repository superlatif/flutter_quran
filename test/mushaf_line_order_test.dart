// ignore: implementation_imports
import 'package:qcf_quran_plus/src/widgets/quran_page/parsed_quran_data.dart';
// ignore: implementation_imports
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran2/services/mushaf_line_order.dart';

ParsedAyahData _ayah(int surah, int ayah) {
  return ParsedAyahData(
    surahNumber: surah,
    ayahNumber: ayah,
    words: const <ParsedWordData>[],
  );
}

List<AyahKey> _keys(List<(int, int)> pairs) {
  return pairs
      .map((pair) => (surah: pair.$1, ayah: pair.$2))
      .toList(growable: false);
}

List<String> _labels(List<ParsedAyahData> data) {
  return data.map((item) => '${item.surahNumber}:${item.ayahNumber}').toList();
}

void main() {
  test('membalik urutan ayat yang diurai secara terbalik', () {
    final parsed = <ParsedAyahData>[_ayah(2, 1), _ayah(1, 1)];

    final ordered = orderParsedAyahsForReading(
      parsed,
      _keys(const <(int, int)>[(1, 1), (2, 1)]),
    );

    expect(_labels(ordered), <String>['1:1', '2:1']);
  });

  test('tidak mengubah urutan yang sudah benar', () {
    final parsed = <ParsedAyahData>[_ayah(1, 1), _ayah(2, 1)];

    final ordered = orderParsedAyahsForReading(
      parsed,
      _keys(const <(int, int)>[(1, 1), (2, 1)]),
    );

    expect(identical(ordered, parsed), isTrue);
  });

  test('menyusun ulang pola urutan lain selama kuncinya cocok', () {
    final parsed = <ParsedAyahData>[_ayah(3, 1), _ayah(1, 1), _ayah(2, 1)];

    final ordered = orderParsedAyahsForReading(
      parsed,
      _keys(const <(int, int)>[(1, 1), (2, 1), (3, 1)]),
    );

    expect(_labels(ordered), <String>['1:1', '2:1', '3:1']);
  });

  test('membiarkan daftar jika kunci tidak lengkap', () {
    final parsed = <ParsedAyahData>[_ayah(1, 1), _ayah(3, 1)];

    final ordered = orderParsedAyahsForReading(
      parsed,
      _keys(const <(int, int)>[(1, 1), (2, 1), (3, 1)]),
    );

    expect(identical(ordered, parsed), isTrue);
  });

  test('memperbaiki urutan ayat pada halaman mushaf', () async {
    await QuranRepository.instance.ensureLoaded(604);

    final repository = QuranRepository.instance;
    final page = repository.pages[1]; // halaman 2 (Al-Baqarah)

    // Baris pertama: Al-Fatihah tidak ada, dimulai dari Al-Baqarah 1.
    final firstLine = page.lines.indexWhere(
      (line) => line.ayahs.any(
        (ayah) => ayah.surahNumber == 2 && ayah.ayahNumber == 1,
      ),
    );
    expect(firstLine, greaterThanOrEqualTo(0));

    // Sebelum diperbaiki, paket mengurai ayat satu baris secara terbalik.
    expect(
      _labels(ParsedLineCache.instance.tryGet(2, firstLine)!),
      <String>['2:2', '2:1'],
    );

    applyMushafAyahOrderFix();

    expect(
      _labels(ParsedLineCache.instance.tryGet(2, firstLine)!),
      <String>['2:1', '2:2'],
    );

    // Baris berikutnya: akhir ayat 2 harus berada sebelum awal ayat 3.
    expect(
      _labels(ParsedLineCache.instance.tryGet(2, firstLine + 1)!),
      <String>['2:2', '2:3'],
    );

    // Pemanggilan ulang tidak boleh membalik lagi.
    applyMushafAyahOrderFix();
    expect(
      _labels(ParsedLineCache.instance.tryGet(2, firstLine)!),
      <String>['2:1', '2:2'],
    );
  });

  testWidgets('WidgetSpan RTL menempatkan elemen pertama di kanan', (
    tester,
  ) async {
    // Flutter >= 3.50 mengikuti urutan visual untuk placeholder RTL.
    // Inilah sebabnya data ayat harus disimpan dalam urutan baca (2:1, 2:2),
    // bukan urutan terbalik hasil parseLine().
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: RichText(
              textDirection: TextDirection.rtl,
              text: const TextSpan(
                children: <InlineSpan>[
                  WidgetSpan(
                    child: SizedBox(width: 40, height: 40),
                  ),
                  WidgetSpan(
                    child: SizedBox(width: 40, height: 40),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    final TextBox first = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 1),
        )
        .first;
    final TextBox second = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 1, extentOffset: 2),
        )
        .first;

    expect(first.left, greaterThan(second.left));
  });
}
