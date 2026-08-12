// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';

import 'package:shopping_hero/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    final sessionProvider = SessionProvider();
    final shoppingProvider = ShoppingProvider();
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(
      MyApp(
        sessionProvider: sessionProvider,
        shoppingProvider: shoppingProvider,
        themeProvider: themeProvider,
      ),
    );

    expect(find.text('Login'), findsOneWidget);
  });
}
