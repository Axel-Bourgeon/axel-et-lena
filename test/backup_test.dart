import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:axel_lena/couple/backup.dart';

void main() {
  test('sauvegarde : réglages et stats, sans l\'identité du téléphone', () async {
    SharedPreferences.setMockInitialValues({
      'settings.seedColor': 0xFF7C93B0,
      'settings.me': 'axel',
      'settings.hiddenTiles': ['discord'],
      'motdujour.streak': 4,
      'motdujour.dist': ['0', '1', '3', '0', '0', '0'],
      'couple.id': 'ABCDE23456',
      'couple.alerts.lastSeen': 123,
    });
    final prefs = await SharedPreferences.getInstance();
    final data = LocalBackup.collect(prefs);
    expect(data.keys.toSet(), {'settings.seedColor', 'settings.hiddenTiles', 'motdujour.streak', 'motdujour.dist'});
  });

  test('restauration sur un téléphone neuf', () async {
    SharedPreferences.setMockInitialValues({'settings.me': 'lena'});
    final prefs = await SharedPreferences.getInstance();
    await LocalBackup.apply(prefs, {
      'settings.seedColor': 0xFF8E7CB3,
      'settings.me': 'axel', // ignoré : l'identité reste celle du téléphone
      'settings.hiddenTiles': ['discord'],
      'motdujour.streak': 7,
      'couple.id': 'XXXXXXXXXX', // ignoré
    });
    expect(prefs.getInt('settings.seedColor'), 0xFF8E7CB3);
    expect(prefs.getString('settings.me'), 'lena');
    expect(prefs.getStringList('settings.hiddenTiles'), ['discord']);
    expect(prefs.getInt('motdujour.streak'), 7);
    expect(prefs.getString('couple.id'), isNull);
  });
}
