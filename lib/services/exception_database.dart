import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Mengelola file JSON kamus lokal pengecualian kata baku Arab.
class ExceptionDatabase {
  ExceptionDatabase._();

  static final ExceptionDatabase instance = ExceptionDatabase._();

  static const String _assetPath = 'assets/data/exceptions.json';

  Map<String, String> _arabicBaku = const <String, String>{};
  Map<String, String> _customExceptions = const <String, String>{};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  int get entryCount => _arabicBaku.length + _customExceptions.length;

  /// Memuat kamus dari aset lokal. Aman dipanggil berkali-kali.
  Future<void> load() async {
    if (_isLoaded) {
      return;
    }
    try {
      final String raw = await rootBundle.loadString(_assetPath);
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;

      Map<String, String> parseMap(String key) {
        final dynamic value = decoded[key];
        if (value is! Map) {
          return const <String, String>{};
        }
        return value.map(
          (dynamic k, dynamic v) => MapEntry<String, String>(
            k.toString().trim().toLowerCase(),
            v.toString(),
          ),
        );
      }

      _arabicBaku = parseMap('arabic_baku');
      _customExceptions = parseMap('custom_exceptions');
      _isLoaded = true;
    } catch (error, stackTrace) {
      debugPrint('Gagal memuat kamus pegon: $error\n$stackTrace');
      // Kamus kosong: mesin tetap bisa bekerja secara fonetis.
      _isLoaded = true;
    }
  }

  /// Mencari kata di kamus. Mengembalikan null bila tidak ditemukan.
  String? lookup(String word) {
    final String key = word.trim().toLowerCase();
    if (key.isEmpty) {
      return null;
    }
    return _customExceptions[key] ?? _arabicBaku[key];
  }
}
