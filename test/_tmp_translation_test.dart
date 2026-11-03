import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quran2/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('translation mode opens an editable field', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AlquranApp());
    await tester.tap(
      find.byKey(const ValueKey<String>('quran-reader-tap-area')),
    );
    await tester.pump();

    final Finder translate = find.byIcon(Icons.translate);
    expect(translate, findsOneWidget);

    await tester.tap(translate);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await tester.pump();

    debugPrint(
      'textfields: ${find.byType(TextField).evaluate().length}',
    );
    debugPrint(
      'progress: ${find.byType(CircularProgressIndicator).evaluate().length}',
    );
    debugPrint(
      'error: ${find.textContaining('belum berhasil').evaluate().length}',
    );
    expect(find.byType(TextField), findsWidgets);
  });
}
