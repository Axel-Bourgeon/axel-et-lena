import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/games/taquin/engine.dart';

/// Parité : un taquin n × n est soluble selon les inversions et la rangée vide.
bool solvable(SlidingPuzzle p) {
  final list = p.tiles.where((t) => t != p.empty).toList();
  int inv = 0;
  for (int i = 0; i < list.length; i++) {
    for (int j = i + 1; j < list.length; j++) {
      if (list[i] > list[j]) inv++;
    }
  }
  if (p.n.isOdd) return inv.isEven;
  final rowFromBottom = p.n - p.emptyPos ~/ p.n;
  return (inv + rowFromBottom).isOdd;
}

void main() {
  test('le mélange est soluble et non résolu', () {
    for (final n in [3, 4, 5]) {
      for (int seed = 0; seed < 20; seed++) {
        final p = SlidingPuzzle(n)..shuffle(math.Random(seed));
        expect(p.solved, isFalse);
        expect(solvable(p), isTrue, reason: 'n=$n seed=$seed');
        expect(p.moves, 0);
      }
    }
  });

  test('glissement d\'une rangée entière', () {
    final p = SlidingPuzzle(3); // vide en 8 (bas droite)
    expect(p.tap(6), [7, 6]); // les deux pièces de la rangée du bas glissent
    expect(p.tiles.sublist(6), [8, 6, 7]);
    expect(p.emptyPos, 6);
    expect(p.tap(4), isEmpty); // ni même ligne ni même colonne
    expect(p.tap(0), [3, 0]); // colonne de gauche
    expect(p.moves, 2);
  });

  test('défaire les coups résout', () {
    final p = SlidingPuzzle(3);
    p.tap(6);
    p.tap(8);
    expect(p.solved, isTrue);
  });
}
