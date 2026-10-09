import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/games/puissance4/engine.dart';

Connect4 playAll(List<int> moves) {
  final g = Connect4();
  for (final m in moves) {
    expect(g.play(m), isNot(-1));
  }
  return g;
}

void main() {
  test('alignement horizontal', () {
    final g = playAll([0, 0, 1, 1, 2, 2, 3]);
    expect(g.result, 1);
    expect(g.winningCells.length, greaterThanOrEqualTo(4));
  });

  test('alignement vertical', () {
    final g = playAll([0, 1, 0, 1, 0, 1, 0]);
    expect(g.result, 1);
  });

  test('alignement diagonal', () {
    // Joueur 1 : (0,0) (1,1) (2,2) (3,3)
    final g = playAll([0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3]);
    expect(g.result, 1);
  });

  test('colonne pleine refusée, annulation', () {
    final g = playAll([0, 0, 0, 0, 0, 0]);
    expect(g.canPlay(0), isFalse);
    expect(g.play(0), -1);
    g.undo();
    expect(g.canPlay(0), isTrue);
    expect(g.history.length, 5);
  });

  test('le téléphone gagne quand il peut', () {
    // Joueur 1 a trois pions en bas (0,1,2) ; c'est à lui : il doit jouer 3.
    final g = playAll([0, 0, 1, 1, 2, 5]);
    expect(g.bestMove(depth: 4, rnd: math.Random(1)), 3);
  });

  test('le téléphone bloque une menace immédiate', () {
    // Joueur 1 menace en 3 ; c'est au joueur 2 de bloquer.
    final g = playAll([0, 6, 1, 6, 2]);
    expect(g.bestMove(depth: 4, rnd: math.Random(1)), 3);
  });

  test('une partie téléphone contre téléphone se termine', () {
    final g = Connect4();
    final rnd = math.Random(2);
    while (!g.over) {
      g.play(g.bestMove(depth: 3, rnd: rnd));
    }
    expect(g.result, isIn([1, 2, 3]));
  });
}
