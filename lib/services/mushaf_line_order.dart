// ignore: implementation_imports
import 'package:qcf_quran_plus/src/widgets/quran_page/parsed_quran_data.dart';
// ignore: implementation_imports
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';

/// Pasangan (surah, ayah) yang dipakai untuk memeriksa urutan bacaan.
typedef AyahKey = ({int surah, int ayah});

AyahKey _keyOf(ParsedAyahData ayah) =>
    (surah: ayah.surahNumber, ayah: ayah.ayahNumber);

bool _matchesOrder(
  List<ParsedAyahData> parsed,
  List<AyahKey> expectedOrder,
) {
  if (parsed.length != expectedOrder.length) {
    return false;
  }
  for (var i = 0; i < parsed.length; i++) {
    if (_keyOf(parsed[i]) != expectedOrder[i]) {
      return false;
    }
  }
  return true;
}

/// Mengembalikan data ayat dalam urutan bacaan (kanan ke kiri) yang benar.
///
/// `parseLine()` pada `qcf_quran_plus 0.1.1` mengurai ayat dalam satu baris
/// secara terbalik. Itu dulu diperlukan karena Flutter lama menempatkan
/// `WidgetSpan` dalam `RichText` RTL mengikuti urutan sumber (kiri ke kanan).
/// Sejak Flutter 3.50, `WidgetSpan` mengikuti urutan visual RTL: elemen pertama
/// berada paling kanan. Akibatnya ayat yang lebih akhir tampil lebih dulu dan
/// potongan ayat sebelumnya ikut ke tengah ayat berikutnya.
///
/// Fungsi ini menyusun ulang ayat sesuai urutan ayat pada data halaman. Urutan
/// relatif antar potongan ayat yang sama tetap dipertahankan. Jika kumpulan
/// kunci tidak cocok, daftar aslinya dikembalikan agar tidak menebak-nebak.
/// Fungsi ini idempoten: jika urutannya sudah benar, list aslinya dikembalikan.
List<ParsedAyahData> orderParsedAyahsForReading(
  List<ParsedAyahData> parsed,
  List<AyahKey> expectedOrder,
) {
  if (_matchesOrder(parsed, expectedOrder)) {
    return parsed;
  }

  final buckets = <AyahKey, List<ParsedAyahData>>{};
  for (final ayah in parsed) {
    buckets
        .putIfAbsent(_keyOf(ayah), () => <ParsedAyahData>[])
        .add(ayah);
  }

  final used = <AyahKey, int>{};
  final ordered = <ParsedAyahData>[];

  for (final key in expectedOrder) {
    final bucket = buckets[key];
    final index = used[key] ?? 0;
    if (bucket == null || index >= bucket.length) {
      // Pola urutan tidak dikenal: jangan menebak-nebak, biarkan apa adanya.
      return parsed;
    }
    ordered.add(bucket[index]);
    used[key] = index + 1;
  }

  if (ordered.length != parsed.length) {
    return parsed;
  }

  return ordered;
}

/// Menyelaraskan cache baris mushaf dengan urutan ayat pada data halaman.
///
/// Dipanggil setelah [QuranRepository.ensureLoaded] selesai. Cache diisi ulang
/// secara menyeluruh supaya semua widget `QuranPageView` mendapat urutan yang
/// sama, baik halaman tunggal maupun dua halaman (tablet PC).
void applyMushafAyahOrderFix() {
  final repository = QuranRepository.instance;
  if (!repository.isReady) {
    return;
  }

  final cache = ParsedLineCache.instance;
  final corrected = <int, List<ParsedAyahData>>{};

  for (var pageIndex = 0; pageIndex < repository.pages.length; pageIndex++) {
    final page = repository.pages[pageIndex];
    for (var lineIndex = 0; lineIndex < page.lines.length; lineIndex++) {
      final parsed = cache.tryGet(pageIndex + 1, lineIndex);
      if (parsed == null) {
        continue;
      }

      if (parsed.length < 2) {
        corrected[parsedLineKey(pageIndex + 1, lineIndex)] = parsed;
        continue;
      }

      final expectedOrder = page.lines[lineIndex].ayahs
          .map(
            (ayah) => (
              surah: ayah.surahNumber,
              ayah: ayah.ayahNumber,
            ),
          )
          .toList();

      corrected[parsedLineKey(pageIndex + 1, lineIndex)] =
          orderParsedAyahsForReading(parsed, expectedOrder);
    }
  }

  if (corrected.isNotEmpty) {
    cache.prefill(corrected);
  }
}
