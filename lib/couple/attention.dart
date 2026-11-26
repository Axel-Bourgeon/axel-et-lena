import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/settings.dart';
import '../games/motdujour/engine.dart';
import 'cloud.dart';

/// Tuiles de l'accueil qui doivent clignoter doucement parce que l'autre
/// attend quelque chose de nous : un message pas encore lu, notre tour aux
/// Mots en croix, le mot du jour qu'il ou elle a déjà fini.
class Attention extends ChangeNotifier {
  Attention._();
  static final Attention instance = Attention._();

  static const String _kOpened = 'couple.alerts.opened';

  final List<StreamSubscription<Object?>> _subs = [];
  Person? _me;
  SharedPreferences? _prefs;

  DateTime? _lastIncoming;
  bool _croixTurn = false;
  bool _motDone = false; // l'autre a fini le mot du jour…
  bool _motMine = false; // … et moi aussi ?

  Set<String> get ids => {
        if (_messagesUnread) 'messages',
        if (_croixTurn) 'croix',
        if (_motDone && !_motMine) 'motdujour',
      };

  bool get _messagesUnread {
    final at = _lastIncoming;
    if (at == null) return false;
    final opened = _prefs?.getInt(_kOpened);
    // Première fois sur ce téléphone : on ne fait pas clignoter un vieux message.
    if (opened == null) {
      _prefs?.setInt(_kOpened, at.millisecondsSinceEpoch);
      return false;
    }
    return at.millisecondsSinceEpoch > opened;
  }

  bool has(String id) => ids.contains(id);

  /// À appeler au démarrage et après avoir relié les téléphones.
  Future<void> start(CoupleCloud cloud, Person me) async {
    if (_me == me && _subs.isNotEmpty) return;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _me = me;
    _prefs = await SharedPreferences.getInstance();
    void onError(Object _) {}
    _subs.add(cloud.alerts.doc(me.other.name).snapshots().listen((s) {
      _lastIncoming = (s.data()?['at'] as Timestamp?)?.toDate();
      notifyListeners();
    }, onError: onError));
    _subs.add(cloud.games.doc('croix').snapshots().listen((s) {
      final d = s.data();
      _croixTurn = d != null && d['status'] == 'playing' && d['turn'] == me.name;
      notifyListeners();
    }, onError: onError));
    final day = WordOfTheDay.dayIndex(DateTime.now());
    _subs.add(cloud.motdujour.doc('$day').snapshots().listen((s) {
      final d = s.data();
      _motDone = d?[me.other.name] is Map;
      _motMine = d?[me.name] is Map;
      notifyListeners();
    }, onError: onError));
  }

  /// La page Messages a été ouverte : le message est lu.
  Future<void> messagesOpened() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    final at = _lastIncoming?.millisecondsSinceEpoch ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    await p.setInt(_kOpened, at > now ? at : now);
    notifyListeners();
  }
}
