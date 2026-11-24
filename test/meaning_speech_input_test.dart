import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quran2/models/word_meaning.dart';
import 'package:quran2/services/meaning_settings_service.dart';
import 'package:quran2/widgets/meaning_dialogs.dart';

void main() {
  testWidgets('Android Makna Latin editor shows speech input', (
    WidgetTester tester,
  ) async {
    final TargetPlatform? originalPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = originalPlatform;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showWordMeaningEditor(
                  context: context,
                  surah: 1,
                  ayah: 1,
                  wordIndex: 0,
                  word: 'الله',
                  existing: const WordMeaning(
                    surah: 1,
                    ayah: 1,
                    wordIndex: 0,
                    meaningPegon: 'makna Pegon',
                    meaningLatin: 'makna Latin',
                  ),
                  settings: MeaningSettingsService.instance,
                );
              },
              child: const Text('Buka makna'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka makna'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('latin-voice-input')),
      findsOneWidget,
    );
    final TextField latinField = tester.widget<TextField>(
      find
          .ancestor(
            of: find.byKey(const ValueKey<String>('latin-voice-input')),
            matching: find.byType(TextField),
          )
          .first,
    );
    expect(latinField.controller?.text, 'makna Latin');
  });

  testWidgets('Android grouped Makna Latin editor shows speech input', (
    WidgetTester tester,
  ) async {
    final TargetPlatform? originalPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = originalPlatform;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showGroupMeaningDialog(
                  context: context,
                  surah: 1,
                  ayah: 1,
                  words: const <String>['الله', 'رب'],
                  meanings: const [],
                  settings: MeaningSettingsService.instance,
                );
              },
              child: const Text('Buka makna gabungan'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka makna gabungan'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('latin-voice-input')),
      findsOneWidget,
    );
  });
}
