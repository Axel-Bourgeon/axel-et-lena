import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/games/pipopipette/engine.dart';

void main() {
  test('fermer un carré donne un point et fait rejouer', () {
    final g = DotsAndBoxes(rows: 2, cols: 2);
    // Carré (0,0) : h(0,0)=0, h(1,0)=2, v(0,0)=0, v(0,1)=1.
    expect(g.play(true, 0), 0); // joueur 1
    expect(g.play(true, 2), 0); // joueur 2
    expect(g.play(false, 0), 0); // joueur 1
    expect(g.current, 2);
    expect(g.play(false, 1), 1); // joueur 2 ferme
    expect(g.boxes[0], 2);
    expect(g.current, 2); // rejoue
    expect(g.play(false, 1), -1); // déjà pris
  });

  test('un trait peut fermer deux carrés', () {
    final g = DotsAndBoxes(rows: 1, cols: 2);
    for (final m in [(true, 0), (true, 1), (true, 2), (true, 3), (false, 0), (false, 2)]) {
      g.play(m.$1, m.$2);
    }
    final p = g.current;
    expect(g.play(false, 1), 2);
    expect(g.score(p), 2);
    expect(g.over, isTrue);
  });

  test('le téléphone ferme un carré disponible', () {
    final g = DotsAndBoxes(rows: 2, cols: 2);
    g.play(true, 0);
    g.play(true, 2);
    g.play(false, 0);
    expect(g.phoneMove(math.Random(1)), (false, 1));
  });

  test('une partie téléphone contre téléphone se termine', () {
    final rnd = math.Random(3);
    final g = DotsAndBoxes(rows: 5, cols: 5);
    int guard = 0;
    while (!g.over && guard++ < 200) {
      final m = g.phoneMove(rnd);
      expect(g.play(m.$1, m.$2), isNot(-1));
    }
    expect(g.over, isTrue);
    expect(g.score(1) + g.score(2), 25);
  });
}
