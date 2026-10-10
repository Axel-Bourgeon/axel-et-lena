import 'dart:math' as math;

/// Un terme d'une formule : [count] dés à [sides] faces, ou une constante
/// (sides == 0, valeur = count). [sign] vaut 1 ou -1.
class DiceTerm {
  const DiceTerm(this.sign, this.count, this.sides);
  final int sign;
  final int count;
  final int sides;

  bool get isConstant => sides == 0;

  @override
  String toString() => '${sign < 0 ? '-' : '+'}${isConstant ? '$count' : '${count}D$sides'}';
}

/// Formule de lancer, ex. « 5D6 + 3 », « 2d20 - 1 », « d% ».
class DiceFormula {
  DiceFormula(this.terms);

  final List<DiceTerm> terms;

  static const int maxDice = 100;
  static const int maxSides = 1000;

  static final _term = RegExp(r'^(\d*)d(\d+|%)$');
  static final _whole = RegExp(r'^[+-]?(\d*d(\d+|%)|\d+)([+-](\d*d(\d+|%)|\d+))*$');

  /// Analyse [input] ; lève [FormatException] avec un message lisible.
  static DiceFormula parse(String input) {
    final s = input.toLowerCase().replaceAll(' ', '');
    if (s.isEmpty) throw const FormatException('Formule vide');
    if (!_whole.hasMatch(s)) throw const FormatException('Formule non comprise (ex. : 5D6 + 3)');
    final terms = <DiceTerm>[];
    int dice = 0;
    for (final m in RegExp(r'([+-]?)([^+-]+)').allMatches(s)) {
      final sign = m.group(1) == '-' ? -1 : 1;
      final body = m.group(2)!;
      final d = _term.firstMatch(body);
      if (d != null) {
        final count = d.group(1)!.isEmpty ? 1 : int.parse(d.group(1)!);
        final sides = d.group(2) == '%' ? 100 : int.parse(d.group(2)!);
        if (count < 1) throw const FormatException('Il faut au moins un dé');
        if (sides < 2 || sides > maxSides) throw FormatException('Dé à $sides faces impossible');
        dice += count;
        terms.add(DiceTerm(sign, count, sides));
      } else if (RegExp(r'^\d+$').hasMatch(body)) {
        terms.add(DiceTerm(sign, int.parse(body), 0));
      } else {
        throw FormatException('« $body » non compris (ex. : 5D6 + 3)');
      }
    }
    if (dice > maxDice) throw const FormatException('Pas plus de 100 dés à la fois');
    return DiceFormula(terms);
  }

  DiceRoll roll(math.Random rnd) {
    final results = <List<int>>[];
    int total = 0;
    for (final t in terms) {
      if (t.isConstant) {
        results.add(const []);
        total += t.sign * t.count;
      } else {
        final r = [for (int i = 0; i < t.count; i++) 1 + rnd.nextInt(t.sides)];
        results.add(r);
        total += t.sign * r.fold<int>(0, (a, b) => a + b);
      }
    }
    return DiceRoll(this, results, total);
  }

  /// Écriture normalisée, ex. « 5D6 + 3 ».
  String get label {
    final b = StringBuffer();
    for (int i = 0; i < terms.length; i++) {
      final t = terms[i];
      final body = t.isConstant ? '${t.count}' : '${t.count == 1 ? '' : t.count}D${t.sides}';
      if (i == 0) {
        b.write(t.sign < 0 ? '-$body' : body);
      } else {
        b.write(t.sign < 0 ? ' − $body' : ' + $body');
      }
    }
    return b.toString();
  }

  /// Plus grand dé de la formule (pour choisir la forme animée).
  int get mainSides => terms.where((t) => !t.isConstant).fold<int>(0, (m, t) => math.max(m, t.sides));
}

class DiceRoll {
  DiceRoll(this.formula, this.results, this.total);

  final DiceFormula formula;

  /// Résultats de chaque dé, par terme (vide pour une constante).
  final List<List<int>> results;
  final int total;

  /// Détail, ex. « 4 + 1 + 6 + 2 + 3 + 3 ».
  String get detail {
    final parts = <String>[];
    for (int i = 0; i < formula.terms.length; i++) {
      final t = formula.terms[i];
      final values = t.isConstant ? ['${t.count}'] : results[i].map((v) => '$v');
      for (final v in values) {
        parts.add(parts.isEmpty ? (t.sign < 0 ? '-$v' : v) : (t.sign < 0 ? '− $v' : '+ $v'));
      }
    }
    return parts.join(' ');
  }

  bool get isSingleDie => formula.terms.length == 1 && formula.terms.first.count == 1 && !formula.terms.first.isConstant;
}
