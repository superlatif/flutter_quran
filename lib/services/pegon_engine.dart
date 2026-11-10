import '../models/conversion_result.dart';
import 'exception_database.dart';
import 'pegon_stemmer.dart';

/// Mesin utama transliterasi teks Latin (Bahasa Indonesia) ke aksara Pegon.
///
/// Dua pendekatan sesuai spesifikasi:
/// 1. Kata serapan Arab dicocokkan dengan kamus pengecualian agar ejaan
///    aslinya (termasuk harakat) tetap dipakai, termasuk kata berimbuhan
///    yang kata dasarnya ada di kamus (imbuhan direkonstruksi fonetis).
/// 2. Kata biasa dikonversi fonetis karakter demi karakter dengan kaidah
///    Pegon gundul standar.
class PegonEngine {
  PegonEngine._();

  static final PegonEngine instance = PegonEngine._();

  final ExceptionDatabase _database = ExceptionDatabase.instance;
  final PegonStemmer _stemmer = PegonStemmer.instance;

  /// Pemetaan konsonan dan digraf fonetis, diurutkan dari yang terpanjang
  /// agar `kh`, `sy`, `ng`, `ny` cocok sebelum `k`, `s`, `n`.
  static const List<String> _digraphs = <String>[
    'kh', 'ch', 'sy', 'ng', 'ny', 'gh', 'th', 'dh',
  ];

  static const Map<String, String> _consonantMap = <String, String>{
    'b': 'ب',
    'p': 'ڤ',
    't': 'ت',
    'j': 'ج',
    'd': 'د',
    'r': 'ر',
    's': 'س',
    'z': 'ز',
    'f': 'ف',
    'v': 'ڤ',
    'q': 'ق',
    'k': 'ك',
    'h': 'ه',
    'l': 'ل',
    'm': 'م',
    'n': 'ن',
    'w': 'و',
    'y': 'ي',
    'g': 'ڬ',
    'c': 'چ',
    "'": 'ء',
  };

  /// Huruf vokal panjang (matres lectionis) untuk posisi tengah/akhir kata.
  static const Map<String, String> _longVowels = <String, String>{
    'a': 'ا',
    'i': 'ي',
    'u': 'و',
  };

  /// Bentuk vokal di awal kata (alif pembawa + huruf vokal).
  static const Map<String, String> _initialVowels = <String, String>{
    'a': 'ا',
    'i': 'اي',
    'u': 'او',
    'e': 'اې',
    'o': 'اۅ',
  };

  /// Harakat untuk mode rekonstruksi imbuhan (mis. `ber` -> بَرْ).
  /// `e` pepet dan `o` didekati dengan fatha/damma.
  static const Map<String, String> _affixDiacritics = <String, String>{
    'a': 'َ',
    'i': 'ِ',
    'u': 'ُ',
    'e': 'َ',
    'o': 'ُ',
  };

  static const String _sukun = 'ْ';

  bool get isDictionaryLoaded => _database.isLoaded;

  int get dictionaryEntryCount => _database.entryCount;

  /// Menyiapkan mesin: memuat kamus pengecualian dari aset lokal.
  Future<void> load() => _database.load();

  /// Mengonversi seluruh kalimat [text] menjadi teks Pegon.
  ///
  /// Spasi, tanda baca, baris baru, dan angka dipertahankan apa adanya
  /// sehingga hasilnya mudah dibaca dan bisa langsung disalin ke kolom
  /// makna pada mode terjemah.
  String convertText(String text) {
    if (text.trim().isEmpty) {
      return '';
    }

    final StringBuffer buffer = StringBuffer();
    final RegExp wordPattern = RegExp("[A-Za-z']+");

    int lastEnd = 0;
    for (final RegExpMatch match in wordPattern.allMatches(text)) {
      buffer.write(text.substring(lastEnd, match.start));
      buffer.write(convertWord(match.group(0)!).output);
      lastEnd = match.end;
    }
    buffer.write(text.substring(lastEnd));
    return buffer.toString();
  }

  /// Mengonversi satu kata menjadi [ConversionResult].
  ConversionResult convertWord(String word) {
    final String cleaned = word.trim().toLowerCase();
    if (cleaned.isEmpty) {
      return ConversionResult(input: word, output: word);
    }

    // 1. Cek langsung di kamus (Arab baku & pengecualian kustom).
    final String? direct = _database.lookup(cleaned);
    if (direct != null) {
      return ConversionResult(
        input: word,
        output: direct,
        source: ConversionSource.dictionary,
      );
    }

    // 2. Kupas imbuhan lalu cek kata dasarnya di kamus.
    final StemResult stem = _stemmer.stem(cleaned);
    if (stem.hasAffix) {
      final String? rootTranslation = _database.lookup(stem.root);
      if (rootTranslation != null) {
        return ConversionResult(
          input: word,
          output: _reconstruct(stem, rootTranslation),
          source: ConversionSource.dictionaryWithAffix,
        );
      }
    }

    // 3. Konversi fonetis murni.
    return ConversionResult(
      input: word,
      output: phoneticConvert(cleaned),
      source: ConversionSource.phonetic,
    );
  }

