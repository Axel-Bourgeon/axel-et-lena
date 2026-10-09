import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'engine.dart';

const _bottomColor = Color(0xFF3E7CB1); // Axel, en bas
const _topColor = Color(0xFFD9627E); // Léna, en haut

class AirHockeyPage extends StatefulWidget {
  const AirHockeyPage({super.key});

  @override
  State<AirHockeyPage> createState() => _AirHockeyPageState();
}

class _AirHockeyPageState extends State<AirHockeyPage> with SingleTickerProviderStateMixin {
  final AirHockey _game = AirHockey();
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// null = écran de choix ; true = contre le téléphone.
  bool? _vsPhone;
  bool _paused = false;
  final Map<int, int> _pointerOwner = {};
  int _seenHits = 0;
  DateTime _lastBuzz = DateTime.fromMillisecondsSinceEpoch(0);
  Rect _table = Rect.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_vsPhone == null || _paused || _game.winner >= 0) return;
    if (_vsPhone!) _game.phoneControl(dt);
    _game.update(dt);
    if (_game.hits != _seenHits) {
      _seenHits = _game.hits;
      final now = DateTime.now();
      if (now.difference(_lastBuzz).inMilliseconds > 60) {
        _lastBuzz = now;
        HapticFeedback.lightImpact();
      }
    }
    setState(() {});
  }

  Vec _toTable(Offset p) => Vec((p.dx - _table.left) / _table.width, (p.dy - _table.top) / _table.width);

  void _down(PointerDownEvent e) {
    if (_vsPhone == null || _paused) return;
    final v = _toTable(e.localPosition);
    final player = v.y > _game.height / 2 ? 0 : 1;
    if (_vsPhone! && player == 1) return;
    if (_pointerOwner.containsValue(player)) return; // un doigt par joueur
    _pointerOwner[e.pointer] = player;
    _game.setTarget(player, v);
  }

  void _move(PointerMoveEvent e) {
    final player = _pointerOwner[e.pointer];
    if (player != null) _game.setTarget(player, _toTable(e.localPosition));
  }

  void _up(PointerEvent e) => _pointerOwner.remove(e.pointer);

  void _start(bool vsPhone) {
    setState(() {
      _vsPhone = vsPhone;
      _paused = false;
      _game.restart();
    });
  }

  String _name(int p) {
    if (_vsPhone == true) return p == 0 ? 'Toi' : 'Téléphone';
    return p == 0 ? 'Axel' : 'Léna';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          // Table au format 1 × height, centrée.
          final w = math.min(c.maxWidth - 16, (c.maxHeight - 16) / _game.height);
          final h = w * _game.height;
          _table = Rect.fromLTWH((c.maxWidth - w) / 2, (c.maxHeight - h) / 2, w, h);
          return Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  child: CustomPaint(painter: _TablePainter(_game, _table, scheme)),
                ),
              ),
              // Scores, chacun lisible de son côté.
              Positioned(
                left: _table.left + 12,
                top: _table.center.dy + 8,
                child: _Score(_name(0), _game.scores[0], _bottomColor),
              ),
              Positioned(
                right: _table.left + 12,
                bottom: c.maxHeight - _table.center.dy + 8,
                child: RotatedBox(quarterTurns: 2, child: _Score(_name(1), _game.scores[1], _topColor)),
              ),
              if (_game.pause > 0 && _game.lastScorer >= 0)
                Center(
                  child: IgnorePointer(
                    child: Text(
                      'But pour ${_name(_game.lastScorer)} !',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: _game.lastScorer == 0 ? _bottomColor : _topColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              Positioned(
                left: 4,
                top: _table.center.dy - 24,
                child: IconButton.filledTonal(
                  tooltip: 'Pause',
                  icon: const Icon(Icons.pause),
                  onPressed: _vsPhone == null ? null : () => setState(() => _paused = true),
                ),
              ),
              if (_vsPhone == null) _menu(context, 'Air hockey', null),
              if (_paused) _menu(context, 'Pause', 'Reprendre'),
              if (_game.winner >= 0) _menu(context, '${_name(_game.winner)} gagne ${_game.scores[_game.winner]} à ${_game.scores[1 - _game.winner]} !', null),
            ],
          );
        }),
      ),
    );
  }

  Widget _menu(BuildContext context, String title, String? resume) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Premier à ${_game.winScore} buts. Chacun joue avec un doigt dans sa moitié.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (resume != null) ...[
                    FilledButton(onPressed: () => setState(() => _paused = false), child: Text(resume)),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: () => _start(false),
                    icon: const Icon(Icons.people_outline),
                    label: const Text('À deux'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _start(true),
                    icon: const Icon(Icons.smartphone),
                    label: const Text('Contre le téléphone'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Quitter')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score(this.name, this.score, this.color);
  final String name;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$score', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.75))),
          const SizedBox(width: 8),
          Text(name, style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.75))),
        ],
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  _TablePainter(this.game, this.table, this.scheme);
  final AirHockey game;
  final Rect table;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final u = table.width;
    Offset p(Vec v) => Offset(table.left + v.x * u, table.top + v.y * u);
    final rink = RRect.fromRectAndRadius(table, Radius.circular(u * 0.08));
    canvas.drawRRect(rink, Paint()..color = scheme.surfaceContainerHighest);
    final line = Paint()
      ..color = scheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(Offset(table.left, table.center.dy), Offset(table.right, table.center.dy), line);
    canvas.drawCircle(table.center, u * 0.14, line);
    // Zones de but.
    final gl = table.left + u * (1 - AirHockey.goalWidth) / 2, gr = table.left + u * (1 + AirHockey.goalWidth) / 2;
    final goal = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(gl, table.top), Offset(gr, table.top), goal..color = _topColor);
    canvas.drawLine(Offset(gl, table.bottom), Offset(gr, table.bottom), goal..color = _bottomColor);
    canvas.drawRRect(
      rink,
      Paint()
        ..color = scheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Palet.
    final puck = p(game.puck);
    canvas.drawCircle(puck + const Offset(1.5, 2), AirHockey.puckR * u, Paint()..color = Colors.black26);
    canvas.drawCircle(puck, AirHockey.puckR * u, Paint()..color = const Color(0xFF222222));
    canvas.drawCircle(puck, AirHockey.puckR * u * 0.55, Paint()..color = const Color(0xFF444444));

    // Maillets.
    for (int i = 0; i < 2; i++) {
      final c = p(game.mallets[i]);
      final color = i == 0 ? _bottomColor : _topColor;
      final r = AirHockey.malletR * u;
      canvas.drawCircle(c + const Offset(2, 3), r, Paint()..color = Colors.black26);
      canvas.drawCircle(c, r, Paint()..color = color);
      canvas.drawCircle(c, r * 0.62, Paint()..color = Color.lerp(color, Colors.white, 0.25)!);
      canvas.drawCircle(c, r * 0.3, Paint()..color = Color.lerp(color, Colors.black, 0.2)!);
    }
  }

  @override
  bool shouldRepaint(covariant _TablePainter old) => true;
}
