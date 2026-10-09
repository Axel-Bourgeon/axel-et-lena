import 'dart:math' as math;

/// Taquin n × n. `tiles[pos]` = numéro de la pièce à cette position, où la
/// pièce k a pour place correcte la position k ; la case vide est n*n - 1.
class SlidingPuzzle {
  SlidingPuzzle(this.n) : tiles = List<int>.generate(n * n, (i) => i);

  final int n;
  final List<int> tiles;
  int moves = 0;

  int get empty => n * n - 1;
  int get emptyPos => tiles.indexOf(empty);

  bool get solved {
    for (int i = 0; i < tiles.length; i++) {
      if (tiles[i] != i) return false;
    }
    return true;
  }

  /// Mélange par coups légaux (toujours soluble), sans revenir en arrière.
  void shuffle(math.Random rnd, {int? steps}) {
    final count = steps ?? n * n * 25;
    int prev = -1;
    for (int s = 0; s < count; s++) {
      final e = emptyPos;
      final options = _neighbors(e).where((p) => p != prev).toList();
      final p = options[rnd.nextInt(options.length)];
      tiles[e] = tiles[p];
      tiles[p] = empty;
      prev = e;
    }
    if (solved) shuffle(rnd, steps: count);
    moves = 0;
  }

  List<int> _neighbors(int pos) {
    final r = pos ~/ n, c = pos % n;
    return [
      if (r > 0) pos - n,
      if (r < n - 1) pos + n,
      if (c > 0) pos - 1,
      if (c < n - 1) pos + 1,
    ];
  }

  /// Touche la pièce en [pos] : si elle est sur la même ligne ou colonne que
  /// la case vide, toute la rangée glisse. Renvoie les pièces déplacées.
  List<int> tap(int pos) {
    final e = emptyPos;
    if (pos == e) return const [];
    final pr = pos ~/ n, pc = pos % n, er = e ~/ n, ec = e % n;
    if (pr != er && pc != ec) return const [];
    final step = pr == er ? (pc < ec ? -1 : 1) : (pr < er ? -n : n);
    final moved = <int>[];
    int hole = e;
    while (hole != pos) {
      final from = hole + step;
      tiles[hole] = tiles[from];
      moved.add(tiles[hole]);
      hole = from;
    }
    tiles[pos] = empty;
    moves++;
    return moved;
  }
}
