import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Person;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/settings.dart';
import 'backup.dart';
import 'cloud.dart';

/// Notifications des alertes du couple, sans serveur (offre Firebase gratuite) :
/// - appli ouverte ou en arrière-plan : écoute en direct de Firestore ;
/// - appli fermée : vérification par Android environ toutes les 15 minutes.
class CoupleNotifier {
  CoupleNotifier._();

  static const String _kLastSeen = 'couple.alerts.lastSeen';
  static const String _kLastPing = 'couple.pings.lastSeen';
  static const String _kMe = 'settings.me';
  static const String _task = 'couple-alerts';

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _pluginReady = false;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pingSub;

  static Future<void> _initPlugin() async {
    if (_pluginReady) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _pluginReady = true;
  }

  /// À appeler au démarrage et après avoir relié les téléphones.
  static Future<void> start(AppSettings settings) async {
    final me = settings.me;
    if (!CoupleCloud.configured || me == null) return;
    final cloud = await CoupleCloud.instance();
    if (cloud == null || !cloud.paired) return;
    await _initPlugin();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await Workmanager().initialize(coupleCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _task,
      _task,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    LocalBackup.save(cloud, me.name).catchError((Object _) {});

    final prefs = await SharedPreferences.getInstance();
    await _sub?.cancel();
    _sub = cloud.alerts.doc(me.other.name).snapshots().listen((s) => _check(s.data(), me.other, prefs));
    await _pingSub?.cancel();
    _pingSub = cloud.pings.doc(me.other.name).snapshots().listen((s) => _checkPing(s.data(), prefs));
  }

  /// Marque l'alerte reçue comme vue (affichée à l'écran).
  static Future<void> markSeen(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    if (at.millisecondsSinceEpoch > (prefs.getInt(_kLastSeen) ?? 0)) {
      await prefs.setInt(_kLastSeen, at.millisecondsSinceEpoch);
    }
  }

  static Future<void> _check(Map<String, dynamic>? data, Person from, SharedPreferences prefs) async {
    final at = data?['at'];
    if (at is! Timestamp) return;
    final ms = at.millisecondsSinceEpoch;
    final last = prefs.getInt(_kLastSeen);
    await prefs.setInt(_kLastSeen, ms > (last ?? 0) ? ms : last!);
    // Première fois sur ce téléphone : on ne ressort pas un vieux message.
    if (last == null || ms <= last) return;
    await _initPlugin();
    await _plugin.show(
      id: 1,
      title: 'Message de ${from.label}',
      body: (data!['text'] as String?) ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'couple_alerts',
          'Messages du couple',
          channelDescription: 'Alertes envoyées par l\'autre',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Notification des jeux (mot du jour réussi, à toi de jouer…).
  static Future<void> _checkPing(Map<String, dynamic>? data, SharedPreferences prefs) async {
    final at = data?['at'];
    if (at is! Timestamp) return;
    final ms = at.millisecondsSinceEpoch;
    final last = prefs.getInt(_kLastPing);
    await prefs.setInt(_kLastPing, ms > (last ?? 0) ? ms : last!);
    if (last == null || ms <= last) return;
    await _initPlugin();
    await _plugin.show(
      id: 2,
      title: (data!['title'] as String?) ?? 'Axel & Léna',
      body: (data['text'] as String?) ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'couple_games',
          'Jeux à deux',
          channelDescription: "Résultats et tours de jeu de l'autre",
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  /// Exécuté par Android en arrière-plan, appli fermée.
  static Future<bool> runInBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final me = Person.values.where((p) => p.name == prefs.getString(_kMe)).firstOrNull;
    if (me == null) return true;
    final cloud = await CoupleCloud.instance();
    if (cloud == null || !cloud.paired) return true;
    final snap = await cloud.alerts.doc(me.other.name).get(const GetOptions(source: Source.server));
    await _check(snap.data(), me.other, prefs);
    final ping = await cloud.pings.doc(me.other.name).get(const GetOptions(source: Source.server));
    await _checkPing(ping.data(), prefs);
    await LocalBackup.save(cloud, me.name);
    return true;
  }
}

@pragma('vm:entry-point')
void coupleCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      return await CoupleNotifier.runInBackground();
    } catch (_) {
      return false; // Android réessaiera plus tard
    }
  });
}
