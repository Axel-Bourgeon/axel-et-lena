import 'dart:collection';
import 'dart:math' as math;

import 'puzzle.dart';

/// Point en « unités de case » : la case (x, y) de l'image a pour centre
/// (x + 0.5, y + 0.5). La bordure extérieure occupe x = -1 / x = width et
/// y = -1 / y = height ; les sachets sont sous la grille (y > height).
class Pt {
  const Pt(this.x, this.y);
  final double x;
  final double y;
  double distTo(Pt o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));
}

class Bag {
  Bag({required this.id, required this.color, required this.size});
  final int id;
  final int color;
  final int size;

  /// Fourmis déjà sorties du sachet.
  int released = 0;

  /// Fourmis ayant récupéré leur pixel (en route vers la fourmilière ou arrivées).
  int collected = 0;

  /// Vrai si la dernière recherche n'a trouvé aucun pixel accessible.
  bool blocked = false;

  double cooldown = 0;

  int get remainingInBag => size - released;
  bool get exhausted => released >= size;
  /// Toutes les fourmis ont leur pixel : le sachet peut disparaître sans
  /// attendre qu'elles soient rentrées à la fourmilière.
  bool get done => collected >= size;
}

enum AntPhase { going, eating, returning }

class Ant {
  Ant({required this.bag, required this.slot, required this.target, required this.standCell, required this.path})
      : x = path.first.x,
        y = path.first.y;

  final Bag bag;
  final int slot;
  final int target;

  /// Case vide (grille étendue) d'où la fourmi mange son pixel.
  final int standCell;
  List<Pt> path;
  int segment = 0;
  double x;
  double y;
  double heading = -math.pi / 2;
  double stride = 0;
  double eatTimer = 0;
  AntPhase phase = AntPhase.going;
  bool carrying = false;

  int get color => bag.color;
}

class FourmisGame {
  FourmisGame({
    required PixelPuzzle source,
    int slotCount = 5,
    int columnCount = 4,
    int seed = 42,
  })  : puzzle = source.copy(),
        original = source,
        _rnd = math.Random(seed),
        slots = List<Bag?>.filled(slotCount, null, growable: true) {
    remaining = puzzle.cells.where((c) => c >= 0).length;
    reserved = List<bool>.filled(puzzle.cells.length, false);
    accessible = List<bool>.filled(puzzle.cells.length, false);
    columns = List.generate(columnCount, (_) => <Bag>[]);
    _generateBags();
    _recomputeAccessible();
  }

  static const double antSpeed = 9; // cases / s à l'aller
  static const double returnSpeed = 12; // cases / s au retour
  static const double eatDuration = 0.12;
  static const double releaseInterval = 0.08;
  static const int maxSlots = 8;

  final PixelPuzzle original;
  final PixelPuzzle puzzle;
  final math.Random _rnd;

  late final List<List<Bag>> columns;
  final List<Bag?> slots;
  final List<Ant> ants = [];
  late List<bool> reserved;
  late List<bool> accessible;
  late int remaining;
  int totalBags = 0;
  int moves = 0;
  double elapsed = 0;

  /// Points de départ des fourmis, un par emplacement (fixés par l'affichage).
  List<Pt>? spawnPoints;

  /// Incrémenté à chaque changement de la grille (pour l'affichage).
  int boardVersion = 0;

  int get width => puzzle.width;
  int get height => puzzle.height;

  bool get won => remaining == 0 && ants.isEmpty;

  int get bagsLeft => columns.fold<int>(0, (s, c) => s + c.length) + slots.where((b) => b != null).length;

  /// Aucun mouvement possible : tous les emplacements pris, aucune fourmi
  /// en route et aucun sachet ouvert ne trouve de pixel accessible.
  bool get stuck {
    if (won || ants.isNotEmpty) return false;
    final hasFree = slots.any((b) => b == null);
    final marketLeft = columns.any((c) => c.isNotEmpty);
    if (hasFree && marketLeft) return false;
    for (final b in slots) {
      if (b != null && !b.exhausted && !b.blocked) return false;
    }
    // Vérifie réellement (un sachet peut ne pas avoir encore réessayé).
    for (final b in slots) {
      if (b != null && !b.exhausted && _hasAccessibleTarget(b.color)) return false;
    }
    return remaining > 0;
  }

