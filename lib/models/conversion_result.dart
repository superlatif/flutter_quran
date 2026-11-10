/// Hasil konversi satu kata Latin menjadi teks Pegon.
class ConversionResult {
  const ConversionResult({
    required this.input,
    required this.output,
    this.source = ConversionSource.phonetic,
  });

  /// Kata asli yang dikonversi (huruf Latin).
  final String input;

  /// Hasil konversi Pegon.
  final String output;

  /// Dari mana hasil konversi berasal.
  final ConversionSource source;

  bool get isEmpty => output.trim().isEmpty;
}

/// Sumber hasil konversi sebuah kata.
enum ConversionSource {
  /// Kata diambil dari kamus pengecualian (Arab baku / kustom).
  dictionary,

  /// Kata hasil rekonstruksi: imbuhan fonetis + kata dasar dari kamus.
  dictionaryWithAffix,

  /// Kata dikonversi fonetis karakter demi karakter.
  phonetic;

  String get label {
    switch (this) {
      case ConversionSource.dictionary:
        return 'Kamus';
      case ConversionSource.dictionaryWithAffix:
        return 'Kamus + imbuhan';
      case ConversionSource.phonetic:
        return 'Fonetis';
    }
  }
}