  /// Merekonstruksi kata berimbuhan: imbuhan diterjemahkan fonetis
  /// berharakat, kata dasar memakai ejaan Arab dari kamus.
  ///
  /// Contoh: `bermusyawarah` -> بَرْ + مُشَاوَرَة.
  String _reconstruct(StemResult stem, String rootTranslation) {
    final StringBuffer buffer = StringBuffer();
    for (final String prefix in stem.prefixes) {
      buffer.write(_affixConvert(prefix));
    }
    buffer.write(rootTranslation);
    for (final String suffix in stem.suffixes) {
      buffer.write(_affixConvert(suffix));
    }
    return buffer.toString();
  }

  /// Konversi fonetis satu kata (tanpa spasi) menjadi Pegon gundul.
  ///
  /// Kaidah yang dipakai (Pegon gundul standar):
  /// - Vokal `a`, `i`, `u` ditulis sebagai huruf vokal panjang (ا ي و).
  /// - `e` pepet dan `o` di tengah kata digugurkan (gundul).
  /// - Vokal di awal kata ditulis dengan alif pembawa (ا، اي، او).
  /// - Vokal kembar dirapatkan menjadi satu huruf.
  ///
  /// Contoh: `kepada` -> كڤادا، `ibu` -> ايبو، `bapak` -> باڤاك.
  String phoneticConvert(String word) {
    final StringBuffer buffer = StringBuffer();
    final String text = word.toLowerCase();
    bool previousWasVowel = false;
    String? previousVowel;

    int i = 0;
    while (i < text.length) {
      final String twoChars =
          i + 1 < text.length ? text.substring(i, i + 2) : '';

      // Digraf dua huruf dulu (kh, sy, ng, ny, ...).
      if (twoChars.length == 2 && _digraphs.contains(twoChars)) {
        buffer.write(_digraphValue(twoChars));
        i += 2;
        previousWasVowel = false;
        previousVowel = null;
        continue;
      }

      final String ch = text[i];

      if (_isVowel(ch)) {
        if (previousWasVowel && previousVowel == ch) {
          // Vokal kembar: cukup satu huruf (mis. `maaf` -> ماف).
          i++;
          continue;
        }
        if (i == 0) {
          buffer.write(_initialVowels[ch] ?? '');
        } else if (previousWasVowel || _longVowels.containsKey(ch)) {
          // Setelah vokal lain memakai huruf vokal tunggal (mis. `air`
          // -> اير), bukan bentuk awal kata (ااي).
          buffer.write(_longVowels[ch] ?? '');
        }
        // `e`/`o` di tengah kata digugurkan (gundul).
        previousWasVowel = true;
        previousVowel = ch;
        i++;
        continue;
      }

      buffer.write(_consonantMap[ch] ?? '');
      previousWasVowel = false;
      previousVowel = null;
      i++;
    }

    return buffer.toString();
  }

  /// Konversi imbuhan dengan harakat + sukun di konsonan akhir.
  ///
  /// Contoh: `ber` -> بَرْ، `kan` -> كَنْ، `nya` -> ڽَ.
  String _affixConvert(String affix) {
    final StringBuffer buffer = StringBuffer();
    final String text = affix.toLowerCase();

    for (int i = 0; i < text.length; i++) {
      final String ch = text[i];

      // Cek digraf imbuhan (mis. `nya`, `peng`) sebelum konsonan tunggal.
      final String twoChars =
          i + 1 < text.length ? text.substring(i, i + 2) : '';
      if (twoChars.length == 2 && _digraphs.contains(twoChars)) {
        buffer.write(_digraphValue(twoChars));
        i++;
        continue;
      }

      if (_isVowel(ch)) {
        if (i == 0) {
          // Vokal di awal imbuhan memakai huruf vokal panjang.
          buffer.write(_longVowels[ch] ?? 'ا');
        }
        if (_affixDiacritics.containsKey(ch)) {
          buffer.write(_affixDiacritics[ch]!);
        }
        continue;
      }

      buffer.write(_consonantMap[ch] ?? '');
    }

    // Sukun pada konsonan akhir imbuhan (mis. بَرْ).
    final String last = text.isNotEmpty ? text[text.length - 1] : '';
    if (text.length > 1 && !_isVowel(last)) {
      buffer.write(_sukun);
    }

    return buffer.toString();
  }

  String _digraphValue(String digraph) {
    const Map<String, String> values = <String, String>{
      'kh': 'خ',
      'ch': 'خ',
      'sy': 'ش',
      'ng': 'ڠ',
      'ny': 'ڽ',
      'gh': 'غ',
      'th': 'ت',
      'dh': 'د',
    };
    return values[digraph] ?? '';
  }

  bool _isVowel(String ch) =>
      ch == 'a' || ch == 'i' || ch == 'u' || ch == 'e' || ch == 'o';
}
