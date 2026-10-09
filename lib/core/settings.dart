import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identifiant du serveur Discord ouvert par la tuile « Discord ».
/// À renseigner ici pour avoir une valeur par défaut (modifiable aussi dans Réglages).
const String kDefaultDiscordServerId = '1378749282177515722';

/// Date de début de notre histoire (compteur de l'accueil).
final DateTime kTogetherSince = DateTime.utc(2017, 6, 1);

/// Appli d'agenda ouverte par la tuile « Agenda ».
enum CalendarApp {
  google('Google Agenda', 'com.google.android.calendar', null),
  outlook('Outlook', 'com.microsoft.office.outlook', 'ms-outlook://events');

  const CalendarApp(this.label, this.package, this.deepLink);

  final String label;
  final String package;

  /// Lien ouvrant directement la vue agenda (Outlook s'ouvre sinon sur les mails).
  final String? deepLink;
}

/// Couleur de base par défaut (vert sauge doux).
const int kDefaultSeedColor = 0xFF6B8E7F;

/// Couleurs proposées dans les Réglages (tons doux et sobres).
const List<Color> kSeedChoices = <Color>[
  Color(0xFF6B8E7F), // sauge
  Color(0xFF7C93B0), // bleu brume
  Color(0xFF8E7CB3), // lavande
  Color(0xFFB07C8E), // vieux rose
  Color(0xFFC49A6C), // sable
  Color(0xFFB5715D), // terre cuite
  Color(0xFF5E9CA0), // lagon
  Color(0xFF7A7F87), // ardoise
];

const String _kSeedColorKey = 'settings.seedColor';
const String _kThemeModeKey = 'settings.themeMode';
const String _kDiscordKey = 'settings.discordServerId';
const String _kHiddenTilesKey = 'settings.hiddenTiles';
const String _kCalendarKey = 'settings.calendarApp';

class AppSettings extends ChangeNotifier {
  AppSettings._(
    this._prefs, {
    required int seedColor,
    required ThemeMode themeMode,
    required String discordServerId,
    required List<String> hiddenTiles,
    required CalendarApp calendarApp,
  })  : _seedColor = seedColor,
        _themeMode = themeMode,
        _discordServerId = discordServerId,
        _hiddenTiles = hiddenTiles,
        _calendarApp = calendarApp;

  final SharedPreferences _prefs;

  int _seedColor;
  ThemeMode _themeMode;
  String _discordServerId;
  List<String> _hiddenTiles;
  CalendarApp _calendarApp;

  /// Charge les réglages depuis le stockage local.
  static Future<AppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppSettings._(
      prefs,
      seedColor: prefs.getInt(_kSeedColorKey) ?? kDefaultSeedColor,
      themeMode: _themeModeFromString(prefs.getString(_kThemeModeKey)),
      discordServerId:
          prefs.getString(_kDiscordKey) ?? kDefaultDiscordServerId,
      hiddenTiles: List<String>.of(
        prefs.getStringList(_kHiddenTilesKey) ?? const <String>[],
      ),
      calendarApp: CalendarApp.values.firstWhere(
        (CalendarApp c) => c.name == prefs.getString(_kCalendarKey),
        orElse: () => CalendarApp.google,
      ),
    );
  }

  static ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  int get seedColor => _seedColor;
  ThemeMode get themeMode => _themeMode;
  String get discordServerId => _discordServerId;
  List<String> get hiddenTiles => List<String>.unmodifiable(_hiddenTiles);

  CalendarApp get calendarApp => _calendarApp;

  bool isHidden(String id) => _hiddenTiles.contains(id);

  Future<void> setCalendarApp(CalendarApp value) async {
    if (value == _calendarApp) return;
    _calendarApp = value;
    notifyListeners();
    await _prefs.setString(_kCalendarKey, value.name);
  }

  Future<void> setSeedColor(int value) async {
    if (value == _seedColor) return;
    _seedColor = value;
    notifyListeners();
    await _prefs.setInt(_kSeedColorKey, value);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
    await _prefs.setString(_kThemeModeKey, _themeModeToString(value));
  }

  Future<void> setDiscordServerId(String value) async {
    final String trimmed = value.trim();
    if (trimmed == _discordServerId) return;
    _discordServerId = trimmed;
    notifyListeners();
    await _prefs.setString(_kDiscordKey, trimmed);
  }

  Future<void> hideTile(String id) async {
    if (_hiddenTiles.contains(id)) return;
    _hiddenTiles = <String>[..._hiddenTiles, id];
    notifyListeners();
    await _prefs.setStringList(_kHiddenTilesKey, _hiddenTiles);
  }

  Future<void> showTile(String id) async {
    if (!_hiddenTiles.contains(id)) return;
    _hiddenTiles = _hiddenTiles.where((String e) => e != id).toList();
    notifyListeners();
    await _prefs.setStringList(_kHiddenTilesKey, _hiddenTiles);
  }
}
