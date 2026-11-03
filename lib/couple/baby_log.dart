import 'package:cloud_firestore/cloud_firestore.dart';

/// Types d'entrées de l'agenda bébé.
enum BabyKind {
  bottle('Biberon', '🍼'),
  breast('Tétée', '🤱'),
  diaper('Couche', '🧷'),
  sleep('Dodo', '😴'),
  other('Autre', '📝');

  const BabyKind(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// Contenu d'une couche.
enum Diaper {
  wet('Pipi'),
  dirty('Caca'),
  both('Les deux');

  const Diaper(this.label);
  final String label;
}

class BabyEntry {
  BabyEntry({
    this.id,
    required this.kind,
    required this.at,
    required this.by,
    this.ml,
    this.diaper,
    this.note = '',
  });

  factory BabyEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return BabyEntry(
      id: doc.id,
      kind: BabyKind.values.firstWhere((k) => k.name == d['kind'], orElse: () => BabyKind.other),
      at: (d['at'] as Timestamp).toDate(),
      by: d['by'] as String? ?? '',
      ml: (d['ml'] as num?)?.toInt(),
      diaper: Diaper.values.where((x) => x.name == d['diaper']).firstOrNull,
      note: d['note'] as String? ?? '',
    );
  }

  final String? id;
  final BabyKind kind;
  final DateTime at;

  /// Person.name de celui ou celle qui a noté.
  final String by;
  final int? ml;
  final Diaper? diaper;
  final String note;

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'at': Timestamp.fromDate(at),
        'by': by,
        if (ml != null) 'ml': ml,
        if (diaper != null) 'diaper': diaper!.name,
        'note': note,
      };

  /// Ex. « 120 mL », « Caca », plus le commentaire.
  String get details => [
        if (ml != null) '$ml mL',
        if (diaper != null) diaper!.label,
        if (note.isNotEmpty) note,
      ].join(' · ');
}

/// Dernière entrée de chaque type (les entrées sont triées de la plus récente
/// à la plus ancienne).
Map<BabyKind, BabyEntry> latestByKind(List<BabyEntry> entries) {
  final out = <BabyKind, BabyEntry>{};
  for (final e in entries) {
    out.putIfAbsent(e.kind, () => e);
  }
  return out;
}

/// Total de lait bu sur les 24 dernières heures.
int bottleMlLast24h(List<BabyEntry> entries, DateTime now) => entries
    .where((e) => e.kind == BabyKind.bottle && now.difference(e.at).inHours < 24 && e.ml != null)
    .fold(0, (s, e) => s + e.ml!);
