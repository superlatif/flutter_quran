import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quran2/screens/pegon_converter_screen.dart';
import 'package:quran2/services/pegon_engine.dart';
import 'package:quran2/services/pegon_spelling_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  testWidgets('Android Pegon converter shows the voice input control', (
    WidgetTester tester,
  ) async {
    final TargetPlatform? originalPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = originalPlatform;
    });

    await tester.runAsync(() async {
      await PegonEngine.instance.load();
    });
    await tester.pumpWidget(const MaterialApp(home: PegonConverterScreen()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('pegon-voice-input')),
      findsOneWidget,
    );
  });

  testWidgets('user can correct a conversion and reuse it', (
    WidgetTester tester,
  ) async {
    final TargetPlatform? originalPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = originalPlatform;
    });

    await tester.runAsync(() async {
      await PegonEngine.instance.load();
    });
    await tester.pumpWidget(const MaterialApp(home: PegonConverterScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('pegon-input')),
      'sejarah',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('pegon-fix-sejarah')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Perbaiki konversi'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('pegon-correction-input')),
      'سِيَرَة',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('pegon-correction-save')),
    );
    await tester.pumpAndSettle();

    expect(PegonEngine.instance.userCorrections['sejarah'], 'سِيَرَة');
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is SelectableText && widget.data == 'سِيَرَة',
      ),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await PegonEngine.instance.removeUserCorrection('sejarah');
    });
  });

  testWidgets('user can choose kaf and fa variants from settings', (
    WidgetTester tester,
  ) async {
    final PegonSpellingSettingsService settings =
        PegonSpellingSettingsService.instance;

    await tester.runAsync(() async {
      await PegonEngine.instance.load();
      await settings.setGSpelling(PegonGSpelling.kafDotAbove);
      await settings.setPSpelling(PegonPSpelling.veh);
    });

    await tester.pumpWidget(const MaterialApp(home: PegonConverterScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('pegon-input')),
      'pegawai',
    );
    await tester.pumpAndSettle();
    expect(_pegonOutput(tester), 'ڤڬاواي');

    await tester.tap(
      find.byKey(const ValueKey<String>('pegon-spelling-settings')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan Ejaan Pegon'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('pegon-g-spelling')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(PegonGSpelling.kafThreeDotsBelow.optionLabel),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('pegon-p-spelling')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PegonPSpelling.feh.optionLabel));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(_pegonOutput(tester), 'فڮاواي');

    await tester.runAsync(() async {
      await settings.setGSpelling(PegonGSpelling.kafDotAbove);
      await settings.setPSpelling(PegonPSpelling.veh);
    });
  });
}

String _pegonOutput(WidgetTester tester) {
  final SelectableText text = tester.widget<SelectableText>(
    find.byWidgetPredicate(
      (Widget widget) => widget is SelectableText,
    ),
  );
  return text.data ?? '';
}
