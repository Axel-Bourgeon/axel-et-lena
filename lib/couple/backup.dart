import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud.dart';

/// Sauvegarde dans l'espace du couple des données locales de chacun
/// (réglages, statistiques des jeux), pour les retrouver après une
/// réinstallation : /couples/{code}/backups/{personne}.
class LocalBackup {
  LocalBackup._();

  /// Préfixes des clés sauvegardées.
  static const List<String> _prefixes = ['settings.', 'motdujour.'];

  /// Clés propres à ce téléphone, jamais restaurées depuis la sauvegarde.
  static const Set<String> _excluded = {'settings.me'};

  static const String _kLastHash = 'backup.lastHash';

  static bool _included(String key) => !_excluded.contains(key) && _prefixes.any(key.startsWith);

  /// Données à sauvegarder (types acceptés par Firestore).
  static Map<String, Object> collect(SharedPreferences prefs) {
    final out = <String, Object>{};
    for (final k in prefs.getKeys().where(_included)) {
      final v = prefs.get(k);
      if (v is List) {
        out[k] = v.cast<String>().toList();
      } else if (v != null) {
        out[k] = v;
      }
    }
    return out;
  }

  /// Envoie la sauvegarde si quelque chose a changé depuis la dernière fois.
  static Future<void> save(CoupleCloud cloud, String person) async {
    if (!cloud.paired) return;
    final prefs = await SharedPreferences.getInstance();
    final data = collect(prefs);
    final hash = jsonEncode(Map.fromEntries(data.entries.toList()..sort((a, b) => a.key.compareTo(b.key))));
    if (prefs.getString(_kLastHash) == hash) return;
    await cloud.backups.doc(person).set({'data': data, 'at': Timestamp.now()});
    await prefs.setString(_kLastHash, hash);
  }

  /// Restaure la sauvegarde de [person] (après avoir rejoint l'espace).
  /// Renvoie true si quelque chose a été restauré.
  static Future<bool> restore(CoupleCloud cloud, String person) async {
    final snap = await cloud.backups.doc(person).get();
    final data = snap.data()?['data'];
    if (data is! Map) return false;
    final prefs = await SharedPreferences.getInstance();
    await apply(prefs, data.cast<String, Object?>());
    return true;
  }

  static Future<void> apply(SharedPreferences prefs, Map<String, Object?> data) async {
    for (final e in data.entries) {
      if (!_included(e.key)) continue;
      final v = e.value;
      if (v is bool) {
        await prefs.setBool(e.key, v);
      } else if (v is int) {
        await prefs.setInt(e.key, v);
      } else if (v is double) {
        await prefs.setDouble(e.key, v);
      } else if (v is String) {
        await prefs.setString(e.key, v);
      } else if (v is List) {
        await prefs.setStringList(e.key, v.map((x) => '$x').toList());
      }
    }
  }
}
