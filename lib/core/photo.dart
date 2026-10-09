import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

/// Outils d'image partagés par les jeux photo (Fourmis, Taquin, Picross,
/// Pipopipette).

/// L'accès à la galerie a été refusé.
class GalleryAccessDenied implements Exception {
  @override
  String toString() => "Accès aux photos refusé (Réglages Android → Applis → Axel & Léna → Autorisations)";
}

/// Photo tirée au hasard dans la galerie (album de l'appareil photo de
/// préférence, pour éviter les captures d'écran). null si aucune photo.
Future<ui.Image?> randomGalleryImage({int maxSide = 1400, math.Random? rnd}) async {
  final ps = await PhotoManager.requestPermissionExtend();
  if (!ps.hasAccess) throw GalleryAccessDenied();
  final paths = await PhotoManager.getAssetPathList(type: RequestType.image);
  if (paths.isEmpty) return null;
  bool isCamera(AssetPathEntity p) {
    final n = p.name.toLowerCase();
    return n.contains('camera') || n.contains('appareil') || n.contains('dcim');
  }

  final candidates = [
    ...paths.where(isCamera),
    ...paths.where((p) => p.isAll),
    ...paths,
  ];
  final r = rnd ?? math.Random();
  for (final path in candidates) {
    final count = await path.assetCountAsync;
    if (count == 0) continue;
    final i = r.nextInt(count);
    final assets = await path.getAssetListRange(start: i, end: i + 1);
    if (assets.isEmpty) continue;
    final bytes = await assets.first.thumbnailDataWithSize(ThumbnailSize(maxSide, maxSide), quality: 92);
    if (bytes == null) continue;
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }
  return null;
}

enum PhotoSource { gallery, camera, random }

/// Photo carrée depuis la galerie, l'appareil ou au hasard. null si annulé.
Future<ui.Image?> squarePhotoFrom(PhotoSource source) async {
  switch (source) {
    case PhotoSource.gallery:
      return pickSquarePhoto(ImageSource.gallery);
    case PhotoSource.camera:
      return pickSquarePhoto(ImageSource.camera);
    case PhotoSource.random:
      final img = await randomSquarePhoto();
      if (img == null) throw Exception('aucune photo dans la galerie');
      return img;
  }
}

/// Message d'erreur lisible pour un chargement de photo raté.
String photoErrorMessage(Object e) =>
    e is GalleryAccessDenied ? '$e' : "Impossible de charger l'image ($e)";

/// Boutons Galerie / Photo / Au hasard / Surprise des écrans de préparation.
class PhotoSourceButtons extends StatelessWidget {
  const PhotoSourceButtons({super.key, required this.enabled, required this.onSource, required this.onSurprise});

  final bool enabled;
  final void Function(PhotoSource source) onSource;
  final VoidCallback onSurprise;

  @override
  Widget build(BuildContext context) {
    Widget b(IconData icon, String label, VoidCallback onTap) =>
        FilledButton.tonalIcon(onPressed: enabled ? onTap : null, icon: Icon(icon), label: Text(label));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        b(Icons.photo_library_outlined, 'Galerie', () => onSource(PhotoSource.gallery)),
        b(Icons.photo_camera_outlined, 'Photo', () => onSource(PhotoSource.camera)),
        b(Icons.casino_outlined, 'Au hasard', () => onSource(PhotoSource.random)),
        b(Icons.auto_awesome_outlined, 'Surprise', onSurprise),
      ],
    );
  }
}

/// Aperçu carré de la photo, ou carte « Photo mystère » si elle a été tirée
/// au hasard (pour garder la surprise).
class PhotoPreview extends StatelessWidget {
  const PhotoPreview({super.key, required this.image, required this.mystery, required this.loading});

  final ui.Image? image;
  final bool mystery;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = image;
    Widget child;
    if (loading || img == null) {
      child = const Center(child: CircularProgressIndicator());
    } else if (mystery) {
      child = ColoredBox(
        color: scheme.primaryContainer,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.help_outline, size: 64, color: scheme.onPrimaryContainer),
            const SizedBox(height: 8),
            Text('Photo mystère', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
    } else {
      child = RawImage(image: img, fit: BoxFit.cover);
    }
    return AspectRatio(aspectRatio: 1, child: Card(clipBehavior: Clip.antiAlias, child: child));
  }
}

/// Comme [randomGalleryImage], recadrée au carré.
Future<ui.Image?> randomSquarePhoto({int maxSide = 1080}) async {
  final img = await randomGalleryImage();
  if (img == null) return null;
  final out = await cropSquare(img, maxSide: maxSide);
  img.dispose();
  return out;
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
