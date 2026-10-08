import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/games/fourmis/engine.dart';
import 'package:axel_lena/games/fourmis/puzzle.dart';

/// Joueur automatique simple : ouvre de préférence un sachet dont la couleur
/// a un pixel accessible.
int playToEnd(FourmisGame game, {int maxSteps = 200000}) {
  int extraSlots = 0;
  for (int step = 0; step < maxSteps; step++) {
    if (game.won) return extraSlots;
    if (game.slots.any((b) => b == null)) {
      int best = -1;
      for (int c = 0; c < game.columns.length; c++) {
        if (game.columns[c].isEmpty) continue;
        final color = game.columns[c].first.color;
        final ok = List.generate(game.puzzle.cells.length, (i) => i)
            .any((i) => game.accessible[i] && game.puzzle.cells[i] == color);
        if (ok) {
          best = c;
          break;
        }
        best = best < 0 ? c : best;
      }
      if (best >= 0) game.takeFromColumn(best);
    }
    game.update(1 / 30);
    if (game.stuck) {
      if (!game.canAddSlot) fail('bloqué sans recours');
      game.addSlot();
      extraSlots++;
    }
  }
  fail('partie non terminée');
}

void main() {
  test('quantize garde au plus k couleurs', () {
    final rnd = math.Random(3);
    final pixels = List.generate(400, (_) => [rnd.nextDouble() * 255, rnd.nextDouble() * 255, rnd.nextDouble() * 255]);
    final q = quantize(pixels, 6);
    expect(q.palette.length, lessThanOrEqualTo(6));
    expect(q.labels.length, 400);
    expect(q.labels.every((l) => l >= 0 && l < q.palette.length), isTrue);
  });

  test('buildPuzzleFromRgba produit une grille cohérente', () {
    const w = 120, h = 200;
    final rgba = Uint8List(w * h * 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        rgba[i] = (x * 2) & 0xFF;
        rgba[i + 1] = (y) & 0xFF;
        rgba[i + 2] = 128;
        rgba[i + 3] = 255;
      }
    }
    final p = buildPuzzleFromRgba(rgba: rgba, srcWidth: w, srcHeight: h, targetWidth: 30, colorCount: 7);
    expect(p.width, 30);
    expect(p.height, lessThanOrEqualTo(48));
    expect(p.cells.length, p.width * p.height);
    expect(p.palette.length, lessThanOrEqualTo(7));
  });

  test('les sachets couvrent exactement tous les pixels', () {
    final puzzle = generateSamplePuzzle(width: 30, seed: 5);
    final game = FourmisGame(source: puzzle, seed: 1);
    final perColor = List<int>.filled(puzzle.palette.length, 0);
    for (final col in game.columns) {
      for (final b in col) {
        perColor[b.color] += b.size;
      }
    }
    for (int c = 0; c < puzzle.palette.length; c++) {
      expect(perColor[c], puzzle.countOf(c));
    }
  });

  for (final seed in [1, 2, 3]) {
    test('une partie complète se termine (graine $seed)', () {
      final puzzle = generateSamplePuzzle(width: 22, seed: seed);
      final game = FourmisGame(source: puzzle, seed: seed);
      final extra = playToEnd(game);
      expect(game.won, isTrue);
      expect(game.remaining, 0);
      expect(extra, lessThanOrEqualTo(3));
    });
  }
}
