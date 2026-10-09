import 'dart:math' as math;

/// Pipopipette (jeu des petits carrés) : [rows] × [cols] carrés.
///
/// Traits horizontaux : index h(r, c) = r * cols + c, r ∈ [0, rows], c ∈ [0, cols[.
/// Traits verticaux : index v(r, c) = r * (cols + 1) + c, r ∈ [0, rows[, c ∈ [0, cols].
class DotsAndBoxes {
  DotsAndBoxes({this.rows = 5, this.cols = 5, this.firstPlayer = 1})
      : current = firstPlayer,
        hLines = List<int>.filled((rows + 1) * cols, 0),
        vLines = List<int>.filled(rows * (cols + 1), 0),
        boxes = List<int>.filled(rows * cols, 0);

  final int rows;
  final int cols;
  final int firstPlayer;

  /// 0 = libre, sinon joueur qui a tracé le trait.
  final List<int> hLines;
  final List<int> vLines;

  /// 0 = libre, sinon propriétaire du carré.
  final List<int> boxes;

  int current;

  int score(int p) => boxes.where((b) => b == p).length;

  bool get over => !boxes.contains(0);

  /// 0 tant que la partie continue, 1 ou 2 pour le gagnant, 3 pour un nul.
  int get result {
    if (!over) return 0;
    final a = score(1), b = score(2);
    return a == b ? 3 : (a > b ? 1 : 2);
  }

  bool isFree(bool horizontal, int index) => (horizontal ? hLines : vLines)[index] == 0;

  /// Trace un trait ; renvoie le nombre de carrés fermés (le joueur rejoue
  /// s'il en a fermé au moins un), ou -1 si le trait est déjà pris.
  int play(bool horizontal, int index) {
    final lines = horizontal ? hLines : vLines;
    if (over || lines[index] != 0) return -1;
    lines[index] = current;
    int closed = 0;
    for (final b in _boxesOf(horizontal, index)) {
      if (boxes[b] == 0 && sidesOf(b) == 4) {
        boxes[b] = current;
        closed++;
      }
    }
    if (closed == 0) current = 3 - current;
    return closed;
  }

  /// Carrés bordés par un trait.
  List<int> _boxesOf(bool horizontal, int index) {
    final out = <int>[];
    if (horizontal) {
      final r = index ~/ cols, c = index % cols;
      if (r > 0) out.add((r - 1) * cols + c);
      if (r < rows) out.add(r * cols + c);
    } else {
      final r = index ~/ (cols + 1), c = index % (cols + 1);
      if (c > 0) out.add(r * cols + c - 1);
      if (c < cols) out.add(r * cols + c);
    }
    return out;
  }

  /// Nombre de côtés tracés autour du carré [b].
  int sidesOf(int b) {
    final r = b ~/ cols, c = b % cols;
    int n = 0;
    if (hLines[r * cols + c] != 0) n++;
    if (hLines[(r + 1) * cols + c] != 0) n++;
    if (vLines[r * (cols + 1) + c] != 0) n++;
    if (vLines[r * (cols + 1) + c + 1] != 0) n++;
    return n;
  }

  List<(bool, int)> freeLines() => [
        for (int i = 0; i < hLines.length; i++)
          if (hLines[i] == 0) (true, i),
        for (int i = 0; i < vLines.length; i++)
          if (vLines[i] == 0) (false, i),
      ];

  /// Coup du téléphone : ferme un carré si possible, sinon évite de donner
  /// un 3e côté ; en dernier recours, sacrifie la plus petite chaîne.
  (bool, int) phoneMove(math.Random rnd) {
    final free = freeLines()..shuffle(rnd);
    // 1. Fermer un carré.
    for (final m in free) {
      if (_boxesOf(m.$1, m.$2).any((b) => boxes[b] == 0 && sidesOf(b) == 3)) return m;
    }
    // 2. Trait sans danger (aucun carré ne passe à 3 côtés).
    final safe = [
      for (final m in free)
        if (_boxesOf(m.$1, m.$2).every((b) => sidesOf(b) < 2)) m,
    ];
    if (safe.isNotEmpty) return safe.first;
    // 3. Donner le moins de carrés possible à l'adversaire.
    (bool, int)? best;
    int bestGift = 1 << 30;
    for (final m in free) {
      final gift = _giftIfPlayed(m);
      if (gift < bestGift) {
        bestGift = gift;
        best = m;
      }
    }
    return best ?? free.first;
  }

  /// Nombre de carrés que l'adversaire peut enchaîner si l'on joue [m].
  int _giftIfPlayed((bool, int) m) {
    final copy = DotsAndBoxes(rows: rows, cols: cols)
      ..hLines.setAll(0, hLines)
      ..vLines.setAll(0, vLines)
      ..boxes.setAll(0, boxes);
    copy.current = 1;
    copy.play(m.$1, m.$2);
    copy.current = 2;
    int taken = 0;
    while (true) {
      (bool, int)? closer;
      for (final f in copy.freeLines()) {
        if (copy._boxesOf(f.$1, f.$2).any((b) => copy.boxes[b] == 0 && copy.sidesOf(b) == 3)) {
          closer = f;
          break;
        }
      }
      if (closer == null) break;
      taken += copy.play(closer.$1, closer.$2);
      copy.current = 2;
    }
    return taken;
  }
}
