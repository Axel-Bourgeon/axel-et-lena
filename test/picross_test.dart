import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/games/picross/engine.dart';

void main() {
  test('blocs d\'une ligne (couleurs, croix ignorées)', () {
    expect(Picross.runsOf([0, 1, 1, 0, 2, 2, 1, -1, 1]), const [Run(1, 2), Run(2, 2), Run(1, 1), Run(1, 1)]);
    expect(Picross.runsOf([0, 0, -1]), isEmpty);
  });

  test('lignes terminées, révélation et victoire', () {
    final p = Picross(n: 2, solution: [1, 0, 2, 2], palette: [0xFF000000, 0xFFFF0000]);
    expect(p.rowClues[0], const [Run(1, 1)]);
    expect(p.colClues[1], const [Run(2, 1)]);
    expect(p.solved, isFalse);
    expect(p.revealed(0), isFalse);
    p.state[0] = 1;
    p.state[1] = -1; // croix = vide
    expect(p.rowDone(0), isTrue);
    expect(p.revealed(1), isTrue); // ligne 0 terminée
    p.state[2] = 2;
    p.state[3] = 2;
    expect(p.solved, isTrue);
  });

  test('une autre solution qui respecte les indices est acceptée', () {
    // Damier 2×2 : deux solutions possibles.
    final p = Picross(n: 2, solution: [1, 0, 0, 1], palette: [0xFF000000]);
    p.state.setAll(0, [0, 1, 1, 0]);
    expect(p.solved, isTrue);
  });

  test('construction depuis une image : fond clair = vide', () {
    const side = 40;
    final rgba = Uint8List(side * side * 4);
    for (int y = 0; y < side; y++) {
      for (int x = 0; x < side; x++) {
        final i = (y * side + x) * 4;
        final dark = x < side / 2; // moitié gauche sombre, droite blanche
        rgba[i] = dark ? 20 : 250;
        rgba[i + 1] = dark ? 30 : 250;
        rgba[i + 2] = dark ? 90 : 250;
        rgba[i + 3] = 255;
      }
    }
    final p = buildPicross(rgba: rgba, side: side, n: 10, colors: 1);
    expect(p.palette.length, 1);
    for (int r = 0; r < 10; r++) {
      expect(p.rowClues[r], const [Run(1, 5)]);
    }
    expect(p.filledTarget, 50);
  });
}
