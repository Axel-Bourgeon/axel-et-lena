import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'engine.dart';

enum _Mode { duo, phone }

enum _Level {
  easy('Facile', 2),
  medium('Moyen', 4),
  hard('Difficile', 7);

  const _Level(this.label, this.depth);
  final String label;
  final int depth;
}

const _p1Color = Color(0xFFE5484D); // rouge
const _p2Color = Color(0xFFF5C33B); // jaune

class Puissance4Page extends StatefulWidget {
  const Puissance4Page({super.key});

  @override
  State<Puissance4Page> createState() => _Puissance4PageState();
}

class _Puissance4PageState extends State<Puissance4Page> with SingleTickerProviderStateMixin {
  _Mode _mode = _Mode.duo;
  _Level _level = _Level.medium;
  late Connect4 _game;
  int _starter = 1;
  final List<int> _score = [0, 0, 0]; // [nuls, joueur 1, joueur 2]
  late final AnimationController _drop;
  int _dropCol = -1, _dropRow = -1;
  bool _thinking = false;
  final _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _drop = AnimationController(vsync: this)..addStatusListener(_onDropDone);
    _game = Connect4(firstPlayer: _starter);
  }

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  String _name(int p) {
    if (_mode == _Mode.phone) return p == 1 ? 'Toi' : 'Téléphone';
    return p == 1 ? 'Axel' : 'Léna';
  }

  bool get _phoneTurn => _mode == _Mode.phone && _game.current == 2 && !_game.over;
  bool get _busy => _drop.isAnimating || _thinking;

  void _newGame({bool alternate = true}) {
    if (alternate) _starter = 3 - _starter;
    setState(() {
      _game = Connect4(firstPlayer: _starter);
      _dropCol = -1;
    });
    _maybePhoneMove();
  }

  void _play(int col) {
    if (_busy || !_game.canPlay(col)) return;
    final row = _game.play(col);
    _dropCol = col;
    _dropRow = row;
    // Durée proportionnelle à la hauteur de chute.
    _drop.duration = Duration(milliseconds: 180 + (Connect4.rows - row) * 55);
    _drop.forward(from: 0);
    setState(() {});
  }

  void _onDropDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_game.over) {
      setState(() => _score[_game.result == 3 ? 0 : _game.result]++);
      return;
    }
    _maybePhoneMove();
  }

  Future<void> _maybePhoneMove() async {
    if (!_phoneTurn) return;
    setState(() => _thinking = true);
    // Laisse l'interface se dessiner avant le calcul.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final col = _game.bestMove(depth: _level.depth, rnd: _rnd);
    setState(() => _thinking = false);
    if (col >= 0) _play(col);
  }

  void _undo() {
    if (_busy || _game.history.isEmpty) return;
    if (_game.over) {
      _score[_game.result == 3 ? 0 : _game.result]--;
    }
    setState(() {
      _game.undo();
      // Contre le téléphone : on annule aussi son coup.
      if (_mode == _Mode.phone && _game.current == 2 && _game.history.isNotEmpty) {
        _game.undo();
      }
      _dropCol = -1;
    });
    _maybePhoneMove();
  }

  void _setMode(_Mode m) {
    if (m == _mode) return;
    _mode = m;
    _score.fillRange(0, 3, 0);
    _starter = 2; // _newGame alterne : le joueur 1 commence
    _newGame();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = _game.over
        ? (_game.result == 3 ? 'Match nul !' : '${_name(_game.result)} gagne !')
        : (_thinking ? 'Le téléphone réfléchit…' : 'À ${_name(_game.current)} de jouer');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puissance 4'),
        actions: [
          IconButton(
            tooltip: 'Annuler le coup',
            icon: const Icon(Icons.undo),
            onPressed: _game.history.isEmpty || _busy ? null : _undo,
          ),
          IconButton(
            tooltip: 'Nouvelle partie',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _newGame,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            SegmentedButton<_Mode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Mode.duo, label: Text('À deux'), icon: Icon(Icons.people_outline)),
                ButtonSegment(value: _Mode.phone, label: Text('Contre le téléphone'), icon: Icon(Icons.smartphone)),
              ],
              selected: {_mode},
              onSelectionChanged: _busy ? null : (s) => _setMode(s.first),
            ),
            if (_mode == _Mode.phone) ...[
              const SizedBox(height: 8),
              SegmentedButton<_Level>(
                showSelectedIcon: false,
                segments: [for (final l in _Level.values) ButtonSegment(value: l, label: Text(l.label))],
                selected: {_level},
                onSelectionChanged: (s) => setState(() => _level = s.first),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _ScoreChip(color: _p1Color, name: _name(1), score: _score[1], active: !_game.over && _game.current == 1),
                const Spacer(),
                Text('Nuls : ${_score[0]}', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const Spacer(),
                _ScoreChip(color: _p2Color, name: _name(2), score: _score[2], active: !_game.over && _game.current == 2),
              ],
            ),
            const SizedBox(height: 12),
            Center(child: Text(status, style: text.titleMedium)),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: Connect4.cols / (Connect4.rows + 0.4),
              child: LayoutBuilder(builder: (context, c) {
                return GestureDetector(
                  onTapUp: (d) {
                    if (_phoneTurn) return;
                    _play((d.localPosition.dx / c.maxWidth * Connect4.cols).floor().clamp(0, Connect4.cols - 1));
                  },
                  child: AnimatedBuilder(
                    animation: _drop,
                    builder: (context, _) => CustomPaint(
                      size: Size(c.maxWidth, c.maxHeight),
                      painter: _BoardPainter(
                        game: _game,
                        dropCol: _dropCol,
                        dropRow: _dropRow,
                        drop: Curves.easeIn.transform(_drop.value),
                        boardColor: scheme.primary,
                        holeColor: scheme.surface,
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (_game.over) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _newGame,
                icon: const Icon(Icons.replay),
                label: const Text('Rejouer'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.color, required this.name, required this.score, required this.active});
  final Color color;
  final String name;
  final int score;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? color : scheme.outlineVariant, width: active ? 2.5 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 9, backgroundColor: color),
          const SizedBox(width: 8),
          Text('$name  $score', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.game,
    required this.dropCol,
    required this.dropRow,
    required this.drop,
    required this.boardColor,
    required this.holeColor,
  });

  final Connect4 game;
  final int dropCol, dropRow;
  final double drop;
  final Color boardColor, holeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / Connect4.cols;
    final top = size.height - cell * Connect4.rows;
    final r = cell * 0.38;
    Offset center(int col, double row) =>
        Offset((col + 0.5) * cell, top + (Connect4.rows - 1 - row + 0.5) * cell);

    final board = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, top, size.width, cell * Connect4.rows),
      Radius.circular(cell * 0.3),
    );
    // Pions (sous le plateau, visibles à travers les trous).
    final win = game.winningCells.toSet();
    for (int row = 0; row < Connect4.rows; row++) {
      for (int col = 0; col < Connect4.cols; col++) {
        final v = game.at(col, row);
        if (v == 0 || (col == dropCol && row == dropRow)) continue;
        _disc(canvas, center(col, row.toDouble()), r, v, win.contains(row * Connect4.cols + col));
      }
    }
    if (dropCol >= 0 && drop >= 1 && game.at(dropCol, dropRow) != 0) {
      _disc(canvas, center(dropCol, dropRow.toDouble()), r, game.at(dropCol, dropRow),
          win.contains(dropRow * Connect4.cols + dropCol));
    }

    // Plateau percé.
    final holes = Path()..fillType = PathFillType.evenOdd;
    holes.addRRect(board);
    for (int row = 0; row < Connect4.rows; row++) {
      for (int col = 0; col < Connect4.cols; col++) {
        holes.addOval(Rect.fromCircle(center: center(col, row.toDouble()), radius: r));
      }
    }
    // Fond des trous vides.
    for (int row = 0; row < Connect4.rows; row++) {
      for (int col = 0; col < Connect4.cols; col++) {
        final occupied = game.at(col, row) != 0 && !(col == dropCol && row == dropRow && drop < 1);
        if (!occupied) {
          canvas.drawCircle(center(col, row.toDouble()), r, Paint()..color = holeColor.withValues(alpha: 0.85));
        }
      }
    }
    if (dropCol >= 0 && drop < 1) {
      // Le pion qui tombe passe devant les trous vides.
      final startRow = Connect4.rows - 0.6;
      final row = startRow + (dropRow - startRow) * drop;
      _disc(canvas, center(dropCol, row), r, game.at(dropCol, dropRow), false);
    }
    canvas.drawPath(holes, Paint()..color = boardColor);
  }

  void _disc(Canvas canvas, Offset c, double r, int player, bool highlight) {
    final color = player == 1 ? _p1Color : _p2Color;
    canvas.drawCircle(c, r, Paint()..color = color);
    canvas.drawCircle(c, r * 0.7, Paint()..color = Color.lerp(color, Colors.black, 0.12)!);
    if (highlight) {
      canvas.drawCircle(
        c,
        r * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
