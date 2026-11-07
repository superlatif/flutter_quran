import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quran2/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});

    const MethodChannel pathProvider = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    final Directory tempDirectory = Directory.systemTemp.createTempSync(
      'quran_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (MethodCall call) async {
          return tempDirectory.path;
        });
  });

  testWidgets('translation mode shows the meaning toolbar', (
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

    final Finder translate = find.byIcon(Icons.history_edu);
    expect(translate, findsOneWidget);

    await tester.tap(translate);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await tester.pump();

    expect(find.textContaining('belum berhasil'), findsNothing);
    expect(find.byTooltip('Berbagi Catatan'), findsOneWidget);
    expect(find.byTooltip('Pengaturan Makna'), findsOneWidget);
    expect(find.textContaining('Makna Gandul'), findsWidgets);
  });
}
