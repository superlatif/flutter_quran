import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
import 'package:qcf_quran_plus/src/services/get_page.dart'; // ignore: implementation_imports

/// Mengelola seluruh state pembaca Al-Qur'an.
class QuranProvider extends ChangeNotifier {
  QuranProvider() {
    _getPage.getQuran(totalPagesCount);
  }

  final GetPage _getPage = GetPage();
  final PageController pageController = PageController(initialPage: 0);

  int currentPage = 1;
  bool isTajweed = true;
  bool dualPage = false;
  bool isDarkMode = false;
  List<HighlightVerse> highlights = <HighlightVerse>[];

  int get totalPages => totalPagesCount;

  void goToPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > totalPages) {
      return;
    }
    pageController.animateToPage(
      pageNumber - 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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
    final List<Surah> surahs = _getPage.surahs;
    Surah? target;
    for (final Surah surah in surahs) {
      if (surah.index == surahNumber) {
        target = surah;
        break;
      }
    }
    if (target == null) {
      return;
    }
    goToPage(target.startPage);
  }

  void goToJuz(int juzNumber) {
    // Cari ayat pertama pada juz terkait.
    for (final Map<String, dynamic> juzEntry in juz) {
      if (int.parse(juzEntry['id'].toString()) == juzNumber) {
        final Map<dynamic, dynamic> verses = juzEntry['verses'];
        int? firstSurah;
        int? firstAyah;
        for (final MapEntry entry in verses.entries) {
          final int surah = int.parse(entry.key);
          final List<int> range = List<int>.from(entry.value);
          if (firstAyah == null || range[0] < firstAyah) {
            firstSurah = surah;
            firstAyah = range[0];
          }
        }
        if (firstAyah != null && firstSurah != null) {
          goToPage(getPageNumber(firstSurah, firstAyah));
        }
      }
    }
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
    isDarkMode = value;
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
