import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
// ignore: implementation_imports
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/quran_provider.dart';
import '../models/ayah_comment.dart';
import '../services/ayah_comment_service.dart';
import '../services/bookmark_service.dart';
import '../services/daily_log_service.dart';
import '../services/offline_data_service.dart';
import 'bookmark_tree_screen.dart';
import 'log_khatam_screen.dart';
import 'quran_search_dialogs.dart';

enum _ReaderSearchAction { page, surah, phrase }

enum _CommentPanelPlacement { abovePage, belowPage }

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

class _AyahCommentPanelState {
  const _AyahCommentPanelState({
    this.comment,
    this.isVisible = false,
    this.anchorY = 0,
    this.placement = _CommentPanelPlacement.belowPage,
  });

  final AyahComment? comment;
  final bool isVisible;
  final double anchorY;
  final _CommentPanelPlacement placement;
}

class _AyahCommentDialog extends StatefulWidget {
  const _AyahCommentDialog({
    required this.surah,
    required this.ayah,
    this.initialComment,
  });

  final int surah;
  final int ayah;
  final String? initialComment;

  @override
  State<_AyahCommentDialog> createState() => _AyahCommentDialogState();
}

class _AyahCommentDialogState extends State<_AyahCommentDialog> {
  late final TextEditingController _controller;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialComment ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.initialComment == null ? 'Tambah' : 'Edit'} Komentar '
        '${getSurahNameEnglish(widget.surah)} ${widget.surah}:${widget.ayah}',
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Tulis komentar untuk ayat ini',
            border: OutlineInputBorder(),
          ),
          validator: (String? value) => value == null || value.trim().isEmpty
              ? 'Komentar tidak boleh kosong'
              : null,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
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
  bool _isPreparingReader = true;
  String? _readerLoadError;
  final ValueNotifier<_OfflineDataState> _offlineData =
      ValueNotifier<_OfflineDataState>(const _OfflineDataState());
  final ValueNotifier<_AyahCommentPanelState> _commentPanelState =
      ValueNotifier<_AyahCommentPanelState>(const _AyahCommentPanelState());

  @override
  void initState() {
    super.initState();
    unawaited(_prepareReader());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshOfflinePages());
    });
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
  }

  @override
  void dispose() {
    _offlineData.dispose();
    _commentPanelState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QuranProvider provider = context.watch<QuranProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text('Alquran'),
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
                    onPressed:
                        offlineData.isScanning ||
                            offlineData.isDownloading ||
                            percentage == 100
                        ? null
                        : offlineData.error != null
                        ? _refreshOfflinePages
                        : _downloadAllOfflinePages,
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
                            valueColor: const AlwaysStoppedAnimation<Color>(
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
                  builder: (BuildContext context) => const BookmarkTreeScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: isDark
                ? 'Beralih ke mode terang'
                : 'Beralih ke mode gelap',
            onPressed: () => provider.setDarkMode(!isDark),
          ),
          ValueListenableBuilder<_AyahCommentPanelState>(
            valueListenable: _commentPanelState,
            builder:
                (
                  BuildContext context,
                  _AyahCommentPanelState panelState,
                  Widget? child,
                ) => IconButton(
                  icon: Icon(
                    panelState.isVisible
                        ? Icons.comment
                        : Icons.comments_disabled_outlined,
                  ),
                  tooltip: panelState.comment == null
                      ? 'Pilih ayat untuk menampilkan komentar'
                      : panelState.isVisible
                      ? 'Sembunyikan komentar ayat'
                      : 'Tampilkan komentar ayat',
                  onPressed: panelState.comment == null
                      ? null
                      : () {
                          _commentPanelState.value = _AyahCommentPanelState(
                            comment: panelState.comment,
                            isVisible: !panelState.isVisible,
                            anchorY: panelState.anchorY,
                            placement: panelState.placement,
                          );
                        },
                ),
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
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Column(
              children: <Widget>[
                ValueListenableBuilder<_AyahCommentPanelState>(
                  valueListenable: _commentPanelState,
                  builder:
                      (
                        BuildContext context,
                        _AyahCommentPanelState panelState,
                        Widget? child,
                      ) {
                        if (!panelState.isVisible ||
                            panelState.comment == null ||
                            panelState.placement !=
                                _CommentPanelPlacement.abovePage) {
                          return const SizedBox.shrink();
                        }
                        return _buildAyahCommentPanel(panelState);
                      },
                ),
                Expanded(
                  child: _readerLoadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.menu_book_outlined, size: 48),
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
                      : _isPreparingReader || !QuranRepository.instance.isReady
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
                                  deferNewPages: true,
                                  deferDelay: const Duration(milliseconds: 50),
                                  onPageChanged: (int? pageNumber) {
                                    if (pageNumber != null) {
                                      _handlePageChanged(provider, pageNumber);
                                    }
                                  },
                                  onLongPress:
                                      (
                                        int surah,
                                        int ayah,
                                        LongPressStartDetails details,
                                      ) {
                                        _showAyahMenu(surah, ayah, details);
                                      },
                                  topBar: _buildTopBar(context, provider),
                                  bottomBar: _buildBottomBar(),
                                );
                              },
                        ),
                ),
                ValueListenableBuilder<_AyahCommentPanelState>(
                  valueListenable: _commentPanelState,
                  builder:
                      (
                        BuildContext context,
                        _AyahCommentPanelState panelState,
                        Widget? child,
                      ) {
                        if (!panelState.isVisible ||
                            panelState.comment == null ||
                            panelState.placement !=
                                _CommentPanelPlacement.belowPage) {
                          return const SizedBox.shrink();
                        }
                        return _buildAyahCommentPanel(panelState);
                      },
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
    );
  }

  Widget _buildAyahCommentPanel(_AyahCommentPanelState panelState) {
    final AyahComment comment = panelState.comment!;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: colorScheme.secondaryContainer,
      child: SizedBox(
        height: 142,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Komentar • ${getSurahNameEnglish(comment.surahId)} '
                      '${comment.surahId}:${comment.ayahId}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit komentar',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => unawaited(
                      _editAyahComment(
                        comment.surahId,
                        comment.ayahId,
                        panelState.anchorY,
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(child: Text(comment.comment)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePageChanged(QuranProvider provider, int pageNumber) {
    provider.handlePageChanged(pageNumber);
    final AyahComment? selectedComment = _commentPanelState.value.comment;
    if (selectedComment != null &&
        getPageNumber(selectedComment.surahId, selectedComment.ayahId) !=
            pageNumber) {
      _commentPanelState.value = const _AyahCommentPanelState();
    }
    if (!QcfFontLoader.isFontLoaded(pageNumber)) {
      unawaited(_downloadPageFont(pageNumber, showSuccess: false));
    }
  }

  bool _isFontLoading(int pageNumber) => _loadingFontPage == pageNumber;

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
    setState(() {
      _navigationTargetPage = pageNumber;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!QcfFontLoader.isFontLoaded(pageNumber)) {
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
      if (mounted) {
        setState(() {
          _navigationTargetPage = null;
        });
      }
    }
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
        ],
      ),
    );
  }

  void _showAyahMenu(int surah, int ayah, LongPressStartDetails details) {
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
                  leading: const Icon(Icons.edit_note),
                  title: const Text('Tampilkan / Beri Komentar'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(
                      _openAyahComment(surah, ayah, details.globalPosition.dy),
                    );
                  },
                ),
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

  Future<void> _openAyahComment(int surah, int ayah, double anchorY) async {
    AyahComment? comment;
    try {
      comment = await AyahCommentService.instance.getComment(
        surahId: surah,
        ayahId: ayah,
      );
    } on Exception catch (error, stackTrace) {
      _showCommentError('memuat', error, stackTrace);
      return;
    }

    if (!mounted) {
      return;
    }

    if (comment == null) {
      await _editAyahComment(surah, ayah, anchorY);
      return;
    }

    _commentPanelState.value = _AyahCommentPanelState(
      comment: comment,
      anchorY: anchorY,
      placement: _commentPlacementForAnchor(anchorY),
      isVisible: true,
    );
  }

  Future<void> _editAyahComment(int surah, int ayah, double anchorY) async {
    AyahComment? existingComment;
    try {
      existingComment = await AyahCommentService.instance.getComment(
        surahId: surah,
        ayahId: ayah,
      );
    } on Exception catch (error, stackTrace) {
      _showCommentError('memuat', error, stackTrace);
      return;
    }

    if (!mounted) {
      return;
    }

    final String? comment = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _AyahCommentDialog(
        surah: surah,
        ayah: ayah,
        initialComment: existingComment?.comment,
      ),
    );

    if (comment == null) {
      return;
    }

    try {
      await AyahCommentService.instance.saveComment(
        surahId: surah,
        ayahId: ayah,
        comment: comment,
      );
    } on Exception catch (error, stackTrace) {
      _showCommentError('menyimpan', error, stackTrace);
      return;
    }

    if (!mounted) {
      return;
    }

    _commentPanelState.value = _AyahCommentPanelState(
      comment: AyahComment(
        surahId: surah,
        ayahId: ayah,
        comment: comment,
        updatedAt: DateTime.now(),
      ),
      anchorY: anchorY,
      placement: _commentPlacementForAnchor(anchorY),
      isVisible: false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Komentar tersimpan. Tekan tombol komentar untuk menampilkannya.',
        ),
      ),
    );
  }

  _CommentPanelPlacement _commentPlacementForAnchor(double anchorY) {
    return anchorY >= MediaQuery.sizeOf(context).height / 2
        ? _CommentPanelPlacement.abovePage
        : _CommentPanelPlacement.belowPage;
  }

  void _showCommentError(
    String action,
    Exception error,
    StackTrace stackTrace,
  ) {
    debugPrint('Gagal $action komentar ayat: $error\n$stackTrace');
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Gagal $action komentar ayat')));
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
