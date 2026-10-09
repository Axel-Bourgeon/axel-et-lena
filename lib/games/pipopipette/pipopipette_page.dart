import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/photo.dart';
import 'engine.dart';

enum _Mode { duo, phone }

const _sizes = {'Petit': 3, 'Moyen': 5, 'Grand': 7};
const _p1Color = Color(0xFF3E7CB1); // bleu
const _p2Color = Color(0xFFD9624B); // corail

class PipopipettePage extends StatefulWidget {
  const PipopipettePage({super.key});

  @override
  State<PipopipettePage> createState() => _PipopipettePageState();
}

class _PipopipettePageState extends State<PipopipettePage> {
  _Mode _mode = _Mode.duo;
  String _size = 'Moyen';
  int _starter = 1;
  late DotsAndBoxes _game;
  (bool, int)? _last;
  bool _thinking = false;
  final _rnd = math.Random();
  final List<int> _wins = [0, 0, 0];

  /// Photo cachée sous la grille, révélée carré par carré.
  bool _photoMode = true;
  ui.Image? _photo;
  bool _photoLoading = false;
  bool _photoErrorShown = false;
  int _surpriseSeed = 0;

  @override
  void initState() {
    super.initState();
    _game = _fresh();
    _loadPhoto();
  }

  @override
  void dispose() {
    _photo?.dispose();
    super.dispose();
  }