  bool get canAddSlot => slots.length < maxSlots;

  /// Trou de fourmilière commun, juste sous l'image : les fourmis y
  /// rapportent leurs pixels.
  Pt get nest => Pt(width / 2, height + 0.85);

  Pt spawnFor(int slot) {
    final sp = spawnPoints;
    if (sp != null && slot < sp.length) return sp[slot];
    return Pt((slot + 0.5) * width / slots.length, height + 3.0);
  }

  // ---------------------------------------------------------------------------
  // Actions du joueur

  /// Ouvre le sachet en tête de la colonne [col] dans le premier emplacement
  /// libre. Renvoie false si impossible.
  bool takeFromColumn(int col) {
    if (col < 0 || col >= columns.length || columns[col].isEmpty) return false;
    final free = slots.indexWhere((b) => b == null);
    if (free < 0) return false;
    slots[free] = columns[col].removeAt(0);
    moves++;
    return true;
  }

  void addSlot() {
    if (canAddSlot) slots.add(null);
  }

  // ---------------------------------------------------------------------------
  // Simulation

  void update(double dt) {
    if (dt <= 0) return;
    dt = math.min(dt, 0.05);
    if (!won) elapsed += dt;

    // Sortie des fourmis.
    for (int s = 0; s < slots.length; s++) {
      final bag = slots[s];
      if (bag == null || bag.exhausted) continue;
      bag.cooldown -= dt;
      if (bag.cooldown > 0) continue;
      final ant = _dispatch(bag, s);
      if (ant == null) {
        bag.blocked = true;
        bag.cooldown = 0.25; // réessaie un peu plus tard
      } else {
        bag.blocked = false;
        bag.released++;
        bag.cooldown = releaseInterval;
        ants.add(ant);
      }
    }

    // Déplacement des fourmis.
    final finished = <Ant>[];
    for (final ant in ants) {
      switch (ant.phase) {
        case AntPhase.going:
          if (_advance(ant, antSpeed * dt)) {
            ant.phase = AntPhase.eating;
            ant.eatTimer = eatDuration;
          }
        case AntPhase.eating:
          ant.eatTimer -= dt;
          if (ant.eatTimer <= 0) {
            _removeCell(ant.target);
            ant.carrying = true;
            ant.bag.collected++;
            ant.phase = AntPhase.returning;
            ant.path = _pathToNest(ant);
            ant.segment = 0;
          }
        case AntPhase.returning:
          if (_advance(ant, returnSpeed * dt)) finished.add(ant);
      }
    }
    ants.removeWhere(finished.contains);

    // Libère les emplacements des sachets terminés.
    for (int s = 0; s < slots.length; s++) {
      final b = slots[s];
      if (b != null && b.done) slots[s] = null;
    }
  }

