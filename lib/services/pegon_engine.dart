import '../models/conversion_result.dart';
import 'exception_database.dart';
import 'indonesian_schwa_resolver.dart';
import 'pegon_correction_service.dart';
import 'pegon_spelling_settings_service.dart';
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
  final IndonesianSchwaResolver _schwaResolver = IndonesianSchwaResolver();
  final PegonStemmer _stemmer = PegonStemmer.instance;
  final PegonCorrectionService _corrections = PegonCorrectionService.instance;
  final PegonSpellingSettingsService _spelling =
      PegonSpellingSettingsService.instance;

  Map<String, String> _userCorrections = const <String, String>{};

  /// Pola kata yang dipakai [convertText] dan layar konverter.
  static final RegExp wordPattern = RegExp(r"[A-Za-z'’‘`]+");

  /// Pemetaan konsonan dan digraf fonetis, diurutkan dari yang terpanjang
  /// agar `kh`, `sy`, `ng`, `ny` cocok sebelum `k`, `s`, `n`.
  ///
  /// `g`, `p`, dan `v` sengaja tidak ada di sini: ketiga huruf tersebut
  /// memakai varian yang bisa dipilih pengguna (lihat [_consonant]).
  static const List<String> _digraphs = <String>[
    'kh', 'ch', 'sy', 'ng', 'ny', 'gh', 'th', 'dh',
  ];

  static const Map<String, String> _consonantMap = <String, String>{
    'b': 'ب',
    't': 'ت',
    'j': 'ج',
    'd': 'د',
    'r': 'ر',
    's': 'س',
    'z': 'ز',
    'f': 'ف',
    'q': 'ق',
    'k': 'ك',
    'h': 'ه',
    'l': 'ل',
    'm': 'م',
    'n': 'ن',
    'w': 'و',
    'y': 'ي',
    'c': 'چ',
    // Fallback fonetis untuk hamzah. Kata Arab yang memakai 'ain (ع) harus
    // masuk kamus pengecualian, mis. `jama'ah` -> جماعة.
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
  /// `e` pepet memakai fatha; `e` taling dinormalisasi menjadi `i`.
  /// `o` didekati dengan damma.
  static const Map<String, String> _affixDiacritics = <String, String>{
    'a': 'َ',
    'i': 'ِ',
    'u': 'ُ',
    'e': 'َ',
    'o': 'ُ',
  };

  static const String _sukun = 'ْ';

  /// Menyeragamkan apostrof tipografis yang sering muncul dari keyboard HP
  /// atau hasil salin-teks menjadi apostrof ASCII `'`.
  ///
  /// Tanpa ini, `jama’ah` dipecah menjadi `jama` + `ah` oleh [convertText]
  /// dan tidak pernah cocok dengan entri kamus `jama'ah`.
  static String _normalizeApostrophes(String text) => text
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('`', "'");

  bool get isDictionaryLoaded => _database.isLoaded;

  int get dictionaryEntryCount => _database.entryCount;

  /// Koreksi pengguna yang sedang dipakai (kata Latin → Pegon).
  Map<String, String> get userCorrections =>
      Map<String, String>.unmodifiable(_userCorrections);

  /// Menyiapkan mesin dengan memuat kamus pengecualian, pelafalan lokal,
  /// koreksi, dan pengaturan ejaan yang tersimpan di perangkat.
  Future<void> load() async {
    await Future.wait<void>(<Future<void>>[
      _database.load(),
      _schwaResolver.load(),
      _corrections.load(),
      _spelling.load(),
    ]);
    _userCorrections = _corrections.entries;
  }

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
    final String cleaned = _normalizeApostrophes(word.trim().toLowerCase());
    if (cleaned.isEmpty) {
      return ConversionResult(input: word, output: word);
    }

    // 1. Koreksi pengguna paling utama, lalu kamus bawaan.
    final String? corrected = _userCorrections[cleaned];
    if (corrected != null) {
      return ConversionResult(
        input: word,
        output: corrected,
        source: ConversionSource.userCorrection,
      );
    }

    final String? direct = _database.lookup(cleaned);
    if (direct != null) {
      return ConversionResult(
        input: word,
        output: direct,
        source: ConversionSource.dictionary,
      );
    }

    final String normalized = _schwaResolver.mapTalingToI(cleaned);
    if (normalized != cleaned) {
      final String? normalizedDirect = _database.lookup(normalized);
      if (normalizedDirect != null) {
        return ConversionResult(
          input: word,
          output: normalizedDirect,
          source: ConversionSource.dictionary,
        );
      }
    }

    // 2. Kupas imbuhan dari ejaan asli, lalu cocokkan akar dengan ejaan
    //    asli maupun bentuk yang menormalkan `e` menjadi `i`.
    final StemResult stem = _stemmer.stem(cleaned);
    if (stem.hasAffix) {
      final String? rootTranslation =
          _userCorrections[stem.root] ??
          _database.lookup(stem.root) ??
          _database.lookup(_schwaResolver.mapTalingToI(stem.root));
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

  /// Menyimpan koreksi pengguna untuk satu kata Latin dan langsung
  /// memakainya pada konversi berikutnya.
  Future<void> addUserCorrection(String latin, String pegon) async {
    final String key = _normalizeApostrophes(latin.trim().toLowerCase());
    final String value = pegon.trim();
    if (key.isEmpty || value.isEmpty) {
      return;
    }
    await _corrections.save(key, value);
    _userCorrections = Map<String, String>.from(_userCorrections)
      ..[key] = value;
  }

  /// Menghapus koreksi pengguna untuk satu kata Latin.
  Future<void> removeUserCorrection(String latin) async {
    final String key = _normalizeApostrophes(latin.trim().toLowerCase());
    await _corrections.remove(key);
    final Map<String, String> next = Map<String, String>.from(_userCorrections);
    next.remove(key);
    _userCorrections = next;
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
  /// - `e` pepet mengikuti kaidah lama; `e` taling diperlakukan sebagai `i`.
  /// - `o` di tengah kata digugurkan (gundul).
  /// - Vokal di awal kata ditulis dengan alif pembawa (ا، اي، او).
  /// - Vokal kembar dirapatkan menjadi satu huruf.
  ///
  /// Contoh dengan pengaturan bawaan: `kepada` -> كڤادا، `ibu` -> ايبو،
  /// `bapak` -> باڤاك. Huruf `g` dan `p`/`v` mengikuti varian ejaan yang
  /// dipilih pengguna pada [PegonSpellingSettingsService].
  String phoneticConvert(String word) {
    final StringBuffer buffer = StringBuffer();
    final String text = _schwaResolver.mapTalingToI(
      _normalizeApostrophes(word.toLowerCase()),
    );
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
        // `o` di tengah kata digugurkan (gundul).
        previousWasVowel = true;
        previousVowel = ch;
        i++;
        continue;
      }

      buffer.write(_consonant(ch));
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
    final String text = _normalizeApostrophes(affix.toLowerCase());

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

      buffer.write(_consonant(ch));
    }

    // Sukun pada konsonan akhir imbuhan (mis. بَرْ).
    final String last = text.isNotEmpty ? text[text.length - 1] : '';
    if (text.length > 1 && !_isVowel(last)) {
      buffer.write(_sukun);
    }

    return buffer.toString();
  }

  /// Konsonan tunggal dengan varian ejaan yang dipilih pengguna.
  ///
  /// - `g` mengikuti [PegonSpellingSettingsService.gSpelling] (kaf).
  /// - `p` dan `v` mengikuti [PegonSpellingSettingsService.pSpelling] (fa).
  String _consonant(String ch) {
    switch (ch) {
      case 'g':
        return _spelling.gSpelling.character;
      case 'p':
      case 'v':
        return _spelling.pSpelling.character;
      default:
        return _consonantMap[ch] ?? '';
    }
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
