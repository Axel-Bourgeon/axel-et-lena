import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_config.dart';

/// Accès à l'espace partagé du couple dans Firestore.
///
/// Chaque téléphone se connecte anonymement. Le premier crée l'espace et
/// obtient un code ; le second le saisit pour rejoindre. Seuls les membres
/// peuvent lire et écrire (voir firebase/firestore.rules). Firestore garde
/// une copie locale : tout marche hors ligne et se synchronise ensuite.
class CoupleCloud {
  CoupleCloud._(this._prefs, this.uid);

  static const String _kCoupleKey = 'couple.id';
  static CoupleCloud? _instance;

  final SharedPreferences _prefs;
  final String uid;

  static bool get configured => kFirebaseOptions != null;

  /// Initialise Firebase (une seule fois). null si non configuré.
  static Future<CoupleCloud?> instance() async {
    if (_instance != null) return _instance;
    final options = kFirebaseOptions;
    if (options == null) return null;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
    _instance = CoupleCloud._(await SharedPreferences.getInstance(), user.uid);
    return _instance;
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get coupleId => _prefs.getString(_kCoupleKey);
  bool get paired => coupleId != null;

  DocumentReference<Map<String, dynamic>> get _couple => _db.collection('couples').doc(coupleId);

  CollectionReference<Map<String, dynamic>> get alerts => _couple.collection('alerts');
  CollectionReference<Map<String, dynamic>> get baby => _couple.collection('baby');
  CollectionReference<Map<String, dynamic>> get notes => _couple.collection('notes');
  CollectionReference<Map<String, dynamic>> get contractions => _couple.collection('contractions');
  CollectionReference<Map<String, dynamic>> get bag => _couple.collection('bag');
  CollectionReference<Map<String, dynamic>> get backups => _couple.collection('backups');
  CollectionReference<Map<String, dynamic>> get pings => _couple.collection('pings');
  CollectionReference<Map<String, dynamic>> get motdujour => _couple.collection('motdujour');
  CollectionReference<Map<String, dynamic>> get games => _couple.collection('games');

  /// Petite notification automatique pour l'autre (fin de mot du jour, tour
  /// de jeu…). Un seul document par expéditeur : le dernier remplace l'ancien.
  Future<void> ping(String fromName, String title, String text) =>
      pings.doc(fromName).set({'title': title, 'text': text, 'at': Timestamp.now()});

  /// L'espace du couple s'il est déjà relié, sinon null (sans jamais échouer) :
  /// pour les jeux qui marchent aussi sans le cloud.
  static Future<CoupleCloud?> ifPaired() async {
    if (!configured) return null;
    try {
      final c = await instance();
      return c != null && c.paired ? c : null;
    } catch (_) {
      return null;
    }
  }

  /// Code facile à lire et à dicter (sans 0/O ni 1/I/L).
  static String newCode(math.Random rnd) {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return List.generate(10, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
  }

  /// Crée l'espace du couple et renvoie le code à donner à l'autre.
  Future<String> create() async {
    final code = newCode(math.Random.secure());
    await _db.collection('couples').doc(code).set({
      'members': [uid],
      'createdAt': Timestamp.now(),
    });
    await _prefs.setString(_kCoupleKey, code);
    return code;
  }

  /// Rejoint l'espace dont l'autre a donné le code.
  Future<void> join(String rawCode) async {
    final code = normalizeCode(rawCode);
    if (code.length != 10) throw const CoupleException('Le code fait 10 caractères');
    try {
      await _db.collection('couples').doc(code).update({
        'members': FieldValue.arrayUnion([uid]),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found' || e.code == 'permission-denied') {
        throw const CoupleException('Code inconnu');
      }
      rethrow;
    }
    await _prefs.setString(_kCoupleKey, code);
  }

  static String normalizeCode(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<void> leave() => _prefs.remove(_kCoupleKey);
}

class CoupleException implements Exception {
  const CoupleException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// « il y a 2 h 10 », « il y a 5 min », « hier à 22:40 ».
String agoLabel(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.inSeconds < 60) return "à l'instant";
  if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
  if (d.inHours < 24) {
    final m = d.inMinutes % 60;
    return 'il y a ${d.inHours} h${m > 0 ? ' ${m.toString().padLeft(2, '0')}' : ''}';
  }
  return 'le ${dateLabel(t)} à ${timeLabel(t)}';
}

String timeLabel(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String dateLabel(DateTime t) {
  const months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${t.day} ${months[t.month - 1]}';
}
