import 'dart:convert';

/// Contenu de l'appli « Conseils bébé » (assets/conseils/conseils.json).
class AdviceTheme {
  const AdviceTheme(this.id, this.label);
  final String id;
  final String label;
}

class AdviceSource {
  const AdviceSource(this.name, this.url);
  final String name;
  final String url;
}

class Advice {
  const Advice({
    required this.id,
    required this.theme,
    required this.title,
    required this.minMonths,
    required this.maxMonths,
    required this.body,
    required this.sources,
    this.urgent = false,
  });

  final String id;
  final String theme;
  final String title;
  final int minMonths;
  final int maxMonths;
  final String body;
  final List<AdviceSource> sources;
  final bool urgent;

  /// Le conseil concerne-t-il un bébé de [months] mois (ou une tranche) ?
  bool coversRange(int from, int to) => minMonths < to && maxMonths > from;

  bool matches(String query) {
    final q = _fold(query);
    return q.isEmpty || _fold(title).contains(q) || _fold(body).contains(q);
  }

  /// Ex. « 0–12 mois », « 1–3 ans ».
  String get ageLabel {
    if (minMonths == 0 && maxMonths >= 36) return 'Tous âges';
    if (maxMonths <= 12) return '$minMonths–$maxMonths mois';
    if (minMonths % 12 == 0 && maxMonths % 12 == 0) return '${minMonths ~/ 12}–${maxMonths ~/ 12} ans';
    return '$minMonths–$maxMonths mois';
  }
}

class EmergencyNumber {
  const EmergencyNumber(this.label, this.number, this.detail);
  final String label;
  final String number;
  final String detail;

  /// « 01 40 05 48 48 » pour les numéros à 10 chiffres.
  String get display {
    if (number.length != 10) return number;
    return [for (int i = 0; i < 10; i += 2) number.substring(i, i + 2)].join(' ');
  }
}

class AdviceBook {
  AdviceBook({required this.themes, required this.advice, required this.numbers});

  factory AdviceBook.fromJson(String source) {
    final d = jsonDecode(source) as Map<String, dynamic>;
    return AdviceBook(
      themes: [for (final t in d['themes'] as List) AdviceTheme(t['id'] as String, t['label'] as String)],
      numbers: [
        for (final n in d['numbers'] as List)
          EmergencyNumber(n['label'] as String, n['number'] as String, n['detail'] as String),
      ],
      advice: [
        for (final a in d['advice'] as List)
          Advice(
            id: a['id'] as String,
            theme: a['theme'] as String,
            title: a['title'] as String,
            minMonths: a['minMonths'] as int,
            maxMonths: a['maxMonths'] as int,
            body: a['body'] as String,
            urgent: a['urgent'] as bool? ?? false,
            sources: [
              for (final s in a['sources'] as List) AdviceSource(s['name'] as String, s['url'] as String),
            ],
          ),
      ],
    );
  }

  final List<AdviceTheme> themes;
  final List<Advice> advice;
  final List<EmergencyNumber> numbers;
}

/// Tranches d'âge proposées dans le filtre (en mois, [début, fin[).
const List<(String, int, int)> kAgeRanges = [
  ('0–3 mois', 0, 3),
  ('3–6 mois', 3, 6),
  ('6–12 mois', 6, 12),
  ('1–2 ans', 12, 24),
  ('2–3 ans', 24, 36),
];

String _fold(String s) {
  const from = 'àâäéèêëîïôöùûüç';
  const to = 'aaaeeeeiioouuuc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}
