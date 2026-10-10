import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:axel_lena/core/settings.dart';
import 'package:axel_lena/home/home_page.dart';

void main() {
  testWidgets('accueil sans débordement sur un écran de téléphone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: HomePage(settings: settings)));
    await tester.pumpAndSettle();

    expect(find.text('Axel & Léna'), findsOneWidget);
    expect(find.textContaining('Ensemble depuis'), findsOneWidget);
    expect(find.text('Fourmis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
