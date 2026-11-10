/// Hasil pengupasan imbuhan satu kata.
class StemResult {
  const StemResult({
    required this.root,
    this.prefixes = const <String>[],
    this.suffixes = const <String>[],
  });

  /// Kata dasar setelah imbuhan dikupas.
  final String root;

  /// Imbuhan awalan yang dikupas, dalam urutan pengupasan.
  final List<String> prefixes;

  /// Imbuhan akhiran yang dikupas, dalam urutan pengupasan.
  final List<String> suffixes;

  /// True bila kata ini mengandung imbuhan.
  bool get hasAffix => prefixes.isNotEmpty || suffixes.isNotEmpty;
}

/// Algoritma kupas awalan/akhiran (afiksasi) ringan untuk bahasa Indonesia.
class PegonStemmer {
  const PegonStemmer._();

  static const PegonStemmer instance = PegonStemmer._();

  /// Awalan yang dikenali. Diurutkan dari yang paling panjang agar
  /// (misalnya) `ter` dan `per` tidak salah dikupas menjadi `t` + `er`.
  static const List<String> _prefixes = <String>[
    'meng', 'peng', 'meny', 'peny', 'mem', 'men', 'pem', 'pen',
    'ber', 'ter', 'per', 'me', 'pe', 'di', 'ke', 'se',
  ];

  /// Akhiran yang dikenali. `kan` dan `an` dicek sebelum `i` agar
  /// `makanan` tidak terkupas menjadi `makena` + `i`.
  static const List<String> _suffixes = <String>[
    'nya', 'kan', 'an', 'lah', 'kah', 'tah', 'i',
  ];

  /// Kata penghubung/umum yang tidak boleh dikupas lebih lanjut
  /// karena hasil kupasnya menjadi tidak bermakna.
  static const Set<String> _particles = <String>{
    'dan', 'atau', 'yang', 'di', 'ke', 'dari', 'pada', 'untuk',
    'dengan', 'ini', 'itu', 'juga', 'tidak', 'bukan', 'jika', 'kalau',
    'karena', 'maka', 'agar', 'supaya', 'oleh', 'akan', 'sudah',
    'telah', 'sedang', 'masih', 'belum', 'ada', 'adalah', 'ialah',
    'yaitu', 'seperti', 'sebagai', 'serta', 'ataupun', 'namun',
    'tetapi', 'melainkan', 'padahal', 'bahwa', 'bahwasanya',
  };

  /// Mengupas imbuhan dari [word] dan mengembalikan hasilnya.
  ///
  /// Kata pendek (<= 4 huruf setelah kupas) tidak dikupas lagi agar
  /// kata dasarnya tidak menjadi sisa-sisa tidak bermakna.
  StemResult stem(String word) {
    String current = word.toLowerCase().trim();
    final List<String> prefixes = <String>[];
    final List<String> suffixes = <String>[];

    if (current.isEmpty || current.length <= 3) {
      return StemResult(root: current);
    }

    // 1. Kupas akhiran dulu.
    bool changed = true;
    while (changed && current.length > 3) {
      changed = false;
      for (final String suffix in _suffixes) {
        if (current.endsWith(suffix) &&
            current.length - suffix.length >= 3) {
          suffixes.add(suffix);
          current = current.substring(0, current.length - suffix.length);
          changed = true;
          break;
        }
      }
    }

    // Kata penghubung umum berhenti di sini.
    if (_particles.contains(current)) {
      return StemResult(root: current, suffixes: suffixes);
    }

    // 2. Kupas awalan.
    changed = true;
    while (changed && current.length > 3) {
      changed = false;
      for (final String prefix in _prefixes) {
        if (current.startsWith(prefix) &&
            current.length - prefix.length >= 2) {
          prefixes.add(prefix);
          current = current.substring(prefix.length);
          changed = true;
          break;
        }
      }
    }

    return StemResult(root: current, prefixes: prefixes, suffixes: suffixes);
  }
}
