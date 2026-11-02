import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran2/main.dart';

void main() {
  testWidgets('AlquranApp renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AlquranApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
