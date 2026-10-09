import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/photo.dart';
import 'engine.dart';

/// Picross photo : choix de l'image, de la taille et du nombre de couleurs.
class PicrossPage extends StatefulWidget {
  const PicrossPage({super.key});

  @override
  State<PicrossPage> createState() => _PicrossPageState();
}

class _PicrossPageState extends State<PicrossPage> {
  static const _sizes = {'10 × 10': 10, '15 × 15': 15, '20 × 20': 20};

  String _size = '10 × 10';
  int _colors = 2;
  ui.Image? _image;
  Picross? _preview;
  bool _loading = false;
  bool _mystery = false;
  int _seed = 1;

  @override
  void initState() {
    super.initState();
    _surprise();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _setImage(ui.Image img) async {
    final old = _image;
    _image = img;
    old?.dispose();
    await _rebuild();
  }

  Future<void> _rebuild() async {
    final img = _image;
    if (img == null) return;
    final rgba = await rgbaOf(img);
    if (!mounted || img != _image) return;
    setState(() {
      _preview = buildPicross(rgba: rgba, side: img.width, n: _sizes[_size]!, colors: _colors);
    });
  }

  Future<void> _surprise() async {
    _seed++;
    _mystery = false;
    await _setImage(await paintSurpriseImage(_seed));
  }

  Future<void> _pick(PhotoSource source) async {
    setState(() => _loading = true);
    try {
      final img = await squarePhotoFrom(source);
      if (img != null) {
        _mystery = source == PhotoSource.random;
        await _setImage(img);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(photoErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _play() {
    final img = _image, p = _preview;
    if (img == null || p == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PicrossGamePage(
        image: img.clone(),
        puzzle: Picross(n: p.n, solution: p.solution, palette: p.palette),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    final p = _preview;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Picross')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            'Colorie les cases grâce aux indices de chaque ligne et colonne. '
            'Chaque ligne ou colonne terminée dévoile ce morceau de la vraie photo.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          PhotoPreview(image: img, mystery: _mystery, loading: _loading),
          const SizedBox(height: 12),
          PhotoSourceButtons(enabled: !_loading, onSource: _pick, onSurprise: _surprise),
          const SizedBox(height: 20),
          Text('Taille', style: text.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [for (final s in _sizes.keys) ButtonSegment(value: s, label: Text(s))],
            selected: {_size},
            onSelectionChanged: (v) {
              _size = v.first;
              _rebuild();
            },
          ),
          const SizedBox(height: 16),
          Text('Couleurs : $_colors', style: text.titleSmall),
          Slider(
            value: _colors.toDouble(),
            min: 1,
            max: 4,
            divisions: 3,
            label: '$_colors',
            onChanged: (v) => setState(() => _colors = v.round()),
            onChangeEnd: (_) => _rebuild(),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: p == null || _loading ? null : _play,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Jouer'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class PicrossGamePage extends StatefulWidget {
  const PicrossGamePage({super.key, required this.image, required this.puzzle});

  final ui.Image image;
  final Picross puzzle;

  @override
  State<PicrossGamePage> createState() => _PicrossGamePageState();
}

class _PicrossGamePageState extends State<PicrossGamePage> {
  /// Outil : 1..k = couleur, -1 = croix, 0 = gomme.
  int _tool = 1;
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  bool _won = false;

  // Tracé en cours.
  int? _pointer;
  int _startCell = -1;
  int _paintValue = 0;
  bool? _horizontal;
  List<int> _before = const [];

  late _Layout _layout;

  Picross get _p => widget.puzzle;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _clock.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.image.dispose();
    super.dispose();
  }

  String get _time {
    final s = _clock.elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _begin(Offset pos) {
    if (_won) return;
    final i = _layout.cellAt(pos, _p.n);
    if (i < 0) return;
    if (!_clock.isRunning) _clock.start();
    _startCell = i;
    _horizontal = null;
    _before = List<int>.of(_p.state);
    // Repasser sur une case déjà de cette valeur efface.
    _paintValue = _p.state[i] == _tool ? 0 : _tool;
    _apply(i);
  }

  void _drag(Offset pos) {
    if (_startCell < 0) return;
    int i = _layout.cellAt(pos, _p.n, clamp: true);
    final n = _p.n;
    final sr = _startCell ~/ n, sc = _startCell % n;
    int r = i ~/ n, c = i % n;
    if (_horizontal == null && (r != sr || c != sc)) {
      _horizontal = (c - sc).abs() >= (r - sr).abs();
    }
    if (_horizontal == null) return;
    // Tracé verrouillé sur la ligne ou la colonne de départ.
    if (_horizontal!) {
      r = sr;
    } else {
      c = sc;
    }
    _p.state.setAll(0, _before);
    if (_horizontal!) {
      for (int x = math.min(sc, c); x <= math.max(sc, c); x++) {
        _apply(sr * n + x, refresh: false);
      }
    } else {
      for (int y = math.min(sr, r); y <= math.max(sr, r); y++) {
        _apply(y * n + sc, refresh: false);
      }
    }
    setState(() {});
  }

  void _apply(int i, {bool refresh = true}) {
    // Repasser avec une couleur n'efface que cette couleur ; la gomme
    // efface tout ; colorier recouvre tout (autre couleur ou croix).
    if (_tool != 0 && _paintValue == 0 && _before[i] != _tool) return;
    _p.state[i] = _paintValue;
    if (refresh) setState(() {});
  }

  void _end() {
    _startCell = -1;
    if (_p.solved && !_won) {
      _clock.stop();
      setState(() => _won = true);
    }
  }

  void _reset() {
    setState(() {
      _p.state.fillRange(0, _p.state.length, 0);
      _won = false;
      _clock
        ..reset()
        ..stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_won ? 'Bravo ! $_time' : _time),
        actions: [
          IconButton(tooltip: 'Recommencer', icon: const Icon(Icons.refresh), onPressed: _reset),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: LayoutBuilder(builder: (context, c) {
                  _layout = _Layout.compute(_p, Size(c.maxWidth, c.maxHeight));
                  if (_won) {
                    return Center(
                      child: SizedBox.square(
                        dimension: math.min(c.maxWidth, c.maxHeight),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: RawImage(image: widget.image, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  }
                  // Événements bruts : un seul doigt, sans délai de tap.
                  return Listener(
                    onPointerDown: (e) {
                      if (_pointer != null) return;
                      _pointer = e.pointer;
                      _begin(e.localPosition);
                    },
                    onPointerMove: (e) {
                      if (e.pointer == _pointer) _drag(e.localPosition);
                    },
                    onPointerUp: (e) {
                      if (e.pointer != _pointer) return;
                      _pointer = null;
                      _end();
                    },
                    onPointerCancel: (e) {
                      if (e.pointer != _pointer) return;
                      _pointer = null;
                      _end();
                    },
                    child: CustomPaint(
                      size: Size(c.maxWidth, c.maxHeight),
                      painter: _GridPainter(_p, widget.image, _layout, scheme),
                    ),
                  );
                }),
              ),
            ),
            if (!_won)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (int k = 1; k <= _p.palette.length; k++)
                      _ToolButton(
                        selected: _tool == k,
                        onTap: () => setState(() => _tool = k),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(_p.palette[k - 1]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    _ToolButton(
                      selected: _tool == -1,
                      onTap: () => setState(() => _tool = -1),
                      child: const SizedBox(width: 34, height: 34, child: Icon(Icons.close)),
                    ),
                    _ToolButton(
                      selected: _tool == 0,
                      onTap: () => setState(() => _tool = 0),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Tooltip(message: 'Gomme', child: Icon(Icons.auto_fix_normal_outlined)),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Autre image'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 3 : 1),
        ),
        child: child,
      ),
    );
  }
}

/// Position de la grille et des zones d'indices.
class _Layout {
  _Layout(this.cell, this.origin, this.clueCell);

  final double cell;
  final Offset origin; // coin haut-gauche de la grille
  final double clueCell;

  static _Layout compute(Picross p, Size size) {
    final maxRow = p.rowClues.fold<int>(1, (m, c) => math.max(m, c.length));
    final maxCol = p.colClues.fold<int>(1, (m, c) => math.max(m, c.length));
    const k = 0.8; // taille d'une case d'indice / case de grille
    final cell = math.min(size.width / (p.n + maxRow * k), size.height / (p.n + maxCol * k));
    final w = cell * (p.n + maxRow * k), h = cell * (p.n + maxCol * k);
    final left = (size.width - w) / 2, top = (size.height - h) / 2;
    return _Layout(cell, Offset(left + maxRow * k * cell, top + maxCol * k * cell), cell * k);
  }

  int cellAt(Offset pos, int n, {bool clamp = false}) {
    int c = ((pos.dx - origin.dx) / cell).floor();
    int r = ((pos.dy - origin.dy) / cell).floor();
    if (clamp) {
      c = c.clamp(0, n - 1);
      r = r.clamp(0, n - 1);
    } else if (c < 0 || r < 0 || c >= n || r >= n) {
      return -1;
    }
    return r * n + c;
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.p, this.image, this.l, this.scheme);
  final Picross p;
  final ui.Image image;
  final _Layout l;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final n = p.n, cell = l.cell, o = l.origin;
    final rowDone = [for (int r = 0; r < n; r++) p.rowDone(r)];
    final colDone = [for (int c = 0; c < n; c++) p.colDone(c)];
    final gridRect = Rect.fromLTWH(o.dx, o.dy, n * cell, n * cell);
    canvas.drawRect(gridRect, Paint()..color = scheme.surfaceContainerLowest);

    final src = image.width / n;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (int i = 0; i < n * n; i++) {
      final r = i ~/ n, c = i % n;
      final rect = Rect.fromLTWH(o.dx + c * cell, o.dy + r * cell, cell, cell);
      final v = p.state[i];
      if (rowDone[r] || colDone[c]) {
        // Morceau de la vraie photo, teinté de la couleur posée (ou éclairci
        // si la case est vide) pour que les indices restent lisibles.
        canvas.drawImageRect(image, Rect.fromLTWH(c * src, r * src, src, src), rect.inflate(0.3), paint);
        if (v > 0) {
          canvas.drawRect(rect, Paint()..color = Color(p.palette[v - 1]).withValues(alpha: 0.55));
        } else {
          canvas.drawRect(rect, Paint()..color = scheme.surface.withValues(alpha: 0.72));
          if (v < 0) _cross(canvas, rect, cell);
        }
        continue;
      }
      if (v > 0) {
        canvas.drawRect(rect.deflate(0.5), Paint()..color = Color(p.palette[v - 1]));
      } else if (v < 0) {
        _cross(canvas, rect, cell);
      }
    }

    // Quadrillage, plus marqué toutes les 5 cases.
    for (int k = 0; k <= n; k++) {
      final line = Paint()
        ..color = k % 5 == 0 ? scheme.outline : scheme.outlineVariant
        ..strokeWidth = k % 5 == 0 ? 1.6 : 0.6;
      canvas.drawLine(Offset(o.dx + k * cell, o.dy), Offset(o.dx + k * cell, o.dy + n * cell), line);
      canvas.drawLine(Offset(o.dx, o.dy + k * cell), Offset(o.dx + n * cell, o.dy + k * cell), line);
    }

    // Indices.
    final cc = l.clueCell;
    for (int r = 0; r < n; r++) {
      final runs = p.rowClues[r];
      for (int j = 0; j < runs.length; j++) {
        final x = o.dx - (runs.length - j) * cc;
        _clue(canvas, Rect.fromLTWH(x, o.dy + r * cell + (cell - cc) / 2, cc, cc), runs[j], rowDone[r]);
      }
      if (runs.isEmpty) _zero(canvas, Rect.fromLTWH(o.dx - cc, o.dy + r * cell + (cell - cc) / 2, cc, cc));
    }
    for (int c = 0; c < n; c++) {
      final runs = p.colClues[c];
      for (int j = 0; j < runs.length; j++) {
        final y = o.dy - (runs.length - j) * cc;
        _clue(canvas, Rect.fromLTWH(o.dx + c * cell + (cell - cc) / 2, y, cc, cc), runs[j], colDone[c]);
      }
      if (runs.isEmpty) _zero(canvas, Rect.fromLTWH(o.dx + c * cell + (cell - cc) / 2, o.dy - cc, cc, cc));
    }
  }

  void _clue(Canvas canvas, Rect r, Run run, bool done) {
    final color = Color(p.palette[run.color - 1]);
    final box = r.deflate(r.width * 0.07);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(r.width * 0.18)),
      Paint()..color = done ? color.withValues(alpha: 0.25) : color,
    );
    final light = color.computeLuminance() > 0.45;
    final tp = TextPainter(
      text: TextSpan(
        text: '${run.length}',
        style: TextStyle(
          fontSize: r.width * 0.55,
          fontWeight: FontWeight.w700,
          color: done ? scheme.onSurfaceVariant.withValues(alpha: 0.6) : (light ? Colors.black87 : Colors.white),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, box.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _cross(Canvas canvas, Rect rect, double cell) {
    final x = Paint()
      ..color = scheme.onSurfaceVariant
      ..strokeWidth = math.max(1, cell * 0.08);
    final d = rect.deflate(cell * 0.3);
    canvas.drawLine(d.topLeft, d.bottomRight, x);
    canvas.drawLine(d.topRight, d.bottomLeft, x);
  }

  void _zero(Canvas canvas, Rect r) {
    final tp = TextPainter(
      text: TextSpan(text: '0', style: TextStyle(fontSize: r.width * 0.5, color: scheme.onSurfaceVariant)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => true;
}
