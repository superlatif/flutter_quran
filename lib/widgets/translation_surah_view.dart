import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

import '../services/ayah_translation_service.dart';

/// Menampilkan satu surah sebagai daftar ayat dengan kolom terjemah yang dapat
/// diedit di bawah setiap ayat.
class TranslationSurahView extends StatefulWidget {
  const TranslationSurahView({
    super.key,
    required this.surahNumber,
    required this.isTajweed,
    required this.isDarkMode,
  });

  final int surahNumber;
  final bool isTajweed;
  final bool isDarkMode;

  @override
  State<TranslationSurahView> createState() => _TranslationSurahViewState();
}

class _TranslationSurahViewState extends State<TranslationSurahView> {
  Map<int, String> _translations = <int, String>{};
  bool _isLoading = true;
  String? _error;
  int _fontLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTranslations());
    unawaited(_loadSurahFonts());
  }

  @override
  void didUpdateWidget(covariant TranslationSurahView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahNumber != widget.surahNumber) {
      _fontLoadGeneration++;
      unawaited(_loadTranslations());
      unawaited(_loadSurahFonts());
    }
  }

  @override
  void dispose() {
    _fontLoadGeneration++;
    super.dispose();
  }

  Future<void> _loadTranslations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final Map<int, String> translations = await AyahTranslationService
          .instance
          .getTranslationsForSurah(widget.surahNumber);
      if (!mounted) {
        return;
      }
      setState(() {
        _translations = translations;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Gagal memuat terjemahan surah: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Terjemahan belum berhasil dimuat. Silakan coba lagi.';
      });
    }
  }

  /// Memuat font QCF untuk seluruh halaman yang dipakai surah ini agar teks
  /// Arab tetap tampil dengan bentuk Mushaf yang benar.
  Future<void> _loadSurahFonts() async {
    final int generation = ++_fontLoadGeneration;
    final int firstPage = getPageNumber(widget.surahNumber, 1);
    final int lastPage = getPageNumber(
      widget.surahNumber,
      getVerseCount(widget.surahNumber),
    );

    for (int page = firstPage; page <= lastPage; page++) {
      if (!mounted || generation != _fontLoadGeneration) {
        return;
      }
      if (QcfFontLoader.isFontLoaded(page)) {
        continue;
      }

      try {
        await QcfFontLoader.ensureFontLoaded(page);
      } catch (error) {
        debugPrint('Gagal memuat font halaman $page: $error');
        continue;
      }

      if (!mounted || generation != _fontLoadGeneration) {
        return;
      }
      // Teks yang sudah terlanjur dibuat dengan font cadangan perlu dibangun
      // ulang setelah font halaman selesai didaftarkan.
      setState(() {});
    }
  }

  Widget _buildAyah(
    BuildContext context,
    int surahNumber,
    int verseNumber,
    int pageNumber,
    Widget ayahWidget,
    bool isHighlighted,
    Color highlightColor,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted
            ? highlightColor.withValues(alpha: 0.3)
            : colors.surfaceContainerHighest.withValues(
                alpha: widget.isDarkMode ? 0.28 : 0.5,
              ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ayahWidget,
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: _AyahTranslationField(
              key: ValueKey<String>('translation_${surahNumber}_$verseNumber'),
              surahId: surahNumber,
              ayahId: verseNumber,
              initialText: _translations[verseNumber] ?? '',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.translate, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadTranslations,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return QuranSurahListView(
      surahNumber: widget.surahNumber,
      highlights: const <HighlightVerse>[],
      isTajweed: widget.isTajweed,
      isDarkMode: widget.isDarkMode,
      ayahBuilder: _buildAyah,
    );
  }
}

class _AyahTranslationField extends StatefulWidget {
  const _AyahTranslationField({
    super.key,
    required this.surahId,
    required this.ayahId,
    required this.initialText,
  });

  final int surahId;
  final int ayahId;
  final String initialText;

  @override
  State<_AyahTranslationField> createState() => _AyahTranslationFieldState();
}

class _AyahTranslationFieldState extends State<_AyahTranslationField> {
  static const Duration _saveDebounce = Duration(milliseconds: 600);

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounceTimer;
  late String _lastSavedText;

  @override
  void initState() {
    super.initState();
    _lastSavedText = widget.initialText;
    _controller = TextEditingController(text: _lastSavedText);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    if (_controller.text != _lastSavedText) {
      unawaited(_persist(_controller.text));
    }
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      unawaited(_persist(_controller.text));
    }
  }

  void _handleChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_saveDebounce, () {
      unawaited(_persist(_controller.text));
    });
  }

  Future<void> _persist(String text) async {
    _debounceTimer?.cancel();
    if (text == _lastSavedText) {
      return;
    }

    try {
      await AyahTranslationService.instance.saveTranslation(
        surahId: widget.surahId,
        ayahId: widget.ayahId,
        translation: text,
      );
      _lastSavedText = text;
    } catch (error, stackTrace) {
      debugPrint(
        'Gagal menyimpan terjemahan ${widget.surahId}:${widget.ayahId}: '
        '$error\n$stackTrace',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _handleChanged,
      minLines: 2,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        labelText: 'Terjemah',
        hintText: 'Tulis terjemah ayat ini...',
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
