import 'package:cloud_firestore/cloud_firestore.dart';

class Contraction {
  Contraction({this.id, required this.start, this.end});

  factory Contraction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Contraction(
      id: doc.id,
      start: (d['start'] as Timestamp).toDate(),
      end: (d['end'] as Timestamp?)?.toDate(),
    );
  }

  final String? id;
  final DateTime start;
  final DateTime? end;

  bool get ongoing => end == null;
  Duration? get duration => end?.difference(start);
}

/// Résumé de la dernière heure.
class ContractionStats {
  ContractionStats({
    required this.countLastHour,
    required this.avgDuration,
    required this.avgInterval,
    required this.regular,
  });

  final int countLastHour;

  /// Durée moyenne des contractions terminées de la dernière heure.
  final Duration? avgDuration;

  /// Écart moyen entre deux débuts de contraction (dernière heure).
  final Duration? avgInterval;

  /// Repère « 5-1-1 » : contractions toutes les 5 minutes environ, d'environ
  /// 1 minute, depuis au moins 1 heure.
  final bool regular;
}

/// [list] : contractions triées de la plus récente à la plus ancienne.
ContractionStats contractionStats(List<Contraction> list, DateTime now) {
  final hour = list.where((c) => now.difference(c.start).inMinutes < 60).toList().reversed.toList();
  final done = hour.where((c) => !c.ongoing).toList();
  Duration? avg(Iterable<Duration> ds) {
    final l = ds.toList();
    if (l.isEmpty) return null;
    return Duration(milliseconds: l.fold<int>(0, (s, d) => s + d.inMilliseconds) ~/ l.length);
  }

  final intervals = [for (int i = 1; i < hour.length; i++) hour[i].start.difference(hour[i - 1].start)];
  final avgDuration = avg(done.map((c) => c.duration!));
  final avgInterval = avg(intervals);
  // Il faut que la série couvre presque toute l'heure, sans trou de plus de
  // 5 min 30, avec des contractions d'au moins 45 s en moyenne.
  final regular = hour.length >= 8 &&
      now.difference(hour.first.start).inMinutes >= 55 &&
      intervals.every((d) => d.inSeconds <= 330) &&
      avgDuration != null &&
      avgDuration.inSeconds >= 45;
  return ContractionStats(
    countLastHour: hour.length,
    avgDuration: avgDuration,
    avgInterval: avgInterval,
    regular: regular,
  );
}

/// « 4 min 30 », « 55 s ».
String durationLabel(Duration d) {
  final m = d.inMinutes, s = d.inSeconds % 60;
  if (m == 0) return '$s s';
  return s == 0 ? '$m min' : '$m min ${s.toString().padLeft(2, '0')}';
}
