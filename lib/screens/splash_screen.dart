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
  bool _isLoading = true;
  final ValueNotifier<double> _fontProgress = ValueNotifier<double>(0);

  /// Hanya 5 halaman pertama dimuat saat startup supaya user tidak
  /// menunggu terlalu lama.
  static const List<int> _initialPages = <int>[1, 2, 3, 4, 5];

  @override
  void initState() {
    super.initState();
    _initFonts();
  }

  @override
  void dispose() {
    _fontProgress.dispose();
    super.dispose();
  }

  /// Memuat font untuk 5 halaman awal, update progress via [_fontProgress].
  /// Mengembalikan true jika semua font halaman awal siap.
  Future<bool> _loadInitialFonts() async {
    bool allReady = true;
    for (int i = 0; i < _initialPages.length; i++) {
      final int page = _initialPages[i];
      try {
        await QcfFontLoader.ensureFontLoaded(page);
        if (!QcfFontLoader.isFontLoaded(page)) {
          allReady = false;
        }
      } catch (_) {
        allReady = false;
      }
      _fontProgress.value = (i + 1) / _initialPages.length;
    }
    return allReady;
  }

  Future<void> _initFonts() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    // Hanya muat font halaman awal (1-5) agar aplikasi tidak menunggu
    // proses unduh seluruh Mushaf pada startup.
    bool fontsReady = await _loadInitialFonts();

    if (!mounted) {
      return;
    }

    if (!fontsReady) {
      final bool? shouldDownload = await _showDownloadDialog();
      if (!mounted) {
        return;
      }
      if (shouldDownload == true) {
        _fontProgress.value = 0;
        fontsReady = await _loadInitialFonts();
        if (!mounted) {
          return;
        }
      }
    }

    if (!mounted) {
      return;
    }

    if (!fontsReady) {
      // Font belum tersedia dan user memilih menunda unduhan.
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });

    // Muat data Quran (parser halaman) agar QuranRepository.isReady = true.
    // Tanpa ini, layar pembaca hanya menampilkan ruang kosong.
    try {
      await QuranRepository.instance.ensureLoaded(604);
    } catch (e) {
      debugPrint('Gagal memuat data Quran: $e');
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

  Future<bool?> _showDownloadDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Font Al-Qur\'an belum tersedia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Font Mushaf untuk halaman awal belum siap. '
                'Unduh sekarang agar bisa mulai membaca?',
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<double>(
                valueListenable: _fontProgress,
                builder:
                    (BuildContext context, double progress, Widget? child) {
                  return Text(
                    'Progres: ${(progress * 100).toInt()}%',
                  );
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Nanti'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Unduh Sekarang'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Font Al-Qur\'an belum terunduh'),
                  const SizedBox(height: 8),
                  const Text(
                    'Font Mushaf diperlukan untuk menampilkan halaman Al-Qur\'an.',
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _initFonts,
                    child: const Text('Unduh / Coba Lagi'),
                  ),
                ],
              )
            : _isLoading
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Memuat Mushaf Al-Qur\'an...'),
                    ],
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}
