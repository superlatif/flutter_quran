import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

/// Mengelola seluruh state pembaca Al-Qur'an.
class QuranProvider extends ChangeNotifier {
  final PageController pageController = PageController(initialPage: 0);

  int currentPage = 1;
  bool isTajweed = true;
  bool dualPage = false;
  ThemeMode themeMode = ThemeMode.system;
  List<HighlightVerse> highlights = <HighlightVerse>[];

  int get totalPages => totalPagesCount;

  void goToPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > totalPages) {
      return;
    }
    pageController.jumpToPage(pageNumber - 1);
  }

  void nextPage() {
    goToPage(currentPage + 1);
  }

  void prevPage() {
    goToPage(currentPage - 1);
  }

  void handlePageChanged(int pageNumber) {
    currentPage = pageNumber;
    notifyListeners();
  }

  void goToSurah(int surahNumber) {
    final int? pageNumber = pageForSurah(surahNumber);
    if (pageNumber == null) {
      return;
    }
    goToPage(pageNumber);
  }

  void goToJuz(int juzNumber) {
    final int? pageNumber = pageForJuz(juzNumber);
    if (pageNumber != null) {
      goToPage(pageNumber);
    }
  }

  int? pageForSurah(int surahNumber) {
    if (surahNumber < 1 || surahNumber > totalSurahCount) {
      return null;
    }
    return getPageNumber(surahNumber, 1);
  }

  int? pageForJuz(int juzNumber) {
    for (final Map<String, dynamic> juzEntry in juz) {
      if (juzEntry['id'] == juzNumber) {
        final Map<dynamic, dynamic> verses = juzEntry['verses'];
        if (verses.isEmpty) {
          return null;
        }
        final MapEntry<dynamic, dynamic> firstVerse = verses.entries.first;
        final int surahNumber = int.parse(firstVerse.key.toString());
        final List<int> range = List<int>.from(firstVerse.value);
        return getPageNumber(surahNumber, range.first);
      }
    }
    return null;
  }

  void toggleTajweed() {
    isTajweed = !isTajweed;
    notifyListeners();
  }

  void setDualPage(bool value) {
    dualPage = value;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    themeMode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void addHighlight({
    required int surah,
    required int verseNumber,
    required int page,
    required Color color,
  }) {
    final HighlightVerse highlight = HighlightVerse(
      surah: surah,
      verseNumber: verseNumber,
      page: page,
      color: color,
    );
    final List<HighlightVerse> existing = List<HighlightVerse>.from(highlights);
    existing.add(highlight);
    highlights = existing;
    notifyListeners();
  }

  void clearHighlights() {
    highlights.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
