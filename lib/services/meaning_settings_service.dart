import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pilihan skrip yang ditampilkan pada makna gandul.
enum DisplayScript {
  pegon('pegon', 'Pegon'),
  latin('latin', 'Latin'),
  both('both', 'Pegon + Latin');

  const DisplayScript(this.value, this.label);

  final String value;
  final String label;

  static DisplayScript fromValue(String? value) {
    return DisplayScript.values.firstWhere(
      (DisplayScript script) => script.value == value,
      orElse: () => DisplayScript.both,
    );
  }
}

/// Mode input/keyboard yang digunakan saat menyunting makna.
enum MeaningInputMode {
  auto('auto', 'Otomatis'),
  pegon('pegon', 'Pegon'),
  latin('latin', 'Latin');

  const MeaningInputMode(this.value, this.label);

  final String value;
  final String label;

  static MeaningInputMode fromValue(String? value) {
    return MeaningInputMode.values.firstWhere(
      (MeaningInputMode mode) => mode.value == value,
      orElse: () => MeaningInputMode.auto,
    );
  }
}

/// Gaya tampilan makna gandul.
enum MeaningStyle {
  block('block', 'Blok'),
  indented('indented', 'Menjorok'),
  italic45('italic_45', 'Miring 45°');

  const MeaningStyle(this.value, this.label);

  final String value;
  final String label;

  static MeaningStyle fromValue(String? value) {
    return MeaningStyle.values.firstWhere(
      (MeaningStyle style) => style.value == value,
      orElse: () => MeaningStyle.block,
    );
  }
}

/// Menyimpan dan menyebarkan pengaturan tampilan makna gandul.
class MeaningSettingsService extends ChangeNotifier {
  MeaningSettingsService._();

  static final MeaningSettingsService instance = MeaningSettingsService._();

  static const String _kDisplayScript = 'display_script';
  static const String _kInputMode = 'input_mode';
  static const String _kShowBaseMeaning = 'show_base_meaning';
  static const String _kMeaningStyle = 'meaning_style';

  bool _isLoaded = false;
  DisplayScript _displayScript = DisplayScript.both;
  MeaningInputMode _inputMode = MeaningInputMode.auto;
  bool _showBaseMeaning = true;
  MeaningStyle _meaningStyle = MeaningStyle.block;

  bool get isLoaded => _isLoaded;
  DisplayScript get displayScript => _displayScript;
  MeaningInputMode get inputMode => _inputMode;
  bool get showBaseMeaning => _showBaseMeaning;
  MeaningStyle get meaningStyle => _meaningStyle;

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _displayScript = DisplayScript.fromValue(
        prefs.getString(_kDisplayScript),
      );
      _inputMode = MeaningInputMode.fromValue(prefs.getString(_kInputMode));
      _showBaseMeaning = prefs.getBool(_kShowBaseMeaning) ?? true;
      _meaningStyle = MeaningStyle.fromValue(prefs.getString(_kMeaningStyle));
    } catch (error) {
      debugPrint('Gagal memuat pengaturan makna: $error');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setDisplayScript(DisplayScript value) async {
    if (_displayScript == value) {
      return;
    }
    _displayScript = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDisplayScript, value.value);
  }

  Future<void> setInputMode(MeaningInputMode value) async {
    if (_inputMode == value) {
      return;
    }
    _inputMode = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInputMode, value.value);
  }

  Future<void> setShowBaseMeaning(bool value) async {
    if (_showBaseMeaning == value) {
      return;
    }
    _showBaseMeaning = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowBaseMeaning, value);
  }

  Future<void> setMeaningStyle(MeaningStyle value) async {
    if (_meaningStyle == value) {
      return;
    }
    _meaningStyle = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMeaningStyle, value.value);
  }
}
