import 'dart:math' as math;
import 'dart:typed_data';

import '../fourmis/palette.dart';
import '../fourmis/puzzle.dart';

/// Bloc d'un indice : [length] cases consécutives de la couleur [color].
class Run {
  const Run(this.color, this.length);
  final int color;
  final int length;

  @override
  bool operator ==(Object other) => other is Run && other.color == color && other.length == length;

  @override
  int get hashCode => Object.hash(color, length);

  @override
  String toString() => '$length:$color';
}

/// Picross (nonogramme) en couleurs, n × n.
///
/// Valeurs de case : 0 = vide, 1..k = couleur (palette[valeur - 1]).
/// Dans la grille du joueur, -1 = case marquée d'une croix (vide supposé).
class Picross {
  Picross({required this.n, required this.solution, required this.palette})
      : state = List<int>.filled(n * n, 0) {
    rowClues = [for (int r = 0; r < n; r++) runsOf(_row(solution, r))];
    colClues = [for (int c = 0; c < n; c++) runsOf(_col(solution, c))];
  }

  final int n;
  final List<int> solution;

  /// Couleurs ARGB des valeurs 1..k.
  final List<int> palette;
  final List<int> state;
  late final List<List<Run>> rowClues;
  late final List<List<Run>> colClues;

  List<int> _row(List<int> g, int r) => g.sublist(r * n, r * n + n);
  List<int> _col(List<int> g, int c) => [for (int r = 0; r < n; r++) g[r * n + c]];

  /// Blocs d'une ligne (les croix comptent comme vides).
  static List<Run> runsOf(List<int> line) {
    final out = <Run>[];
    int i = 0;
    while (i < line.length) {
      final v = line[i];
      if (v <= 0) {
        i++;
        continue;
      }
      int j = i;
      while (j < line.length && line[j] == v) {
        j++;
      }
      out.add(Run(v, j - i));
      i = j;
    }
    return out;
  }

  static bool _same(List<Run> a, List<Run> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool rowDone(int r) => _same(runsOf(_row(state, r)), rowClues[r]);
  bool colDone(int c) => _same(runsOf(_col(state, c)), colClues[c]);

  /// La case est révélée (photo en pleine qualité) si sa ligne ou sa colonne
  /// est terminée.
  bool revealed(int i) => rowDone(i ~/ n) || colDone(i % n);

  bool get solved {
    for (int k = 0; k < n; k++) {
      if (!rowDone(k) || !colDone(k)) return false;
    }
    return true;
  }

  int get filledTarget => solution.where((v) => v > 0).length;
}

/// Construit un picross à partir d'une image carrée RGBA : moyenne par case,
/// réduction à [colors] couleurs + le fond (la teinte la plus claire devient
/// « vide »), puis couleurs écartées pour être faciles à distinguer.
Picross buildPicross({
  required Uint8List rgba,
  required int side,
  required int n,
  required int colors,
  int seed = 1,
}) {
  final pixels = List<List<double>>.generate(n * n, (_) => [0, 0, 0]);
  for (int gy = 0; gy < n; gy++) {
    final y0 = gy * side ~/ n, y1 = math.max(y0 + 1, (gy + 1) * side ~/ n);
    for (int gx = 0; gx < n; gx++) {
      final x0 = gx * side ~/ n, x1 = math.max(x0 + 1, (gx + 1) * side ~/ n);
      double r = 0, g = 0, b = 0;
      int count = 0;
      // Échantillonnage d'un point sur deux : largement suffisant.
      for (int y = y0; y < y1; y += 2) {
        for (int x = x0; x < x1; x += 2) {
          final i = (y * side + x) * 4;
          r += rgba[i];
          g += rgba[i + 1];
          b += rgba[i + 2];
          count++;
        }
      }
      pixels[gy * n + gx] = [r / count, g / count, b / count];
    }
  }
  // Palette triée par luminosité : la dernière (la plus claire) = fond.
  final q = quantize(pixels, colors + 1, seed: seed);
  final bg = q.palette.length - 1;
  final solution = [for (final l in q.labels) l == bg ? 0 : l + 1];
  final palette = separatePalette(q.palette.sublist(0, bg), ColorContrast.contrasted, seed: seed);
  return Picross(n: n, solution: solution, palette: palette);
}
