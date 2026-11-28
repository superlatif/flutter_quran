import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan koreksi konversi Pegon buatan pengguna di perangkat.
///
/// Kunci adalah kata Latin yang sudah dinormalkan (huruf kecil, apostrof
/// diseragamkan), nilai adalah ejaan Pegon pilihan pengguna. Kamus bawaan
/// tetap berada di aset aplikasi; koreksi ini hanya menimpa hasilnya.
class PegonCorrectionService {
  PegonCorrectionService._();

  static final PegonCorrectionService instance = PegonCorrectionService._();

  /// Kunci penyimpanan. Diekspos agar pengujian bisa memeriksa isinya.
  static const String storageKey = 'pegon_user_corrections_v1';

  Map<String, String> _entries = const <String, String>{};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Salinan koreksi yang sedang dipakai mesin konversi.
  Map<String, String> get entries => Map<String, String>.unmodifiable(_entries);

  /// Memuat koreksi dari penyimpanan lokal. Aman dipanggil berkali-kali.
  Future<void> load() async {
    if (_isLoaded) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map) {
          _entries = decoded.map(
            (dynamic key, dynamic value) =>
                MapEntry<String, String>(key.toString(), value.toString()),
          );
        }
      }
    } catch (error) {
      debugPrint('Gagal memuat koreksi pegon: $error');
    }
    _isLoaded = true;
  }

  /// Menyimpan atau menimpa satu koreksi.
  Future<void> save(String key, String value) async {
    final Map<String, String> next = Map<String, String>.from(_entries);
    next[key] = value;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(next));

    _entries = next;
    _isLoaded = true;
  }

  /// Menghapus satu koreksi.
  Future<void> remove(String key) async {
    if (!_entries.containsKey(key)) {
      return;
    }
    final Map<String, String> next = Map<String, String>.from(_entries);
    next.remove(key);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(next));

    _entries = next;
  }
}
