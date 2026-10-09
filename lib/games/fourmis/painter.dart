import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'engine.dart';
import 'puzzle.dart';

/// Disposition de l'aire de jeu (grille + rangée d'emplacements).
class GameLayout {
  GameLayout(Size size, FourmisGame game, {required this.slotRowHeight}) {
    final slotCount = game.slots.length;
    // Grille + une case de bordure de chaque côté.
    final boardAreaH = size.height - slotRowHeight - 12;
    final cellW = size.width / (game.width + 2);
    final cellH = boardAreaH / (game.height + 2);
    cell = math.max(1.0, math.min(cellW, cellH));
    final boardW = game.width * cell, boardH = game.height * cell;
    origin = Offset((size.width - boardW) / 2, (boardAreaH - boardH) / 2);
    boardRect = origin & Size(boardW, boardH);

    final slotTop = size.height - slotRowHeight;
    const gap = 8.0;
    final slotW = math.min(72.0, (size.width - gap * (slotCount + 1)) / slotCount);
    final totalW = slotW * slotCount + gap * (slotCount - 1);
    final left = (size.width - totalW) / 2;
    slotRects = [
      for (int i = 0; i < slotCount; i++)
        Rect.fromLTWH(left + i * (slotW + gap), slotTop + 4, slotW, slotRowHeight - 8),
    ];
  }

  final double slotRowHeight;
  late final double cell;
  late final Offset origin;
  late final Rect boardRect;
  late final List<Rect> slotRects;

  Offset toPx(double x, double y) => Offset(origin.dx + x * cell, origin.dy + y * cell);

  Pt toBoard(Offset p) => Pt((p.dx - origin.dx) / cell, (p.dy - origin.dy) / cell);

  List<Pt> spawnPoints() => [for (final r in slotRects) toBoard(r.topCenter)];
}

class GamePainter extends CustomPainter {
  GamePainter({required this.game, required this.layout, required this.scheme, required this.time});