  /// Avance la fourmi le long de son chemin ; true si elle est arrivée.
  bool _advance(Ant ant, double dist) {
    final path = ant.path;
    while (dist > 0 && ant.segment < path.length - 1) {
      final target = path[ant.segment + 1];
      final dx = target.x - ant.x, dy = target.y - ant.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 1e-6) {
        ant.segment++;
        continue;
      }
      ant.heading = math.atan2(dy, dx);
      if (d <= dist) {
        ant.x = target.x;
        ant.y = target.y;
        ant.segment++;
        dist -= d;
        ant.stride += d;
      } else {
        ant.x += dx / d * dist;
        ant.y += dy / d * dist;
        ant.stride += dist;
        dist = 0;
      }
    }
    return ant.segment >= path.length - 1;
  }

  void _removeCell(int index) {
    if (puzzle.cells[index] >= 0) {
      puzzle.cells[index] = -1;
      remaining--;
    }
    reserved[index] = false;
    _recomputeAccessible();
    // Un pixel retiré peut débloquer tous les sachets.
    for (final b in slots) {
      if (b != null && b.blocked) b.cooldown = 0;
    }
    boardVersion++;
  }

  // ---------------------------------------------------------------------------
  // Grille et chemins

  int get _gw => width + 2;
  int get _gh => height + 2;

  /// Index dans la grille étendue (avec bordure) ; x, y en coordonnées image.
  int _g(int x, int y) => (y + 1) * _gw + (x + 1);

  bool _inImage(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  bool _walkable(int x, int y) {
    if (x < -1 || y < -1 || x > width || y > height) return false;
    if (!_inImage(x, y)) return true;
    return puzzle.cells[y * width + x] < 0;
  }

  static const _dirs = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];

  /// Cases pleines touchant une case vide reliée à l'extérieur.
  void _recomputeAccessible() {
    final visited = List<bool>.filled(_gw * _gh, false);
    final queue = Queue<int>();
    for (int x = -1; x <= width; x++) {
      for (final y in [-1, height]) {
        final g = _g(x, y);
        if (!visited[g]) {
          visited[g] = true;
          queue.add(g);
        }
      }
    }
    for (int y = 0; y < height; y++) {
      for (final x in [-1, width]) {
        final g = _g(x, y);
        if (!visited[g]) {
          visited[g] = true;
          queue.add(g);
        }
      }
    }
    for (int i = 0; i < accessible.length; i++) {
      accessible[i] = false;
    }
    while (queue.isNotEmpty) {
      final g = queue.removeFirst();
      final x = g % _gw - 1, y = g ~/ _gw - 1;
      for (final d in _dirs) {
        final nx = x + d[0], ny = y + d[1];
        if (nx < -1 || ny < -1 || nx > width || ny > height) continue;
        final ng = _g(nx, ny);
        if (visited[ng]) continue;
        if (_walkable(nx, ny)) {
          visited[ng] = true;
          queue.add(ng);
        } else {
          accessible[ny * width + nx] = true;
        }
      }
    }
  }

  bool _hasAccessibleTarget(int color) {
    for (int i = 0; i < puzzle.cells.length; i++) {
      if (accessible[i] && !reserved[i] && puzzle.cells[i] == color) return true;
    }
    return false;
  }

  /// Cherche le pixel accessible le plus proche de la couleur du sachet et
  /// crée une fourmi avec son chemin. null si aucun pixel disponible.
  Ant? _dispatch(Bag bag, int slot) {
    if (!_hasAccessibleTarget(bag.color)) return null;
    final spawn = spawnFor(slot);
    final entryX = spawn.x.floor().clamp(-1, width).toInt();
    final entryY = height; // rangée de bordure sous l'image
    final start = _g(entryX, entryY);

    final prev = List<int>.filled(_gw * _gh, -2);
    final queue = Queue<int>()..add(start);
    prev[start] = -1;
    int foundFrom = -1, foundCell = -1;

    while (queue.isNotEmpty && foundCell < 0) {
      final g = queue.removeFirst();
      final x = g % _gw - 1, y = g ~/ _gw - 1;
      // Ordre des directions mélangé pour des trajets variés.
      final dirs = List.of(_dirs)..shuffle(_rnd);
      for (final d in dirs) {
        final nx = x + d[0], ny = y + d[1];
        if (nx < -1 || ny < -1 || nx > width || ny > height) continue;
        final ng = _g(nx, ny);
        if (prev[ng] != -2) continue;
        if (_walkable(nx, ny)) {
          prev[ng] = g;
          queue.add(ng);
        } else {
          final ci = ny * width + nx;
          if (puzzle.cells[ci] == bag.color && !reserved[ci]) {
            foundFrom = g;
            foundCell = ci;
            break;
          }
        }
      }
    }
    if (foundCell < 0) return null;

    reserved[foundCell] = true;
    final cells = <int>[];
    for (int g = foundFrom; g != -1; g = prev[g]) {
      cells.add(g);
    }
    final path = <Pt>[spawn];
    for (final g in cells.reversed) {
      path.add(Pt(g % _gw - 1 + 0.5, g ~/ _gw - 1 + 0.5));
    }
    final tx = foundCell % width, ty = foundCell ~/ width;
    // La fourmi s'arrête au bord du pixel cible.
    final last = path.last;
    path.add(Pt((last.x + tx + 0.5) / 2, (last.y + ty + 0.5) / 2));
    return Ant(bag: bag, slot: slot, target: foundCell, standCell: foundFrom, path: path);
  }

  /// Chemin de la fourmi (qui vient de manger) jusqu'à la fourmilière. Les
  /// cases vides ne font que s'agrandir, donc un chemin calculé reste valable.
  List<Pt> _pathToNest(Ant ant) {
    final nestG = _g(nest.x.floor().clamp(-1, width).toInt(), height);
    final prev = List<int>.filled(_gw * _gh, -2);
    final queue = Queue<int>()..add(ant.standCell);
    prev[ant.standCell] = -1;
    while (queue.isNotEmpty && prev[nestG] == -2) {
      final g = queue.removeFirst();
      final x = g % _gw - 1, y = g ~/ _gw - 1;
      for (final d in _dirs) {
        final nx = x + d[0], ny = y + d[1];
        if (!_walkable(nx, ny)) continue;
        final ng = _g(nx, ny);
        if (prev[ng] != -2) continue;
        prev[ng] = g;
        queue.add(ng);
      }
    }
    final cells = <int>[];
    if (prev[nestG] != -2) {
      for (int g = nestG; g != -1; g = prev[g]) {
        cells.add(g);
      }
    }
    return <Pt>[
      Pt(ant.x, ant.y),
      for (final g in cells.reversed) Pt(g % _gw - 1 + 0.5, g ~/ _gw - 1 + 0.5),
      nest,
    ];
  }

  // ---------------------------------------------------------------------------
  // Génération des sachets

  void _generateBags() {
    final n = puzzle.cells.length;
    // Profondeur de chaque case depuis l'extérieur (BFS à travers tout).
    final depth = List<int>.filled(n, 1 << 30);
    final queue = Queue<int>();
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
          depth[y * width + x] = 0;
          queue.add(y * width + x);
        }
      }
    }
    while (queue.isNotEmpty) {
      final i = queue.removeFirst();
      final x = i % width, y = i ~/ width;
      for (final d in _dirs) {
        final nx = x + d[0], ny = y + d[1];
        if (!_inImage(nx, ny)) continue;
        final j = ny * width + nx;
        if (depth[j] > depth[i] + 1) {
          depth[j] = depth[i] + 1;
          queue.add(j);
        }
      }
    }

    final order = <int>[for (int i = 0; i < n; i++) if (puzzle.cells[i] >= 0) i];
    final jitter = {for (final i in order) i: depth[i] + _rnd.nextDouble() * 2.5};
    order.sort((a, b) => jitter[a]!.compareTo(jitter[b]!));

    final scale = (order.length / 900).clamp(0.6, 2.0).toDouble();
    final baseSizes = [6, 9, 12, 15];
    int pickSize() => math.max(3, (baseSizes[_rnd.nextInt(baseSizes.length)] * scale).round());

    final colorCount = puzzle.palette.length;
    final remainingOfColor = List<int>.filled(colorCount, 0);
    for (final i in order) {
      remainingOfColor[puzzle.cells[i]]++;
    }
    final counter = List<int>.filled(colorCount, 0);
    final target = List<int>.generate(colorCount, (_) => pickSize());
    final sequence = <Bag>[];
    int id = 0;

    for (final i in order) {
      final c = puzzle.cells[i];
      counter[c]++;
      remainingOfColor[c]--;
      // On émet le sachet quand il est plein, ou on l'agrandit s'il ne
      // resterait qu'un petit reliquat.
      if (counter[c] >= target[c] && (remainingOfColor[c] == 0 || remainingOfColor[c] >= 3)) {
        sequence.add(Bag(id: id++, color: c, size: counter[c]));
        counter[c] = 0;
        target[c] = pickSize();
      } else if (remainingOfColor[c] == 0 && counter[c] > 0) {
        sequence.add(Bag(id: id++, color: c, size: counter[c]));
        counter[c] = 0;
      }
    }

    // Léger mélange local pour éviter un ordre trop évident.
    for (int i = 0; i < sequence.length - 1; i++) {
      if (_rnd.nextDouble() < 0.3) {
        final t = sequence[i];
        sequence[i] = sequence[i + 1];
        sequence[i + 1] = t;
      }
    }
    for (int i = 0; i < sequence.length; i++) {
      columns[i % columns.length].add(sequence[i]);
    }
    totalBags = sequence.length;
  }
}
