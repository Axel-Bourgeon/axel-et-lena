import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/tools/des/dice.dart';

void main() {
  test('analyse des formules', () {
    final f = DiceFormula.parse('5D6 + 3');
    expect(f.terms.length, 2);
    expect(f.terms[0].count, 5);
    expect(f.terms[0].sides, 6);
    expect(f.terms[1].isConstant, isTrue);
    expect(f.label, '5D6 + 3');
    expect(DiceFormula.parse('d%').terms.single.sides, 100);
    expect(DiceFormula.parse('2d20-1').label, '2D20 − 1');
    expect(DiceFormula.parse('d8').label, 'D8');
  });

  test('formules refusées', () {
    for (final bad in ['', '5d6++3', '3x', 'd1', '0d6', '101d6', 'd6+', 'abc']) {
      expect(() => DiceFormula.parse(bad), throwsFormatException, reason: bad);
    }
  });

  test('les résultats restent dans les bornes', () {
    final rnd = math.Random(1);
    final f = DiceFormula.parse('5D6 + 3');
    for (int i = 0; i < 500; i++) {
      final r = f.roll(rnd);
      expect(r.results[0].every((v) => v >= 1 && v <= 6), isTrue);
      expect(r.total, inInclusiveRange(8, 33));
      expect(r.total, r.results[0].fold<int>(0, (a, b) => a + b) + 3);
    }
  });

  test('détail lisible', () {
    final f = DiceFormula.parse('2d4-1');
    final r = f.roll(math.Random(3));
    expect(r.detail, '${r.results[0][0]} + ${r.results[0][1]} − 1');
  });
}
