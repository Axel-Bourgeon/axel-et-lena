import 'dart:convert';
import 'dart:math' as math;

/// Un axe : proposition de gauche (0) ↔ proposition de droite (100).
class Prompt {
  const Prompt(this.left, this.right, {this.theme});
  final String left;
  final String right;

  /// Thème d'origine pour un axe composé de deux éléments d'un même thème.
  final String? theme;
}

/// Banque de concepts du Disque (assets/disque/concepts.json) :
/// - des couples tout faits (« Froid ↔ Chaud ») ;
/// - des thèmes dont on oppose deux éléments (« Sandwich ↔ Tarte »).
class DisqueDeck {
  DisqueDeck({required this.pairs, required this.themes});

  factory DisqueDeck.fromJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    return DisqueDeck(
      pairs: [
        for (final p in data['pairs'] as List) Prompt((p as List)[0] as String, p[1] as String),
      ],
      themes: {
        for (final e in (data['themes'] as Map<String, dynamic>).entries)
          e.key: [for (final v in e.value as List) v as String],
      },
    );
  }

  final List<Prompt> pairs;
  final Map<String, List<String>> themes;

  /// Part des axes tirés parmi les thèmes (le reste : couples tout faits).
  static const double themeShare = 0.3;

  Prompt draw(math.Random rnd) {
    final usable = themes.entries.where((e) => e.value.length >= 2).toList();
    if (usable.isNotEmpty && (pairs.isEmpty || rnd.nextDouble() < themeShare)) {
      final t = usable[rnd.nextInt(usable.length)];
      final a = rnd.nextInt(t.value.length);
      int b = rnd.nextInt(t.value.length - 1);
      if (b >= a) b++;
      return Prompt(t.value[a], t.value[b], theme: t.key);
    }
    final p = pairs[rnd.nextInt(pairs.length)];
    // On inverse parfois les côtés pour varier.
    return rnd.nextBool() ? p : Prompt(p.right, p.left);
  }

  /// Points selon l'écart entre la cible et la réponse (0 à 100).
  static int score(int target, int guess) {
    final d = (target - guess).abs();
    if (d <= zone4) return 4;
    if (d <= zone3) return 3;
    if (d <= zone2) return 2;
    return 0;
  }

  static const int zone4 = 4;
  static const int zone3 = 10;
  static const int zone2 = 17;
}
