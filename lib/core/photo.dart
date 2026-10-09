import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Outils d'image partagés par les jeux photo (Taquin, Picross).

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

/// Choisit une photo (galerie ou appareil) et la recadre au carré.
/// null si l'utilisateur annule.
Future<ui.Image?> pickSquarePhoto(ImageSource source, {int maxSide = 1080}) async {
  final file = await ImagePicker().pickImage(source: source, maxWidth: 1400, maxHeight: 1400, imageQuality: 92);
  if (file == null) return null;
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final frame = await codec.getNextFrame();
  final out = await cropSquare(frame.image, maxSide: maxSide);
  frame.image.dispose();
  return out;
}

/// Pixels RGBA bruts d'une image.
Future<Uint8List> rgbaOf(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('décodage impossible');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
