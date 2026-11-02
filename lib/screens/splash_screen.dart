import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
// ignore: implementation_imports
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';

import 'package:quran2/screens/quran_reader_screen.dart';

/// Splash screen: cek ketersediaan font lokal, unduh jika diperlukan,
/// lalu masuk ke layar pembaca Mushaf.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasError = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initFonts();
  }

  Future<void> _initFonts() async {
    if (!mounted || _isLoading && !_hasError) {
      return;
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Prepare only the first page before opening the reader. The remaining
      // pages are loaded incrementally after the reader is available.
      await Future.wait<void>(<Future<void>>[
        QcfFontLoader.ensureFontLoaded(1),
        QuranRepository.instance.ensureLoaded(604),
      ]);
    } catch (error) {
      debugPrint('Gagal menyiapkan Mushaf: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage =
            'Mushaf belum berhasil disiapkan. Silakan coba unduh kembali.';
      });
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const QuranReaderScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.menu_book_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Mushaf belum berhasil disiapkan.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _initFonts,
                      icon: const Icon(Icons.download),
                      label: const Text('Unduh dan Coba Lagi'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text(
                      'Sedang menyiapkan Mushaf Al-Qur\'an',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mohon tunggu sebentar. Halaman akan dibuka segera; '
                      'halaman lainnya disiapkan bertahap di latar belakang.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ),
        ),
      ),
    );
  }
}
