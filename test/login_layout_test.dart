import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_hero/features/auth/presentation/screens/login_page.dart';

void main() {
  testWidgets('login page should not overflow on a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 520);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
