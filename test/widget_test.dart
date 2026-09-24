import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studycompete/app.dart';

void main() {
  testWidgets('StudyCompeteApp builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: StudyCompeteApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