  /// Tire une photo au hasard dans la galerie (paysage dessiné en repli).
  Future<void> _loadPhoto() async {
    if (!_photoMode) return;
    setState(() => _photoLoading = true);
    ui.Image? img;
    try {
      img = await randomSquarePhoto(maxSide: 900);
    } catch (e) {
      // Prévenir une seule fois, puis utiliser le paysage dessiné.
      if (mounted && !_photoErrorShown) {
        _photoErrorShown = true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(photoErrorMessage(e))));
      }
    }
    img ??= await paintSurpriseImage(++_surpriseSeed);
    if (!mounted) {
      img.dispose();
      return;
    }
    final old = _photo;
    setState(() {
      _photo = img;
      _photoLoading = false;
    });
    old?.dispose();
  }

  void _showPhoto() {
    final img = _photo;
    if (img == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: AspectRatio(aspectRatio: 1, child: RawImage(image: img, fit: BoxFit.cover)),
        ),
      ),
    );
  }

  DotsAndBoxes _fresh() {
    final n = _sizes[_size]!;
    return DotsAndBoxes(rows: n, cols: n, firstPlayer: _starter);
  }

  String _name(int p) {
    if (_mode == _Mode.phone) return p == 1 ? 'Toi' : 'Téléphone';
    return p == 1 ? 'Axel' : 'Léna';
  }

  bool get _phoneTurn => _mode == _Mode.phone && _game.current == 2 && !_game.over;

  void _newGame({bool alternate = true}) {
    if (alternate) _starter = 3 - _starter;
    setState(() {
      _game = _fresh();
      _last = null;
    });
    _loadPhoto();
    _phoneLoop();
  }

  void _play(bool horizontal, int index) {
    if (_game.play(horizontal, index) < 0) return;
    _last = (horizontal, index);
    if (_game.over) _wins[_game.result == 3 ? 0 : _game.result]++;
    setState(() {});
    _phoneLoop();
  }

  Future<void> _phoneLoop() async {
    if (_thinking || !_phoneTurn) return;
    _thinking = true;
    final game = _game;
    while (mounted && identical(game, _game) && _phoneTurn) {
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted || !identical(game, _game)) break;
      final m = _game.phoneMove(_rnd);
      _game.play(m.$1, m.$2);
      _last = m;
      if (_game.over) _wins[_game.result == 3 ? 0 : _game.result]++;
      setState(() {});
    }
    _thinking = false;
  }

  void _tap(Offset p, Size size, double cell, Offset origin) {
    if (_phoneTurn || _game.over) return;
    final x = (p.dx - origin.dx) / cell, y = (p.dy - origin.dy) / cell;
    (bool, int)? best;
    double bestD = 0.45;
    // Traits horizontaux : milieu en (c + 0.5, r).
    for (int r = 0; r <= _game.rows; r++) {
      for (int c = 0; c < _game.cols; c++) {
        final d = math.max((x - c - 0.5).abs() * 0.55, (y - r).abs());
        final i = r * _game.cols + c;
        if (d < bestD && _game.isFree(true, i)) {
          bestD = d;
          best = (true, i);
        }
      }
    }
    // Traits verticaux : milieu en (c, r + 0.5).
    for (int r = 0; r < _game.rows; r++) {
      for (int c = 0; c <= _game.cols; c++) {
        final d = math.max((x - c).abs(), (y - r - 0.5).abs() * 0.55);
        final i = r * (_game.cols + 1) + c;
        if (d < bestD && _game.isFree(false, i)) {
          bestD = d;
          best = (false, i);
        }
      }
    }
    if (best != null) _play(best.$1, best.$2);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = _game.over
        ? (_game.result == 3 ? 'Égalité !' : '${_name(_game.result)} gagne !')
        : (_phoneTurn ? 'Le téléphone joue…' : 'À ${_name(_game.current)} de jouer');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipopipette'),
        actions: [
          IconButton(tooltip: 'Nouvelle partie', icon: const Icon(Icons.refresh), onPressed: _newGame),
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
              onSelectionChanged: (s) {
                _mode = s.first;
                _wins.fillRange(0, 3, 0);
                _starter = 2;
                _newGame();
              },
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final s in _sizes.keys) ButtonSegment(value: s, label: Text(s))],
              selected: {_size},
              onSelectionChanged: (s) {
                _size = s.first;
                _newGame(alternate: false);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Photo cachée'),
              subtitle: const Text('Une photo de la galerie au hasard, révélée carré par carré'),
              value: _photoMode,
              onChanged: (v) {
                setState(() => _photoMode = v);
                if (v && _photo == null) _loadPhoto();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ScoreChip(
                  color: _p1Color,
                  name: _name(1),
                  boxes: _game.score(1),
                  wins: _wins[1],
                  active: !_game.over && _game.current == 1,
                ),
                const Spacer(),
                _ScoreChip(
                  color: _p2Color,
                  name: _name(2),
                  boxes: _game.score(2),
                  wins: _wins[2],
                  active: !_game.over && _game.current == 2,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(child: Text(status, style: text.titleMedium)),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, c) {
                final size = Size(c.maxWidth, c.maxHeight);
                final cell = (size.width - 32) / _game.cols;
                const origin = Offset(16, 16);
                return GestureDetector(
                  onTapUp: (d) => _tap(d.localPosition, size, cell, origin),
                  child: CustomPaint(
                    size: size,
                    painter: _BoardPainter(
                      game: _game,
                      cell: cell,
                      origin: origin,
                      last: _last,
                      photo: _photoMode && !_photoLoading ? _photo : null,
                      dotColor: scheme.onSurface,
                      emptyColor: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                );
              }),
            ),
            if (_game.over) ...[
              const SizedBox(height: 16),
              if (_photoMode && _photo != null) ...[
                OutlinedButton.icon(
                  onPressed: _showPhoto,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Voir la photo'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: _newGame,
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
  const _ScoreChip({
    required this.color,
    required this.name,
    required this.boxes,
    required this.wins,
    required this.active,
  });
  final Color color;
  final String name;
  final int boxes;
  final int wins;
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
          Text('$name  $boxes', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('  ($wins ${wins > 1 ? 'victoires' : 'victoire'})',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.game,
    required this.cell,
    required this.origin,
    required this.last,
    required this.photo,
    required this.dotColor,
    required this.emptyColor,
  });

  final DotsAndBoxes game;
  final double cell;
  final Offset origin;
  final (bool, int)? last;
  final ui.Image? photo;
  final Color dotColor, emptyColor;

  Offset _pt(int r, int c) => origin + Offset(c * cell, r * cell);

  Color _color(int p) => p == 1 ? _p1Color : _p2Color;

  @override
  void paint(Canvas canvas, Size size) {
    // Carrés gagnés.
    for (int b = 0; b < game.boxes.length; b++) {
      final p = game.boxes[b];
      if (p == 0) continue;
      final r = b ~/ game.cols, c = b % game.cols;
      final img = photo;
      if (img != null) {
        // Morceau de la photo, teinté de la couleur du joueur.
        final rect = Rect.fromPoints(_pt(r, c), _pt(r + 1, c + 1));
        final s = img.width / game.cols;
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(c * s, r * s, s, s),
          rect,
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.drawRect(rect, Paint()..color = _color(p).withValues(alpha: 0.28));
        continue;
      }
      final rect = Rect.fromPoints(_pt(r, c), _pt(r + 1, c + 1)).deflate(cell * 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.12)),
        Paint()..color = _color(p).withValues(alpha: 0.35),
      );
    }
    final stroke = math.max(3.0, cell * 0.09);
    void line(Offset a, Offset b, int owner, bool isLast) {
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = owner == 0 ? 1.5 : (isLast ? stroke * 1.45 : stroke)
        ..color = owner == 0 ? emptyColor : _color(owner);
      canvas.drawLine(a, b, paint);
    }

    for (int r = 0; r <= game.rows; r++) {
      for (int c = 0; c < game.cols; c++) {
        final i = r * game.cols + c;
        line(_pt(r, c), _pt(r, c + 1), game.hLines[i], last == (true, i));
      }
    }
    for (int r = 0; r < game.rows; r++) {
      for (int c = 0; c <= game.cols; c++) {
        final i = r * (game.cols + 1) + c;
        line(_pt(r, c), _pt(r + 1, c), game.vLines[i], last == (false, i));
      }
    }
    final dot = Paint()..color = dotColor;
    for (int r = 0; r <= game.rows; r++) {
      for (int c = 0; c <= game.cols; c++) {
        canvas.drawCircle(_pt(r, c), math.max(3.5, cell * 0.075), dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
