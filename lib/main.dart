import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quran2/providers/quran_provider.dart';
import 'package:quran2/screens/splash_screen.dart';

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
      child: MaterialApp(
        title: 'Alquran',
        debugShowCheckedModeBanner: false,
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
        home: const SplashScreen(),
      ),
    );
  }
}
