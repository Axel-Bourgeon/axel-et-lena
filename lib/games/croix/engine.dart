/// Mots en croix : jeu de lettres à deux, chacun son tour (même à des moments
/// différents). Plateau, bonus et tirage propres à l'appli.
library;

import 'dart:math' as math;

const int kSize = 15;
const int kCenter = 7;
const int kRackSize = 7;
const int kBingo = 50;
const String kJoker = '?';

enum Bonus {
  none('', 1, 1),
  dl('L×2', 2, 1),
  tl('L×3', 3, 1),
  dw('M×2', 1, 2),
  tw('M×3', 1, 3),
  start('★', 1, 2);

  const Bonus(this.label, this.letter, this.word);
  final String label;
  final int letter;
  final int word;
}

/// Cases bonus d'un quart du plateau (lignes et colonnes 0 à 7), recopiées
/// par symétrie sur les trois autres quarts.
const Map<(int, int), Bonus> _quarter = {
  (0, 4): Bonus.tw, (4, 0): Bonus.tw,
  (2, 2): Bonus.dw, (5, 5): Bonus.dw, (1, 6): Bonus.dw, (6, 1): Bonus.dw,
  (0, 0): Bonus.tl, (2, 5): Bonus.tl, (5, 2): Bonus.tl, (3, 7): Bonus.tl, (7, 3): Bonus.tl,
  (0, 7): Bonus.dl, (7, 0): Bonus.dl, (1, 3): Bonus.dl, (3, 1): Bonus.dl,
  (2, 4): Bonus.dl, (4, 2): Bonus.dl, (4, 6): Bonus.dl, (6, 4): Bonus.dl,
  (7, 7): Bonus.start,
};

Bonus bonusAt(int r, int c) {
  final qr = r <= kCenter ? r : kSize - 1 - r;
  final qc = c <= kCenter ? c : kSize - 1 - c;
  return _quarter[(qr, qc)] ?? Bonus.none;
}

/// Valeur des lettres (le joker vaut 0).
const Map<String, int> kValues = {
  'A': 1, 'B': 3, 'C': 3, 'D': 2, 'E': 1, 'F': 4, 'G': 3, 'H': 4, 'I': 1,
  'J': 8, 'K': 10, 'L': 1, 'M': 2, 'N': 1, 'O': 1, 'P': 3, 'Q': 9, 'R': 1,
  'S': 1, 'T': 1, 'U': 1, 'V': 5, 'W': 10, 'X': 9, 'Y': 9, 'Z': 9, kJoker: 0,
};

/// Nombre de jetons de chaque lettre dans le sac (101 jetons).
const Map<String, int> kCounts = {
  'A': 9, 'B': 2, 'C': 3, 'D': 3, 'E': 14, 'F': 2, 'G': 2, 'H': 2, 'I': 8,
  'J': 1, 'K': 1, 'L': 5, 'M': 3, 'N': 6, 'O': 6, 'P': 2, 'Q': 1, 'R': 6,
  'S': 6, 'T': 6, 'U': 5, 'V': 2, 'W': 1, 'X': 1, 'Y': 1, 'Z': 1, kJoker: 2,
};

List<String> fullBag(math.Random rnd) {
  final bag = <String>[
    for (final e in kCounts.entries)
      for (int i = 0; i < e.value; i++) e.key,
  ];
  bag.shuffle(rnd);
  return bag;
}

int cellKey(int r, int c) => r * kSize + c;
String cellId(int r, int c) => '${r}_$c';

/// Une lettre posée. [joker] : posée avec un joker (vaut 0 point).
class Tile {
  const Tile(this.letter, {this.joker = false});
  final String letter;
  final bool joker;

  int get value => joker ? 0 : (kValues[letter] ?? 0);

  /// Stockage : majuscule = lettre normale, minuscule = joker.
  String get code => joker ? letter.toLowerCase() : letter;
  static Tile fromCode(String s) => s == s.toLowerCase() ? Tile(s.toUpperCase(), joker: true) : Tile(s);
}

Map<int, Tile> boardFromMap(Map<String, dynamic>? m) {
  final out = <int, Tile>{};
  m?.forEach((k, v) {
    final p = k.split('_');
    if (p.length != 2 || v is! String || v.isEmpty) return;
    final r = int.tryParse(p[0]), c = int.tryParse(p[1]);
    if (r == null || c == null) return;
    out[cellKey(r, c)] = Tile.fromCode(v);
  });
  return out;
}

class Placement {
  const Placement(this.r, this.c, this.tile);
  final int r, c;
  final Tile tile;
}

class FormedWord {
  const FormedWord(this.text, this.points);
  final String text;
  final int points;
}

