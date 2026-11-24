import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quran2/providers/quran_provider.dart';
import 'package:quran2/screens/quran_reader_screen.dart';

void main() {
  // Sqflite hanya mendukung Android/iOS secara native.
  // Di desktop (Linux/Windows/macOS), gunakan implementasi FFI.
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const AlquranApp());
}

class AlquranApp extends StatelessWidget {
  const AlquranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<QuranProvider>(create: (_) => QuranProvider()),
      ],
      child: Consumer<QuranProvider>(
        builder: (BuildContext context, QuranProvider provider, Widget? child) {
          return MaterialApp(
            title: 'Alquran',
            debugShowCheckedModeBanner: false,
            themeMode: provider.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF0F766E)),
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Color(0xFF0F766E),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            builder: (BuildContext context, Widget? child) {
              // qcf_quran_plus 0.1.1 masih memakai package:flutter/material.dart.
              // Bridge ini membuat ThemeData & MaterialLocalizations versi lama
              // tetap tersedia sampai paket tersebut pindah ke material_ui.
              // ignore: deprecated_member_use
              return MaterialUiCompatibilityBridge(child: child!);
            },
            home: const QuranReaderScreen(),
          );
        },
      ),
    );
  }
}
