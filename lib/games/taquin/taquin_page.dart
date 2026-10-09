import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'engine.dart';

/// Taquin photo : choix de l'image et de la taille, puis partie.
class TaquinPage extends StatefulWidget {
  const TaquinPage({super.key});

  @override
  State<TaquinPage> createState() => _TaquinPageState();
}

class _TaquinPageState extends State<TaquinPage> {
  static const _sizes = {'3 × 3': 3, '4 × 4': 4, '5 × 5': 5};

  String _size = '3 × 3';
  ui.Image? _image;
  bool _loading = false;
  int _surpriseSeed = 1;

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

  void _setImage(ui.Image img) {
    final old = _image;
    setState(() => _image = img);
    old?.dispose();
  }

  Future<void> _surprise() async {
    _surpriseSeed++;
    _setImage(await paintSurpriseImage(_surpriseSeed));
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _loading = true);
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1400, maxHeight: 1400, imageQuality: 92);
      if (file == null) return;
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      _setImage(await cropSquare(frame.image));
      frame.image.dispose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible de charger l\'image ($e)')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _play() {
    final img = _image;
    if (img == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TaquinGamePage(image: img.clone(), n: _sizes[_size]!),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return Scaffold(
      appBar: AppBar(title: const Text('Taquin')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            'Remets les pièces de la photo dans l\'ordre en les faisant glisser vers la case vide.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: _loading || img == null
                  ? const Center(child: CircularProgressIndicator())
                  : RawImage(image: img, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galerie'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Photo'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _surprise,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Surprise'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Taille', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [for (final s in _sizes.keys) ButtonSegment(value: s, label: Text(s))],
            selected: {_size},
            onSelectionChanged: (v) => setState(() => _size = v.first),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: img == null || _loading ? null : _play,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Jouer'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}

class TaquinGamePage extends StatefulWidget {
  const TaquinGamePage({super.key, required this.image, required this.n});

  final ui.Image image;
  final int n;

  @override
  State<TaquinGamePage> createState() => _TaquinGamePageState();
}

class _TaquinGamePageState extends State<TaquinGamePage> {
  late SlidingPuzzle _puzzle;
  bool _numbers = false;
  bool _peek = false;
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _newGame();
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

  void _newGame() {
    setState(() {
      _puzzle = SlidingPuzzle(widget.n)..shuffle(math.Random());
      _clock
        ..reset()
        ..stop();
    });
  }

  void _tap(int pos) {
    if (_puzzle.solved) return;
    if (_puzzle.tap(pos).isEmpty) return;
    if (!_clock.isRunning) _clock.start();
    if (_puzzle.solved) _clock.stop();
    setState(() {});
  }

  String get _time {
    final s = _clock.elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = widget.n;
    final solved = _puzzle.solved;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_puzzle.moves} coups · $_time'),
        actions: [
          IconButton(
            tooltip: 'Numéros',
            isSelected: _numbers,
            icon: const Icon(Icons.pin_outlined),
            selectedIcon: const Icon(Icons.pin),
            onPressed: () => setState(() => _numbers = !_numbers),
          ),
          IconButton(tooltip: 'Mélanger', icon: const Icon(Icons.shuffle), onPressed: _newGame),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, c) {
                final side = c.maxWidth;
                final tile = side / n;
                if (_peek || solved) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RawImage(image: widget.image, fit: BoxFit.cover),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      for (int pos = 0; pos < n * n; pos++)
                        if (_puzzle.tiles[pos] != _puzzle.empty)
                          AnimatedPositioned(
                            key: ValueKey(_puzzle.tiles[pos]),
                            duration: const Duration(milliseconds: 130),
                            curve: Curves.easeOut,
                            left: (pos % n) * tile,
                            top: (pos ~/ n) * tile,
                            width: tile,
                            height: tile,
                            child: GestureDetector(
                              onTap: () => _tap(pos),
                              child: Padding(
                                padding: const EdgeInsets.all(1.5),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CustomPaint(
                                    painter: _TilePainter(widget.image, _puzzle.tiles[pos], n, _numbers),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            if (solved) ...[
              Center(child: Text('Bravo ! ${_puzzle.moves} coups en $_time', style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _newGame,
                icon: const Icon(Icons.replay),
                label: const Text('Rejouer'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ] else
              // Listener (événements bruts) : le bouton ne « vole » pas l'appui.
              Listener(
                onPointerDown: (_) => setState(() => _peek = true),
                onPointerUp: (_) => setState(() => _peek = false),
                onPointerCancel: (_) => setState(() => _peek = false),
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Maintenir pour voir l\'image'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.image, this.index, this.n, this.showNumber);
  final ui.Image image;
  final int index;
  final int n;
  final bool showNumber;

  @override
  void paint(Canvas canvas, Size size) {
    final s = image.width / n;
    final src = Rect.fromLTWH((index % n) * s, (index ~/ n) * s, s, s);
    canvas.drawImageRect(image, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
    if (showNumber) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: size.width * 0.26,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width * 0.08, size.height * 0.04));
    }
  }

  @override
  bool shouldRepaint(covariant _TilePainter old) =>
      old.index != index || old.showNumber != showNumber || old.image != image;
}

/// Recadre au carré (centre) et limite la taille.
Future<ui.Image> cropSquare(ui.Image src, {int maxSide = 1080}) async {
  final side = math.min(src.width, src.height);
  final out = math.min(side, maxSide);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawImageRect(
    src,
    Rect.fromLTWH((src.width - side) / 2, (src.height - side) / 2, side.toDouble(), side.toDouble()),
    Rect.fromLTWH(0, 0, out.toDouble(), out.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  return rec.endRecording().toImage(out, out);
}

/// Paysage dessiné (aucune photo nécessaire) : ciel, soleil, collines.
Future<ui.Image> paintSurpriseImage(int seed, {int side = 900}) {
  final rnd = math.Random(seed);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final s = side.toDouble();
  final hue = rnd.nextDouble() * 360;
  Color hsl(double h, double sat, double l) => HSLColor.fromAHSL(1, h % 360, sat, l).toColor();

  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s * 0.7), [hsl(hue + 200, 0.55, 0.55), hsl(hue + 20, 0.75, 0.75)]),
  );
  final sun = Offset(s * (0.2 + rnd.nextDouble() * 0.6), s * (0.2 + rnd.nextDouble() * 0.15));
  canvas.drawCircle(sun, s * 0.11, Paint()..color = hsl(hue + 40, 0.9, 0.8));
  for (int k = 0; k < 5; k++) {
    final base = s * (0.45 + k * 0.11);
    final path = Path()..moveTo(0, s);
    final phase = rnd.nextDouble() * math.pi * 2, freq = 1.5 + rnd.nextDouble() * 2.5;
    for (int x = 0; x <= 60; x++) {
      final px = s * x / 60;
      path.lineTo(px, base + math.sin(px / s * math.pi * freq + phase) * s * 0.05);
    }
    path
      ..lineTo(s, s)
      ..close();
    canvas.drawPath(path, Paint()..color = hsl(hue + 120 + k * 25, 0.45, 0.62 - k * 0.09));
  }
  // Quelques arbres pour donner des repères.
  for (int t = 0; t < 7; t++) {
    final x = rnd.nextDouble() * s, y = s * (0.62 + rnd.nextDouble() * 0.3), h = s * (0.06 + rnd.nextDouble() * 0.06);
    canvas.drawPath(
      Path()
        ..moveTo(x, y - h)
        ..lineTo(x - h * 0.35, y)
        ..lineTo(x + h * 0.35, y)
        ..close(),
      Paint()..color = hsl(hue + 150, 0.5, 0.22),
    );
  }
  return rec.endRecording().toImage(side, side);
}
