import 'dart:math' as math;

/// Puissance 4 : 7 colonnes × 6 rangées, joueurs 1 et 2 (0 = vide).
/// La rangée 0 est en bas.
class Connect4 {
  Connect4({this.firstPlayer = 1}) : current = firstPlayer;

  static const int cols = 7;
  static const int rows = 6;

  final int firstPlayer;
  final List<int> cells = List<int>.filled(cols * rows, 0);
  final List<int> history = [];
  int current;

  /// 0 tant que la partie continue, 1 ou 2 pour le gagnant, 3 pour un nul.
  int result = 0;

  /// Cases alignées du gagnant.
  List<int> winningCells = const [];

  bool get over => result != 0;

  int at(int col, int row) => cells[row * cols + col];

  int heightOf(int col) {
    int r = 0;
    while (r < rows && at(col, r) != 0) {
      r++;
    }
    return r;
  }

  bool canPlay(int col) => !over && col >= 0 && col < cols && at(col, rows - 1) == 0;

  /// Joue dans [col] ; renvoie la rangée atteinte, ou -1 si impossible.
  int play(int col) {
    if (!canPlay(col)) return -1;
    final row = heightOf(col);
    cells[row * cols + col] = current;
    history.add(col);
    final line = _lineThrough(col, row, current);
    if (line != null) {
      result = current;
      winningCells = line;
    } else if (history.length == cols * rows) {
      result = 3;
    }
    current = 3 - current;
    return row;
  }

  void undo() {
    if (history.isEmpty) return;
    final col = history.removeLast();
    final row = heightOf(col) - 1;
    cells[row * cols + col] = 0;
    current = 3 - current;
    result = 0;
    winningCells = const [];
  }

  static const _dirs = [
    [1, 0],
    [0, 1],
    [1, 1],
    [1, -1],
  ];

  List<int>? _lineThrough(int col, int row, int p) {
    for (final d in _dirs) {
      final line = <int>[row * cols + col];
      for (final s in [1, -1]) {
        int c = col + d[0] * s, r = row + d[1] * s;
        while (c >= 0 && c < cols && r >= 0 && r < rows && at(c, r) == p) {
          line.add(r * cols + c);
          c += d[0] * s;
          r += d[1] * s;
        }
      }
      if (line.length >= 4) return line;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Adversaire : minimax avec élagage alpha-bêta.

  /// Meilleure colonne pour le joueur courant. [depth] règle la difficulté.
  int bestMove({int depth = 6, math.Random? rnd}) {
    final r = rnd ?? math.Random();
    final me = current;
    int bestScore = -1 << 30;
    final best = <int>[];
    for (final col in _moveOrder()) {
      if (!canPlay(col)) continue;
      play(col);
      final score = -_negamax(depth - 1, -(1 << 30), 1 << 30);
      undo();
      if (score > bestScore) {
        bestScore = score;
        best
          ..clear()
          ..add(col);
      } else if (score == bestScore) {
        best.add(col);
      }
    }
    assert(current == me);
    return best.isEmpty ? -1 : best[r.nextInt(best.length)];
  }

  static const _order = [3, 2, 4, 1, 5, 0, 6];
  List<int> _moveOrder() => _order;

  /// Score du point de vue du joueur qui doit jouer.
  int _negamax(int depth, int alpha, int beta) {
    if (result == 1 || result == 2) {
      // Le joueur précédent vient de gagner : mauvais pour nous, d'autant
      // plus que c'est rapide.
      return -100000 - depth;
    }
    if (result == 3) return 0;
    if (depth == 0) return _evaluate(current) - _evaluate(3 - current);
    int best = -(1 << 30);
    for (final col in _moveOrder()) {
      if (!canPlay(col)) continue;
      play(col);
      final score = -_negamax(depth - 1, -beta, -alpha);
      undo();
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// Heuristique : fenêtres de 4 cases encore jouables pour [p].
  int _evaluate(int p) {
    int score = 0;
    for (int r = 0; r < rows; r++) {
      if (at(3, r) == p) score += 3;
    }
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (final d in _dirs) {
          final ec = c + d[0] * 3, er = r + d[1] * 3;
          if (ec < 0 || ec >= cols || er < 0 || er >= rows) continue;
          int mine = 0, theirs = 0;
          for (int k = 0; k < 4; k++) {
            final v = at(c + d[0] * k, r + d[1] * k);
            if (v == p) {
              mine++;
            } else if (v != 0) {
              theirs++;
            }
          }
          if (theirs > 0) continue;
          if (mine == 3) {
            score += 20;
          } else if (mine == 2) {
            score += 4;
          }
        }
      }
    }
    return score;
  }
}
