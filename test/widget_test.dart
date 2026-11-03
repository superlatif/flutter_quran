import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

import 'package:quran2/main.dart';
import 'package:quran2/providers/quran_provider.dart';
import 'package:quran2/screens/quran_reader_screen.dart';
import 'package:quran2/screens/quran_search_dialogs.dart';

void main() {
  test('Quran navigation resolves page and juz without loading Quran data', () {
    final QuranProvider provider = QuranProvider();
    addTearDown(provider.dispose);

    expect(provider.pageForJuz(2), getPageNumber(2, 142));
    expect(provider.pageForJuz(3), getPageNumber(2, 253));
    expect(provider.pageForSurah(2), getPageNumber(2, 1));
    expect(provider.pageForJuz(31), isNull);
    expect(provider.pageForSurah(115), isNull);
  });

  test('Quran theme can switch between system, dark, and light modes', () {
    final QuranProvider provider = QuranProvider();
    addTearDown(provider.dispose);

    expect(provider.themeMode, ThemeMode.system);

    provider.setDarkMode(true);
    expect(provider.themeMode, ThemeMode.dark);

    provider.setDarkMode(false);
    expect(provider.themeMode, ThemeMode.light);
  });

  testWidgets('Quran navigation changes page without an animation', (
    WidgetTester tester,
  ) async {
    final QuranProvider provider = QuranProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PageView(
          controller: provider.pageController,
          children: List<Widget>.generate(
            provider.totalPages,
            (int index) => Text('Halaman ${index + 1}'),
          ),
        ),
      ),
    );

    provider.goToPage(5);

    expect(provider.pageController.page, 4);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Surah search uses the original name instead of translation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SurahSearchDialog())),
    );

    await tester.enterText(find.byType(TextField), 'Al Isra');
    await tester.pump();

    expect(find.text("Al Isra'"), findsOneWidget);
    expect(find.text('The Night Journey'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Night Journey');
    await tester.pump();

    expect(find.text('Surah tidak ditemukan.'), findsOneWidget);
  });

  test('Quran phrase search runs in an isolate', () async {
    final List<Map<String, dynamic>> matches = await compute(
      searchQuranPhrase,
      'بسم الله الرحمن الرحيم',
    );

    expect(
      matches.any(
        (Map<String, dynamic> match) =>
            match['sora'] == 1 && match['aya_no'] == 1,
      ),
      isTrue,
    );
  });

  testWidgets('AlquranApp opens the Quran reader immediately', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AlquranApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(QuranReaderScreen), findsOneWidget);
    expect(find.text('Alquran'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
  });

  testWidgets('Reader controls toggle when the page is tapped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AlquranApp());

    final Finder tapArea = find.byKey(
      const ValueKey<String>('quran-reader-tap-area'),
    );
    expect(tapArea, findsOneWidget);
    expect(find.text('Alquran'), findsNothing);

    await tester.tap(tapArea);
    await tester.pump();
    expect(find.text('Alquran'), findsOneWidget);

    await tester.tap(tapArea);
    await tester.pump();
    expect(find.text('Alquran'), findsNothing);
  });
}