  final FourmisGame game;
  final GameLayout layout;
  final ColorScheme scheme;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBoard(canvas);
    _paintNest(canvas);
    _paintSlots(canvas);
    _paintAnts(canvas);
  }

  /// Trou de fourmilière : petit monticule de terre avec une entrée sombre.
  void _paintNest(Canvas canvas) {
    final c = layout.toPx(game.nest.x, game.nest.y);
    final w = math.max(26.0, layout.cell * 3.2);
    final h = w * 0.42;
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w, height: h),
      Paint()..color = const Color(0xFFB08A5E),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, -h * 0.08), width: w * 0.62, height: h * 0.55),
      Paint()..color = const Color(0xFF8A6642),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, -h * 0.02), width: w * 0.38, height: h * 0.34),
      Paint()..color = const Color(0xFF2B2118),
    );
  }

  void _paintBoard(Canvas canvas) {
    final cell = layout.cell;
    final p = game.puzzle;
    // Fond de la grille.
    canvas.drawRRect(
      RRect.fromRectAndRadius(layout.boardRect.inflate(cell * 0.5), Radius.circular(cell)),
      Paint()..color = scheme.surfaceContainerHighest.withValues(alpha: 0.5),
    );
    final inset = cell >= 7 ? cell * 0.06 : 0.0;
    final paint = Paint();
    final dim = Paint()..color = scheme.surface.withValues(alpha: 0.38);
    for (int y = 0; y < p.height; y++) {
      for (int x = 0; x < p.width; x++) {
        final i = y * p.width + x;
        final c = p.cells[i];
        if (c < 0) continue;
        final r = Rect.fromLTWH(
          layout.origin.dx + x * cell + inset,
          layout.origin.dy + y * cell + inset,
          cell - 2 * inset,
          cell - 2 * inset,
        );
        paint.color = Color(p.palette[c]);
        canvas.drawRect(r, paint);
        if (!game.accessible[i]) canvas.drawRect(r, dim);
      }
    }
  }

  void _paintSlots(Canvas canvas) {
    for (int s = 0; s < layout.slotRects.length; s++) {
      final r = layout.slotRects[s];
      final bag = game.slots[s];
      if (bag == null) {
        _dashedRRect(canvas, RRect.fromRectAndRadius(r, const Radius.circular(14)), scheme.outlineVariant);
        continue;
      }
      paintBag(
        canvas,
        r,
        Color(game.puzzle.palette[bag.color]),
        bag.remainingInBag > 0 ? '${bag.remainingInBag}' : '',
        dimmed: bag.blocked && bag.remainingInBag > 0,
        sleeping: bag.blocked && bag.remainingInBag > 0,
        time: time,
      );
    }
  }

  void _dashedRRect(Canvas canvas, RRect rr, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rr);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), paint);
        d += 11;
      }
    }
  }

  void _paintAnts(Canvas canvas) {
    final len = math.max(7.0, math.min(layout.cell * 1.05, 16.0));
    final nest = game.nest;
    for (final ant in game.ants) {
      final pos = layout.toPx(ant.x, ant.y);
      // Rapetisse en entrant dans la fourmilière.
      final shrink = ant.phase == AntPhase.returning
          ? (math.sqrt(math.pow(ant.x - nest.x, 2) + math.pow(ant.y - nest.y, 2)) / 0.9).clamp(0.3, 1.0)
          : 1.0;
      paintAnt(
        canvas,
        pos,
        ant.heading,
        len * shrink,
        Color(game.puzzle.palette[ant.color]),
        stride: ant.stride,
        carrying: ant.carrying,
        eating: ant.phase == AntPhase.eating,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}

/// Dessine une fourmi centrée en [pos], orientée selon [heading].
void paintAnt(
  Canvas canvas,
  Offset pos,
  double heading,
  double len,
  Color color, {
  double stride = 0,
  bool carrying = false,
  bool eating = false,
}) {
  canvas.save();
  canvas.translate(pos.dx, pos.dy);
  canvas.rotate(heading);
  const body = Color(0xFF2B2118);
  final legPaint = Paint()
    ..color = body
    ..strokeWidth = math.max(0.8, len * 0.07)
    ..strokeCap = StrokeCap.round;
  final swing = math.sin(stride * 9) * len * 0.12;
  for (int k = -1; k <= 1; k++) {
    final bx = k * len * 0.14;
    final s = (k.isEven ? swing : -swing);
    canvas.drawLine(Offset(bx, 0), Offset(bx + s + k * len * 0.08, -len * 0.36), legPaint);
    canvas.drawLine(Offset(bx, 0), Offset(bx - s + k * len * 0.08, len * 0.36), legPaint);
  }
  final fill = Paint()..color = body;
  // Abdomen (coloré), thorax, tête.
  final abdomen = Rect.fromCenter(center: Offset(-len * 0.28, 0), width: len * 0.46, height: len * 0.34);
  canvas.drawOval(abdomen, Paint()..color = color);
  canvas.drawOval(
    abdomen,
    Paint()
      ..color = body
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, len * 0.07),
  );
  canvas.drawOval(Rect.fromCenter(center: Offset(len * 0.02, 0), width: len * 0.24, height: len * 0.18), fill);
  final headX = len * 0.24 + (eating ? math.sin(stride * 40) * len * 0.03 : 0);
  canvas.drawCircle(Offset(headX, 0), len * 0.12, fill);
  if (carrying) {
    final crumb = Rect.fromCenter(center: Offset(len * 0.44, 0), width: len * 0.26, height: len * 0.26);
    canvas.drawRect(crumb, Paint()..color = color);
    canvas.drawRect(
      crumb,
      Paint()
        ..color = body
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }
  canvas.restore();
}

/// Dessine un petit sachet en papier de couleur [color] avec un nombre.
void paintBag(
  Canvas canvas,
  Rect r,
  Color color,
  String label, {
  bool dimmed = false,
  bool sleeping = false,
  double time = 0,
}) {
  final w = r.width, h = r.height;
  final path = Path()
    ..moveTo(r.left + w * 0.14, r.top + h * 0.18)
    ..lineTo(r.right - w * 0.14, r.top + h * 0.18)
    ..lineTo(r.right - w * 0.04, r.bottom - h * 0.04)
    ..quadraticBezierTo(r.center.dx, r.bottom + h * 0.02, r.left + w * 0.04, r.bottom - h * 0.04)
    ..close();
  canvas.drawShadow(path, Colors.black, 2, false);
  canvas.drawPath(path, Paint()..color = dimmed ? Color.lerp(color, Colors.grey, 0.45)! : color);
  // Rabat du sachet.
  final fold = Rect.fromLTRB(r.left + w * 0.10, r.top + h * 0.06, r.right - w * 0.10, r.top + h * 0.24);
  canvas.drawRRect(
    RRect.fromRectAndRadius(fold, Radius.circular(h * 0.04)),
    Paint()..color = Color.lerp(color, Colors.white, 0.35)!,
  );
  if (label.isNotEmpty) {
    final lum = color.computeLuminance();
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: lum > 0.45 ? const Color(0xFF1F1F1F) : Colors.white,
          fontSize: math.min(w, h) * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(r.center.dx - tp.width / 2, r.top + h * 0.58 - tp.height / 2));
  }
  if (sleeping) {
    final z = TextPainter(
      text: TextSpan(
        text: 'z',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: math.min(w, h) * 0.22,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bob = math.sin(time * 3) * 2;
    z.paint(canvas, Offset(r.right - z.width, r.top - z.height * 0.3 + bob));
  }
}

/// Aperçu statique d'une grille (écran de préparation, écran de victoire).
class PuzzlePreviewPainter extends CustomPainter {
  PuzzlePreviewPainter(this.puzzle);
  final PixelPuzzle puzzle;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / puzzle.width, size.height / puzzle.height);
    final ox = (size.width - cell * puzzle.width) / 2;
    final oy = (size.height - cell * puzzle.height) / 2;
    final paint = Paint();
    for (int y = 0; y < puzzle.height; y++) {
      for (int x = 0; x < puzzle.width; x++) {
        final c = puzzle.cells[y * puzzle.width + x];
        if (c < 0) continue;
        paint.color = Color(puzzle.palette[c]);
        // Léger recouvrement pour éviter les lignes d'anticrénelage.
        canvas.drawRect(Rect.fromLTWH(ox + x * cell, oy + y * cell, cell + 0.5, cell + 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PuzzlePreviewPainter oldDelegate) => oldDelegate.puzzle != puzzle;
}
