import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quran2/screens/pegon_converter_screen.dart';
import 'package:quran2/services/pegon_engine.dart';

void main() {
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
}
