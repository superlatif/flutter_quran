import 'package:qcf_quran_plus/qcf_quran_plus.dart';

/// Menyiapkan teks ayat yang aman untuk clipboard dan share sheet.
///
/// `Ayah.othmanicAyah` memakai glyph Private Use Area (U+E000–U+F8FF) yang
/// hanya ada pada font mushaf khusus. Clipboard hanya membawa teks, bukan font,
/// sehingga glyph tersebut tampil sebagai kotak ketika ditempel di aplikasi
/// lain. `Ayah.ayah` berisi teks Arab Unicode standar yang didukung font
/// sistem mana pun, jadi itulah yang dipakai di sini.
String formatAyahForClipboard(Ayah ayah) {
  final String body = ayah.ayah
      .replaceAll('\u00A0', ' ')
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      // Angka Arab di akhir teks adalah penanda nomor ayat pada mushaf.
      // Nomor ayat sudah ditulis pada baris referensi di bawahnya.
      .replaceAll(RegExp(r'[\u0660-\u0669\s]+$'), '')
      .trim();

  return '$body\n\n'
      '${ayah.surahNameEn} (${ayah.surahNumber}:${ayah.ayahNumber})';
}
