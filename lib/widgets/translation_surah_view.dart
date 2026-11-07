import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

import '../models/verse_note.dart';
import '../models/word_meaning.dart';
import '../services/database_service.dart';
import '../services/meaning_settings_service.dart';
import '../utils/quran_words.dart';
import 'meaning_dialogs.dart';
import 'meaning_gandul_layout.dart';

/// Menampilkan satu surah sebagai daftar ayat beserta makna gandul
/// Pegon–Latin per kata dan catatan per ayat.
class TranslationSurahView extends StatefulWidget {
  const TranslationSurahView({
    super.key,
    required this.surahNumber,
    required this.isTajweed,
    required this.isDarkMode,
    this.refreshToken = 0,
  });

  final int surahNumber;
  final bool isTajweed;
  final bool isDarkMode;
  final int refreshToken;

  @override
  State<TranslationSurahView> createState() => _TranslationSurahViewState();
}

class _TranslationSurahViewState extends State<TranslationSurahView> {
  final MeaningSettingsService _settings = MeaningSettingsService.instance;

  Map<int, List<WordMeaning>> _meaningsByAyah = <int, List<WordMeaning>>{};
  Map<int, List<VerseNote>> _notesByAyah = <int, List<VerseNote>>{};
  bool _isLoading = true;
  String? _error;
  int _fontLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_handleSettingsChanged);
    unawaited(_loadData());
    unawaited(_loadSurahFonts());
  }

  @override
  void didUpdateWidget(covariant TranslationSurahView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahNumber != widget.surahNumber ||
        oldWidget.refreshToken != widget.refreshToken) {
      _fontLoadGeneration++;
      unawaited(_loadData());
      unawaited(_loadSurahFonts());
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_handleSettingsChanged);
    _fontLoadGeneration++;
    super.dispose();
  }

  void _handleSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _settings.load();
      final List<WordMeaning> meanings = await DatabaseService.instance
          .getWordMeaningsForSurah(widget.surahNumber);
      final List<VerseNote> notes = await DatabaseService.instance
          .getVerseNotesForSurah(widget.surahNumber);

      final Map<int, List<WordMeaning>> meaningsByAyah =
          <int, List<WordMeaning>>{};
      for (final WordMeaning meaning in meanings) {
        meaningsByAyah
            .putIfAbsent(meaning.ayah, () => <WordMeaning>[])
            .add(meaning);
      }

      final Map<int, List<VerseNote>> notesByAyah = <int, List<VerseNote>>{};
      for (final VerseNote note in notes) {
        notesByAyah.putIfAbsent(note.ayah, () => <VerseNote>[]).add(note);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _meaningsByAyah = meaningsByAyah;
        _notesByAyah = notesByAyah;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Gagal memuat makna gandul surah: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Makna gandul belum berhasil dimuat. Silakan coba lagi.';
      });
    }
  }

  Future<void> _reloadAyah(int ayah) async {
    try {
      final List<WordMeaning> meanings = await DatabaseService.instance
          .getWordMeanings(surah: widget.surahNumber, ayah: ayah);
      final List<VerseNote> notes = await DatabaseService.instance
          .getVerseNotes(surah: widget.surahNumber, ayah: ayah);
      if (!mounted) {
        return;
      }
      setState(() {
        _meaningsByAyah[ayah] = meanings;
        _notesByAyah[ayah] = notes;
      });
    } catch (error, stackTrace) {
      debugPrint('Gagal memuat ulang makna ayat: $error\n$stackTrace');
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
      setState(() {});
    }
  }

  WordMeaning? _findMeaning(int ayah, int wordIndex) {
    final List<WordMeaning> meanings =
        _meaningsByAyah[ayah] ?? const <WordMeaning>[];
    for (final WordMeaning meaning in meanings) {
      if (meaning.wordIndex == wordIndex) {
        return meaning;
      }
    }
    return null;
  }

  Future<void> _editWord({
    required int ayah,
    required List<String> words,
    required int wordIndex,
  }) async {
    final bool? changed = await showWordMeaningEditor(
      context: context,
      surah: widget.surahNumber,
      ayah: ayah,
      wordIndex: wordIndex,
      word: words[wordIndex],
      existing: _findMeaning(ayah, wordIndex),
      settings: _settings,
    );
    if (changed == true) {
      await _reloadAyah(ayah);
    }
  }

  Future<void> _openGroup({
    required int ayah,
    required List<String> words,
    WordMeaning? initialGroup,
  }) async {
    final bool? changed = await showGroupMeaningDialog(
      context: context,
      surah: widget.surahNumber,
      ayah: ayah,
      words: words,
      meanings: _meaningsByAyah[ayah] ?? const <WordMeaning>[],
      settings: _settings,
      initialGroup: initialGroup,
    );
    if (changed == true) {
      await _reloadAyah(ayah);
    }
  }

  Future<void> _openNotes(int ayah) async {
    await showVerseNotesDialog(
      context: context,
      surah: widget.surahNumber,
      ayah: ayah,
      settings: _settings,
      onChanged: () => unawaited(_reloadAyah(ayah)),
    );
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
    final List<String> words = getAyahWords(surahNumber, verseNumber);
    final List<WordMeaning> meanings =
        _meaningsByAyah[verseNumber] ?? const <WordMeaning>[];
    final List<VerseNote> notes =
        _notesByAyah[verseNumber] ?? const <VerseNote>[];
    final bool hasGroup = meanings.any(
      (WordMeaning meaning) => meaning.isGroupPrimary,
    );

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
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$verseNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: hasGroup ? 'Kelola Makna Gabungan' : 'Gabungkan Makna',
                visualDensity: VisualDensity.compact,
                icon: Icon(hasGroup ? Icons.link : Icons.link_outlined),
                color: hasGroup ? colors.primary : null,
                onPressed: words.length < 2
                    ? null
                    : () => _openGroup(ayah: verseNumber, words: words),
              ),
              IconButton(
                tooltip: 'Catatan Ayat',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  notes.isEmpty ? Icons.note_add_outlined : Icons.sticky_note_2,
                ),
                color: notes.isEmpty ? null : colors.primary,
                onPressed: () => _openNotes(verseNumber),
              ),
            ],
          ),
          ayahWidget,
          const Divider(height: 20),
          MeaningGandulLayout(
            words: words,
            meanings: meanings,
            displayScript: _settings.displayScript,
            meaningStyle: _settings.meaningStyle,
            showBaseMeaning: _settings.showBaseMeaning,
            onWordTap: (int wordIndex) => _editWord(
              ayah: verseNumber,
              words: words,
              wordIndex: wordIndex,
            ),
            onGroupTap: (WordMeaning group) => _openGroup(
              ayah: verseNumber,
              words: words,
              initialGroup: group,
            ),
          ),
          if (notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: notes
                      .map(
                        (VerseNote note) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: colors.secondaryContainer.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _openNotes(verseNumber),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      note.noteType.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: colors.onSecondaryContainer,
                                      ),
                                    ),
                                    if (note.contentPegon?.isNotEmpty ?? false)
                                      Text(
                                        note.contentPegon!,
                                        textDirection: TextDirection.rtl,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.8,
                                        ),
                                      ),
                                    if (note.contentLatin?.isNotEmpty ?? false)
                                      Text(
                                        note.contentLatin!,
                                        textDirection: TextDirection.ltr,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    if (note.reference?.isNotEmpty ?? false)
                                      Text(
                                        note.reference!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: colors.outline,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
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
                onPressed: _loadData,
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
