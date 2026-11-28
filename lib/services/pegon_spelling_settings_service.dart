import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Varian huruf Pegon untuk bunyi `g` (kaf).
///
/// Ejaan bawaan aplikasi memakai [kafDotAbove]. Beberapa tradisi Pegon
/// memakai kaf ber titik tiga di bawah atau kaf ber titik satu di bawah.
enum PegonGSpelling {
  kafDotAbove('kaf_dot_above', 'ڬ', 'Kaf titik 1 atas (bawaan)'),
  kafThreeDotsBelow('kaf_three_dots_below', 'ڮ', 'Kaf titik 3 bawah'),
  kafDotBelow('kaf_dot_below', 'ࢴ', 'Kaf titik 1 bawah'),
  kehehDotAbove('keheh_dot_above', 'ݢ', 'Keheh titik 1 atas');

  const PegonGSpelling(this.value, this.character, this.label);

  final String value;
  final String character;
  final String label;

  /// Teks pilihan yang menampilkan glif sekaligus nama variannya.
  String get optionLabel => '$character — $label';

  static PegonGSpelling fromValue(String? value) {
    return PegonGSpelling.values.firstWhere(
      (PegonGSpelling spelling) => spelling.value == value,
      orElse: () => PegonGSpelling.kafDotAbove,
    );
  }
}

/// Varian huruf Pegon untuk bunyi `p` / `v` (fa).
///
/// Ejaan bawaan aplikasi memakai [veh] (fa titik tiga). Tradisi lain
/// memakai fa ber titik satu di bawah, atau fa biasa (titik satu di atas).
enum PegonPSpelling {
  veh('veh', 'ڤ', 'Fa titik 3 atas (bawaan)'),
  fehDotBelow('feh_dot_below', 'ڣ', 'Fa titik 1 bawah'),
  fehDotMovedBelow('feh_dot_moved_below', 'ڢ', 'Fa titik 1 dipindah ke bawah'),
  feh('feh', 'ف', 'Fa biasa (titik 1 atas)');

  const PegonPSpelling(this.value, this.character, this.label);

  final String value;
  final String character;
  final String label;

  /// Teks pilihan yang menampilkan glif sekaligus nama variannya.
  String get optionLabel => '$character — $label';

  static PegonPSpelling fromValue(String? value) {
    return PegonPSpelling.values.firstWhere(
      (PegonPSpelling spelling) => spelling.value == value,
      orElse: () => PegonPSpelling.veh,
    );
  }
}

/// Menyimpan dan menyebarkan pilihan ejaan Pegon hasil konversi Latin.
///
/// Pengaturan ini bersifat global: dipakai baik oleh layar konverter maupun
/// tombol "Ubah ke Pegon" pada editor makna. Kata yang sudah ada di kamus
/// pengecualian dan koreksi pengguna tidak diubah oleh pengaturan ini.
class PegonSpellingSettingsService extends ChangeNotifier {
  PegonSpellingSettingsService._();

  static final PegonSpellingSettingsService instance =
      PegonSpellingSettingsService._();

  static const String gSpellingKey = 'pegon_g_spelling';
  static const String pSpellingKey = 'pegon_p_spelling';

  bool _isLoaded = false;
  PegonGSpelling _gSpelling = PegonGSpelling.kafDotAbove;
  PegonPSpelling _pSpelling = PegonPSpelling.veh;

  bool get isLoaded => _isLoaded;
  PegonGSpelling get gSpelling => _gSpelling;
  PegonPSpelling get pSpelling => _pSpelling;

  /// Memuat pilihan yang tersimpan. Aman dipanggil berkali-kali.
  Future<void> load() async {
    if (_isLoaded) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _gSpelling = PegonGSpelling.fromValue(prefs.getString(gSpellingKey));
      _pSpelling = PegonPSpelling.fromValue(prefs.getString(pSpellingKey));
    } catch (error) {
      debugPrint('Gagal memuat pengaturan ejaan Pegon: $error');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setGSpelling(PegonGSpelling value) async {
    if (_gSpelling == value) {
      return;
    }
    _gSpelling = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(gSpellingKey, value.value);
  }

  Future<void> setPSpelling(PegonPSpelling value) async {
    if (_pSpelling == value) {
      return;
    }
    _pSpelling = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(pSpellingKey, value.value);
  }
}
