import 'package:flutter/material.dart';

import 'core/settings.dart';
import 'home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppSettings settings = await AppSettings.load();
  runApp(AxelLenaApp(settings));
}

class AxelLenaApp extends StatelessWidget {
  const AxelLenaApp(this.settings, {super.key});

  final AppSettings settings;

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(settings.seedColor),
        brightness: brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Axel & Léna',
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: settings.themeMode,
          home: HomePage(settings: settings),
        );
      },
    );
  }
}
