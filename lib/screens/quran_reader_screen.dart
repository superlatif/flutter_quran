import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
// ignore: implementation_imports
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/quran_provider.dart';
import '../models/quran_page_info.dart';
import '../services/bookmark_service.dart';
import '../services/daily_log_service.dart';
import '../services/meaning_settings_service.dart';
import '../services/offline_data_service.dart';
import '../widgets/meaning_dialogs.dart';
import '../widgets/translation_surah_view.dart';
import 'about_screen.dart';
import 'bookmark_tree_screen.dart';
import 'log_khatam_screen.dart';
import 'quran_search_dialogs.dart';
import 'reading_statistics_screen.dart';

enum _ReaderSearchAction { page, surah, phrase }

class _OfflineDataState {
  const _OfflineDataState({
    this.cachedPages = const <int>{},
    this.isScanning = true,
    this.isDownloading = false,
    this.error,
  });

  final Set<int> cachedPages;
  final bool isScanning;
  final bool isDownloading;
  final String? error;

  int get percentage =>
      (cachedPages.length * 100 / QcfFontLoader.totalPages).floor();
}

/// Layar utama pembaca Mushaf Al-Qur'an (15 baris per halaman).
class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  int? _loadingFontPage;
  int? _navigationTargetPage;
  int _fontPreloadGeneration = 0;
  bool _isPreparingReader = true;
  bool _isChromeVisible = false;
  bool _isTranslationMode = false;
  int? _translationSurahId;
  int _translationRefreshToken = 0;
  String? _readerLoadError;
  final ValueNotifier<_OfflineDataState> _offlineData =
      ValueNotifier<_OfflineDataState>(const _OfflineDataState());

  @override
  void initState() {
    super.initState();
    unawaited(_applySystemUiMode(immersive: !_isChromeVisible));
    unawaited(_prepareReader());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshOfflinePages());
    });
  }

  /// Requests immersive (hidden system bars) mode while the reader is in
  /// full-screen mode and restores the normal bars when the chrome is shown.
  ///
  /// Immersive mode is not supported on every Android version (edge-to-edge is
  /// enforced from API 35/36), so the [SafeArea] around the reader body is what
  /// guarantees that the status bar, navigation bar, and DeX taskbar never
  /// cover the Mushaf.
  Future<void> _applySystemUiMode({required bool immersive}) {
    if (kIsWeb) {
      return Future<void>.value();
    }
    return SystemChrome.setEnabledSystemUIMode(
      immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _prepareReader() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isPreparingReader = true;
      _readerLoadError = null;
    });

    try {
      await Future.wait<void>(<Future<void>>[
        QcfFontLoader.ensureFontLoaded(1),
        QuranRepository.instance.ensureLoaded(QcfFontLoader.totalPages),
      ]);
    } catch (error, stackTrace) {
      debugPrint('Gagal menyiapkan data Mushaf lokal: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingReader = false;
        _readerLoadError =
            'Data Mushaf belum berhasil dibuka. Silakan coba lagi.';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isPreparingReader = false;
    });

    // Keep the neighbouring pages ready so the next swipe is not delayed by
    // font registration (each Quran page uses its own QCF font family).
    unawaited(_preparePageFonts(1));
  }

  @override
  void dispose() {
    // Never leave the system bars hidden after leaving the reader.
    unawaited(_applySystemUiMode(immersive: false));
    _offlineData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QuranProvider provider = context.watch<QuranProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: _isChromeVisible
          ? AppBar(
              title: _buildAppBarTitle(context, provider),
              actions: <Widget>[
                if (!QcfFontLoader.isFontLoaded(provider.currentPage))
                  IconButton(
                    tooltip: _isFontLoading(provider.currentPage)
                        ? 'Menyiapkan font halaman ${provider.currentPage}'
                        : 'Unduh font halaman ${provider.currentPage}',
                    onPressed: _isFontLoading(provider.currentPage)
                        ? null
                        : () => _downloadPageFont(provider.currentPage),
                    icon: _isFontLoading(provider.currentPage)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                  ),
                ValueListenableBuilder<_OfflineDataState>(
                  valueListenable: _offlineData,
                  builder:
                      (
                        BuildContext context,
                        _OfflineDataState offlineData,
                        Widget? child,
                      ) {
                        final int percentage = offlineData.percentage;
                        if (!offlineData.isScanning && percentage == 100) {
                          return const SizedBox.shrink();
                        }
                        final String tooltip = offlineData.isScanning
                            ? 'Memeriksa font Mushaf offline'
                            : offlineData.isDownloading
                            ? 'Menyiapkan font Mushaf offline: $percentage%'
                            : offlineData.error != null
                            ? 'Gagal memeriksa font offline. Ketuk untuk mencoba lagi.'
                            : percentage == 100
                            ? 'Semua 604 halaman siap dibaca offline'
                            : 'Font offline $percentage%. Ketuk untuk menyiapkan semua halaman';
                        return IconButton(
                          tooltip: tooltip,
                          onPressed: offlineData.isScanning || percentage == 100
                              ? null
                              : () => _onOfflineIndicatorTap(offlineData),
                          icon: SizedBox(
                            width: 36,
                            height: 36,
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                CircularProgressIndicator(
                                  value: offlineData.isScanning
                                      ? null
                                      : percentage / 100,
                                  backgroundColor: Colors.red,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.green,
                                      ),
                                  strokeWidth: 3,
                                ),
                                Text(
                                  offlineData.isScanning ? '…' : '$percentage%',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                ),
                IconButton(
                  icon: const Icon(Icons.bookmarks),
                  tooltip: 'Bookmark',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext context) =>
                            const BookmarkTreeScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                  tooltip: isDark
                      ? 'Beralih ke mode terang'
                      : 'Beralih ke mode gelap',
                  onPressed: () => provider.setDarkMode(!isDark),
                ),
                IconButton(
                  icon: Icon(
                    _isTranslationMode ? Icons.menu_book : Icons.history_edu,
                    color: _isTranslationMode
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  tooltip: _isTranslationMode
                      ? 'Kembali ke Mushaf'
                      : 'Mode Makna Gandul',
                  onPressed: () => _toggleTranslationMode(provider),
                ),
                Switch(
                  value: provider.isTajweed,
                  onChanged: (_) => provider.toggleTajweed(),
                ),
                IconButton(
                  icon: Icon(
                    provider.dualPage ? Icons.grid_view : Icons.layers,
                    color: provider.dualPage
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  tooltip: provider.dualPage
                      ? 'Mode 2 Halaman / Spread'
                      : 'Mode 1 Halaman',
                  onPressed: () => provider.setDualPage(!provider.dualPage),
                ),
              ],
            )
          : null,
      body: SafeArea(
        // The AppBar already accounts for the top inset when it is visible.
        // The bottom inset is always respected so navigation bars, gesture
        // areas, and the DeX taskbar never cover the Mushaf.
        top: !_isChromeVisible,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey<String>('quran-reader-tap-area'),
                      behavior: HitTestBehavior.translucent,
                      onTap: _toggleChrome,
                      child: _readerLoadError != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.menu_book_outlined,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _readerLoadError!,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      onPressed: _prepareReader,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Coba Lagi'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _isTranslationMode
                          ? _buildTranslationMode(provider, isDark)
                          : _isPreparingReader ||
                                !QuranRepository.instance.isReady
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Membuka data Mushaf dari perangkat...',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : LayoutBuilder(
                              builder:
                                  (
                                    BuildContext context,
                                    BoxConstraints constraints,
                                  ) {
                                    final bool twoPage =
                                        provider.dualPage &&
                                        constraints.maxWidth >= 750;
                                    return QuranPageView(
                                      pageController: provider.pageController,
                                      highlights: provider.highlights,
                                      isDarkMode: isDark,
                                      isTajweed: provider.isTajweed,
                                      enableTwoPageLayout: twoPage,
                                      // Build pages as soon as they enter the
                                      // viewport. Deferring them until the swipe
                                      // settles leaves a blank page visible for a
                                      // moment (the "jeda" between pages).
                                      deferNewPages: false,
                                      onPageChanged: (int? pageNumber) {
                                        if (pageNumber != null) {
                                          _handlePageChanged(
                                            provider,
                                            pageNumber,
                                          );
                                        }
                                      },
                                      onLongPress:
                                          (
                                            int surah,
                                            int ayah,
                                            LongPressStartDetails _,
                                          ) {
                                            _showAyahMenu(surah, ayah);
                                          },
                                      topBar: _isChromeVisible
                                          ? _buildTopBar(context, provider)
                                          : null,
                                      bottomBar: _isChromeVisible
                                          ? _buildBottomBar()
                                          : null,
                                    );
                                  },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            if (_navigationTargetPage case final int targetPage)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.scrim
                      .withValues(alpha: 0.35),
                  child: Center(
                    child: Card(
                      margin: const EdgeInsets.all(32),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Menyiapkan halaman $targetPage...',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Mohon tunggu sebentar. Mushaf sedang dibuka.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handlePageChanged(QuranProvider provider, int pageNumber) {
    provider.handlePageChanged(pageNumber);
    unawaited(_preparePageFonts(pageNumber));
  }

  /// Loads the font for [pageNumber] and the pages directly before/after it.
  ///
  /// QCF fonts are page-specific, so without preloading the incoming page is
  /// blank for a moment while its font is registered. Preloading the neighbours
  /// makes normal sequential swiping (and swiping back) render immediately.
  Future<void> _preparePageFonts(int pageNumber) async {
    final int generation = ++_fontPreloadGeneration;
    final List<int> pages = <int>[
      pageNumber,
      if (pageNumber + 1 <= QcfFontLoader.totalPages) pageNumber + 1,
      if (pageNumber - 1 >= 1) pageNumber - 1,
    ];

    for (int index = 0; index < pages.length; index++) {
      final int page = pages[index];
      if (!mounted || generation != _fontPreloadGeneration) {
        return;
      }

      if (QcfFontLoader.isFontLoaded(page)) {
        _markOfflinePageReady(page);
        continue;
      }

      try {
        await QcfFontLoader.ensureFontLoaded(page);
      } catch (error) {
        debugPrint('Gagal memuat font halaman $page: $error');
        continue;
      }

      if (!mounted || generation != _fontPreloadGeneration) {
        return;
      }
      _markOfflinePageReady(page);

      // The current page may already have been laid out with a fallback font
      // while its QCF font was loading. Rebuild it once the font is ready.
      if (index == 0) {
        setState(() {});
      }
    }
  }

  bool _isFontLoading(int pageNumber) => _loadingFontPage == pageNumber;

  void _onOfflineIndicatorTap(_OfflineDataState offlineData) {
    final int percentage = offlineData.percentage;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            offlineData.isDownloading
                ? 'Unduhan font Mushaf: $percentage% selesai'
                : 'Persiapan font Mushaf dimulai dari $percentage%',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

    if (offlineData.isDownloading) {
      return;
    }
    if (offlineData.error != null) {
      unawaited(_refreshOfflinePages());
      return;
    }
    unawaited(_downloadAllOfflinePages());
  }

  Future<void> _refreshOfflinePages() async {
    _offlineData.value = _OfflineDataState(
      cachedPages: _offlineData.value.cachedPages,
      isScanning: true,
      isDownloading: _offlineData.value.isDownloading,
    );
    try {
      final Set<int> cachedPages = await OfflineDataService.instance
          .getCachedPages();
      if (!mounted) {
        return;
      }
      for (int page = 1; page <= QcfFontLoader.totalPages; page++) {
        if (QcfFontLoader.isFontLoaded(page)) {
          cachedPages.add(page);
        }
      }
      _offlineData.value = _OfflineDataState(cachedPages: cachedPages);
    } on Exception catch (error, stackTrace) {
      debugPrint('Gagal memeriksa data offline: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      _offlineData.value = _OfflineDataState(
        cachedPages: _offlineData.value.cachedPages,
        error: 'Gagal memeriksa data offline',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memeriksa data offline')),
      );
    }
  }

  Future<void> _downloadAllOfflinePages() async {
    final _OfflineDataState currentState = _offlineData.value;
    if (currentState.isScanning ||
        currentState.isDownloading ||
        currentState.percentage == 100) {
      return;
    }

    final Set<int> cachedPages = Set<int>.from(currentState.cachedPages);
    _offlineData.value = _OfflineDataState(
      cachedPages: Set<int>.unmodifiable(cachedPages),
      isDownloading: true,
    );

    try {
      for (int page = 1; page <= QcfFontLoader.totalPages; page++) {
        if (cachedPages.contains(page)) {
          continue;
        }
        await OfflineDataService.instance.cachePage(page);
        cachedPages.add(page);
        if (!mounted) {
          return;
        }
        _offlineData.value = _OfflineDataState(
          cachedPages: Set<int>.unmodifiable(cachedPages),
          isDownloading: true,
        );
        await Future<void>.delayed(Duration.zero);
      }
      if (mounted) {
        _offlineData.value = _OfflineDataState(
          cachedPages: Set<int>.unmodifiable(cachedPages),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua halaman siap digunakan offline')),
        );
      }
    } on Exception catch (error, stackTrace) {
      debugPrint('Gagal menyiapkan seluruh data offline: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      _offlineData.value = _OfflineDataState(
        cachedPages: Set<int>.unmodifiable(cachedPages),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Persiapan data offline terhenti. Ketuk indikator untuk melanjutkan.',
          ),
        ),
      );
    }
  }

  Future<void> _downloadPageFont(
    int pageNumber, {
    bool showSuccess = true,
  }) async {
    setState(() {
      _loadingFontPage = pageNumber;
    });

    try {
      await QcfFontLoader.ensureFontLoaded(pageNumber);
      if (!mounted) {
        return;
      }
      _markOfflinePageReady(pageNumber);
      setState(() {
        _loadingFontPage = null;
      });
      unawaited(_preparePageFonts(pageNumber));
      if (showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Font halaman $pageNumber berhasil dimuat')),
        );
      }
    } catch (error) {
      debugPrint('Gagal memuat font halaman $pageNumber: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingFontPage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Font halaman $pageNumber gagal dimuat. '
            'Tekan tombol unduh untuk mencoba lagi.',
          ),
        ),
      );
    }
  }

  void _markOfflinePageReady(int pageNumber) {
    final _OfflineDataState currentState = _offlineData.value;
    if (currentState.cachedPages.contains(pageNumber)) {
      return;
    }
    final Set<int> cachedPages = Set<int>.from(currentState.cachedPages)
      ..add(pageNumber);
    _offlineData.value = _OfflineDataState(
      cachedPages: Set<int>.unmodifiable(cachedPages),
      isScanning: currentState.isScanning,
      isDownloading: currentState.isDownloading,
    );
  }

  Future<void> _navigateToPage(int pageNumber) async {
    if (pageNumber < 1 || pageNumber > QcfFontLoader.totalPages) {
      return;
    }
    final QuranProvider provider = context.read<QuranProvider>();
    final bool needsFont = !QcfFontLoader.isFontLoaded(pageNumber);
    if (needsFont) {
      setState(() {
        _navigationTargetPage = pageNumber;
      });
    }

    try {
      if (needsFont) {
        await WidgetsBinding.instance.endOfFrame;
        await QcfFontLoader.ensureFontLoaded(pageNumber);
      }
      if (!mounted) {
        return;
      }
      _markOfflinePageReady(pageNumber);
      provider.goToPage(pageNumber);
    } catch (error) {
      debugPrint('Gagal membuka halaman $pageNumber: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Halaman $pageNumber belum dapat dibuka. Silakan coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && _navigationTargetPage != null) {
        setState(() {
          _navigationTargetPage = null;
        });
      }
    }
  }

  Widget _buildAppBarTitle(BuildContext context, QuranProvider provider) {
    final ThemeData theme = Theme.of(context);
    final QuranPageInfo info = QuranPageInfo.forPage(provider.currentPage);
    final String detailLabel = _isTranslationMode
        ? 'Makna Gandul • ${getSurahName(_translationSurahId ?? 1)}'
        : info.label;

    return Row(
      children: <Widget>[
        const Text('Alquran'),
        const SizedBox(width: 10),
        Container(
          width: 1,
          height: 18,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            detailLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _toggleChrome() {
    final bool showChrome = !_isChromeVisible;
    setState(() {
      _isChromeVisible = showChrome;
    });
    unawaited(_applySystemUiMode(immersive: !showChrome));
  }

  void _toggleTranslationMode(QuranProvider provider) {
    setState(() {
      _isTranslationMode = !_isTranslationMode;
      if (_isTranslationMode) {
        _translationSurahId ??=
            QuranPageInfo.forPage(provider.currentPage).primarySurahId ?? 1;
      }
    });
  }

  void _selectTranslationSurah(int surahNumber) {
    if (surahNumber < 1 || surahNumber > totalSurahCount) {
      return;
    }
    setState(() {
      _translationSurahId = surahNumber;
    });
  }

  Future<void> _showTranslationSurahSearch() async {
    final int? surahNumber = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => const SurahSearchDialog(),
    );
    if (surahNumber == null || !mounted) {
      return;
    }
    _selectTranslationSurah(surahNumber);
  }

  Widget _buildTranslationMode(QuranProvider provider, bool isDark) {
    final int surahNumber = _translationSurahId ?? 1;

    return Column(
      children: <Widget>[
        if (_isChromeVisible) _buildTranslationTopBar(surahNumber),
        Expanded(
          child: TranslationSurahView(
            key: ValueKey<int>(surahNumber),
            surahNumber: surahNumber,
            isTajweed: provider.isTajweed,
            isDarkMode: isDark,
            refreshToken: _translationRefreshToken,
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationTopBar(int surahNumber) {
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Surah sebelumnya',
            onPressed: surahNumber > 1
                ? () => _selectTranslationSurah(surahNumber - 1)
                : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                '${getSurahName(surahNumber)} • '
                '$surahNumber / $totalSurahCount',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Surah berikutnya',
            onPressed: surahNumber < totalSurahCount
                ? () => _selectTranslationSurah(surahNumber + 1)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Pilih surah',
            onPressed: _showTranslationSurahSearch,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Pengaturan Makna',
            onPressed: () => showMeaningSettingsDialog(
              context: context,
              settings: MeaningSettingsService.instance,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Berbagi Catatan',
            onPressed: () => showMeaningExportImportDialog(
              context: context,
              surah: surahNumber,
              ayah: 1,
              onImported: () {
                if (mounted) {
                  setState(() {
                    _translationRefreshToken++;
                  });
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Kembali ke Mushaf',
            onPressed: () =>
                _toggleTranslationMode(context.read<QuranProvider>()),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, QuranProvider provider) {
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: provider.prevPage,
          ),
          Expanded(
            child: Center(
              child: Text(
                'Halaman ${provider.currentPage} / ${provider.totalPages}',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: provider.nextPage,
          ),
          PopupMenuButton<_ReaderSearchAction>(
            icon: const Icon(Icons.search),
            tooltip: 'Cari halaman, surah, atau kalimat',
            onSelected: (_ReaderSearchAction action) {
              switch (action) {
                case _ReaderSearchAction.page:
                  _showPageSearch();
                  break;
                case _ReaderSearchAction.surah:
                  _showSurahSearch();
                  break;
                case _ReaderSearchAction.phrase:
                  _showTextSearch();
                  break;
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_ReaderSearchAction>>[
                  const PopupMenuItem<_ReaderSearchAction>(
                    value: _ReaderSearchAction.page,
                    child: Text('Cari Halaman'),
                  ),
                  const PopupMenuItem<_ReaderSearchAction>(
                    value: _ReaderSearchAction.surah,
                    child: Text('Cari Surah'),
                  ),
                  const PopupMenuItem<_ReaderSearchAction>(
                    value: _ReaderSearchAction.phrase,
                    child: Text('Cari Kalimat'),
                  ),
                ],
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.reorder),
            tooltip: 'Pilih Juz',
            onSelected: (int value) {
              final int? pageNumber = provider.pageForJuz(value);
              if (pageNumber != null) {
                unawaited(_navigateToPage(pageNumber));
              }
            },
            itemBuilder: (BuildContext context) => _buildJuzMenuItems(),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<int>> _buildJuzMenuItems() {
    return <PopupMenuEntry<int>>[
      for (int i = 1; i <= 30; i++)
        PopupMenuItem<int>(value: i, child: Text('Juz $i')),
    ];
  }

  Future<void> _showPageSearch() async {
    final TextEditingController controller = TextEditingController();
    String? errorMessage;
    final int? pageNumber = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Cari Halaman'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nomor halaman',
                      hintText: '1–604',
                    ),
                    onSubmitted: (_) => _submitPageSearch(
                      dialogContext,
                      controller,
                      setDialogState,
                      (String? error) => errorMessage = error,
                    ),
                  ),
                  if (errorMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () => _submitPageSearch(
                    dialogContext,
                    controller,
                    setDialogState,
                    (String? error) => errorMessage = error,
                  ),
                  child: const Text('Buka'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (pageNumber != null && mounted) {
      await _navigateToPage(pageNumber);
    }
  }

  void _submitPageSearch(
    BuildContext dialogContext,
    TextEditingController controller,
    StateSetter setDialogState,
    void Function(String?) updateError,
  ) {
    final int? pageNumber = int.tryParse(controller.text.trim());
    if (pageNumber == null || pageNumber < 1 || pageNumber > totalPagesCount) {
      setDialogState(() {
        updateError('Masukkan nomor halaman dari 1 sampai $totalPagesCount.');
      });
      return;
    }
    Navigator.pop(dialogContext, pageNumber);
  }

  Future<void> _showSurahSearch() async {
    final int? surahNumber = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => const SurahSearchDialog(),
    );
    if (surahNumber == null || !mounted) {
      return;
    }
    final int? pageNumber = context.read<QuranProvider>().pageForSurah(
      surahNumber,
    );
    if (pageNumber != null) {
      await _navigateToPage(pageNumber);
    }
  }

  Future<void> _showTextSearch() async {
    final QuranSearchMatch? match = await showDialog<QuranSearchMatch>(
      context: context,
      builder: (BuildContext context) => const QuranTextSearchDialog(),
    );
    if (match != null && mounted) {
      await _navigateToPage(getPageNumber(match.surah, match.ayah));
    }
  }

  Widget _buildBottomBar() {
    final QuranProvider provider = context.watch<QuranProvider>();
    return SizedBox(
      height: 40,
      child: Center(
        child: Text('Tajwid: ${provider.isTajweed ? 'Aktif' : 'Mati'}'),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF0F766E)),
            child: Center(
              child: Text(
                'Alquran',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Log & Monitoring Khatam'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => const LogAndKhatamScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.insights),
            title: const Text('Statistik Bacaan'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) =>
                      const ReadingStatisticsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Bookmark'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => const BookmarkTreeScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang Kami'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => const AboutScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAyahMenu(int surah, int ayah) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Salin Ayat'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_copyAyah(surah, ayah));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Bagikan Ayat'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_shareAyah(surah, ayah));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: const Text('Tandai Akhir Bacaan Hari Ini'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _markReadingAsFinished(surah, ayah);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: const Text('Tambahkan ke Bookmark'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _addBookmark(surah, ayah);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Ayah? _findAyah(int surah, int ayahNumber) {
    for (final QuranPage page in QuranRepository.instance.pages) {
      for (final Ayah verse in page.ayahs) {
        if (verse.surahNumber == surah && verse.ayahNumber == ayahNumber) {
          return verse;
        }
      }
    }
    return null;
  }

  String _formatAyah(Ayah ayah) {
    return '${ayah.othmanicAyah.trim()}\n\n'
        '${ayah.surahNameEn} (${ayah.surahNumber}:${ayah.ayahNumber})';
  }

  Future<void> _copyAyah(int surah, int ayahNumber) async {
    final Ayah? ayah = _findAyah(surah, ayahNumber);
    if (ayah == null) {
      _showAyahNotFound();
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: _formatAyah(ayah)));
    } on Exception catch (error, stackTrace) {
      _showAyahActionError('menyalin', error, stackTrace);
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Ayat berhasil disalin')));
  }

  Future<void> _shareAyah(int surah, int ayahNumber) async {
    final Ayah? ayah = _findAyah(surah, ayahNumber);
    if (ayah == null) {
      _showAyahNotFound();
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _formatAyah(ayah),
          subject: '${ayah.surahNameEn} ${ayah.surahNumber}:${ayah.ayahNumber}',
        ),
      );
    } on Exception catch (error, stackTrace) {
      _showAyahActionError('membagikan', error, stackTrace);
    }
  }

  void _showAyahNotFound() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Teks ayat tidak ditemukan')));
  }

  void _showAyahActionError(
    String action,
    Exception error,
    StackTrace stackTrace,
  ) {
    debugPrint('Gagal $action ayat: $error\n$stackTrace');
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Gagal $action ayat')));
  }

  Future<void> _markReadingAsFinished(int surah, int ayah) async {
    await DailyLogService.instance.markReadingAsFinished(
      surahId: surah,
      ayahId: ayah,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Log bacaan $surah:$ayah berhasil disimpan')),
    );
  }

  Future<void> _addBookmark(int surah, int ayah) async {
    final List<dynamic> nodes = await BookmarkService.instance.getNodes();
    if (!mounted) {
      return;
    }

    final int? nodeId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Pilih Kategori Bookmark'),
              ),
              for (final dynamic node in nodes)
                ListTile(
                  title: Text(node.name.toString()),
                  onTap: () async {
                    Navigator.pop(context, node.id);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (nodeId != null) {
      final int pageNumber = getPageNumber(surah, ayah);
      final bool wasAdded = await BookmarkService.instance.createItem(
        nodeId: nodeId,
        surahId: surah,
        ayahId: ayah,
        pageNumber: pageNumber,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasAdded
                ? 'Ayat berhasil ditambahkan ke bookmark'
                : 'Ayat ini sudah ada di kategori tersebut',
          ),
        ),
      );
    }
  }
}