class MoveEval {
  const MoveEval.error(this.error) : words = const [], score = 0;
  const MoveEval(this.words, this.score) : error = null;

  final String? error;
  final List<FormedWord> words;
  final int score;

  bool get ok => error == null;
}

/// Vérifie la pose et calcule les points (sans regarder le dictionnaire).
MoveEval evaluate(Map<int, Tile> board, List<Placement> placed) {
  if (placed.isEmpty) return const MoveEval.error('Pose des lettres sur le plateau');
  final keys = <int>{};
  for (final p in placed) {
    if (p.r < 0 || p.r >= kSize || p.c < 0 || p.c >= kSize) return const MoveEval.error('Hors du plateau');
    final k = cellKey(p.r, p.c);
    if (board.containsKey(k) || !keys.add(k)) return const MoveEval.error('Case déjà prise');
  }
  final sameRow = placed.every((p) => p.r == placed.first.r);
  final sameCol = placed.every((p) => p.c == placed.first.c);
  if (!sameRow && !sameCol) return const MoveEval.error('Les lettres doivent être sur une même ligne');

  final all = <int, Tile>{...board, for (final p in placed) cellKey(p.r, p.c): p.tile};
  final newKeys = keys;
  Tile? at(int r, int c) => (r < 0 || r >= kSize || c < 0 || c >= kSize) ? null : all[cellKey(r, c)];

  // Pas de trou entre les lettres posées.
  if (sameRow) {
    final r = placed.first.r;
    final cs = placed.map((p) => p.c).toList()..sort();
    for (int c = cs.first; c <= cs.last; c++) {
      if (at(r, c) == null) return const MoveEval.error('Les lettres doivent se suivre');
    }
  } else {
    final c = placed.first.c;
    final rs = placed.map((p) => p.r).toList()..sort();
    for (int r = rs.first; r <= rs.last; r++) {
      if (at(r, c) == null) return const MoveEval.error('Les lettres doivent se suivre');
    }
  }

  if (board.isEmpty) {
    if (!keys.contains(cellKey(kCenter, kCenter))) return const MoveEval.error('Le premier mot passe par l\'étoile');
    if (placed.length < 2) return const MoveEval.error('Le premier mot fait au moins 2 lettres');
  } else {
    final touches = placed.any((p) => [(-1, 0), (1, 0), (0, -1), (0, 1)].any((d) {
          final r = p.r + d.$1, c = p.c + d.$2;
          return r >= 0 && r < kSize && c >= 0 && c < kSize && board.containsKey(cellKey(r, c));
        }));
    if (!touches) return const MoveEval.error('Le mot doit toucher une lettre déjà posée');
  }

  FormedWord? wordThrough(int r, int c, int dr, int dc) {
    int r0 = r, c0 = c;
    while (at(r0 - dr, c0 - dc) != null) {
      r0 -= dr;
      c0 -= dc;
    }
    final buf = StringBuffer();
    int sum = 0, mult = 1, len = 0;
    for (int rr = r0, cc = c0; at(rr, cc) != null; rr += dr, cc += dc) {
      final t = at(rr, cc)!;
      buf.write(t.letter);
      len++;
      if (newKeys.contains(cellKey(rr, cc))) {
        final b = bonusAt(rr, cc);
        sum += t.value * b.letter;
        mult *= b.word;
      } else {
        sum += t.value;
      }
    }
    if (len < 2) return null;
    return FormedWord(buf.toString(), sum * mult);
  }

  final words = <FormedWord>[];
  final first = placed.first;
  if (placed.length == 1) {
    final h = wordThrough(first.r, first.c, 0, 1), v = wordThrough(first.r, first.c, 1, 0);
    if (h != null) words.add(h);
    if (v != null) words.add(v);
  } else {
    final (dr, dc) = sameRow ? (0, 1) : (1, 0);
    words.add(wordThrough(first.r, first.c, dr, dc)!);
    for (final p in placed) {
      final w = wordThrough(p.r, p.c, dc, dr);
      if (w != null) words.add(w);
    }
  }
  if (words.isEmpty) return const MoveEval.error('Il faut former un mot d\'au moins 2 lettres');
  final score = words.fold<int>(0, (s, w) => s + w.points) + (placed.length == kRackSize ? kBingo : 0);
  return MoveEval(words, score);
}

int rackValue(Iterable<String> rack) => rack.fold<int>(0, (s, l) => s + (kValues[l] ?? 0));

/// Retire de [rack] les lettres jouées (un joker pour chaque lettre-joker).
/// null si le chevalet ne les contient pas.
List<String>? removeFromRack(List<String> rack, Iterable<Tile> used) {
  final left = List<String>.of(rack);
  for (final t in used) {
    if (!left.remove(t.joker ? kJoker : t.letter)) return null;
  }
  return left;
}
