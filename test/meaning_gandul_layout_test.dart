import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quran2/models/word_meaning.dart';
import 'package:quran2/services/meaning_settings_service.dart';
import 'package:quran2/widgets/meaning_gandul_layout.dart';

void main() {
  testWidgets('shows Pegon without Latin when both meanings are available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: MeaningGandulLayout(
              words: const <String>['كلمة'],
              meanings: const <WordMeaning>[
                WordMeaning(
                  surah: 1,
                  ayah: 1,
                  wordIndex: 0,
                  meaningPegon: 'makna Pegon',
                  meaningLatin: 'makna Latin',
                ),
              ],
              displayScript: DisplayScript.both,
              meaningStyle: MeaningStyle.block,
              showBaseMeaning: true,
              onWordTap: (_) {},
              onGroupTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('makna Pegon'), findsOneWidget);
    expect(find.text('makna Latin'), findsNothing);
  });

  testWidgets('shows Latin as fallback when Pegon is not available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: MeaningGandulLayout(
              words: const <String>['كلمة'],
              meanings: const <WordMeaning>[
                WordMeaning(
                  surah: 1,
                  ayah: 1,
                  wordIndex: 0,
                  meaningLatin: 'makna Latin',
                ),
              ],
              displayScript: DisplayScript.both,
              meaningStyle: MeaningStyle.block,
              showBaseMeaning: true,
              onWordTap: (_) {},
              onGroupTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('makna Latin'), findsOneWidget);
  });
}
