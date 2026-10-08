import 'dart:math' as math;
import 'dart:typed_data';

/// Image pixellisée à palette réduite : la grille que les fourmis vident.
class PixelPuzzle {
  PixelPuzzle({required this.width, required this.height, required this.cells, required this.palette})
      : assert(cells.length == width * height);

  final int width;
  final int height;

  /// Index de couleur par case (ligne par ligne), -1 = case vide.
  final List<int> cells;

  /// Couleurs ARGB (0xAARRGGBB).
  final List<int> palette;

  PixelPuzzle copy() => PixelPuzzle(width: width, height: height, cells: List<int>.of(cells), palette: palette);

  int countOf(int color) => cells.where((c) => c == color).length;
}

/// Réduit une image RGBA (déjà décodée) en une grille [targetWidth] × h
/// à [colorCount] couleurs maximum.
PixelPuzzle buildPuzzleFromRgba({
  required Uint8List rgba,
  required int srcWidth,
  required int srcHeight,
  required int targetWidth,
  required int colorCount,
  int seed = 1,
}) {
  // Recadrage centré pour garder un rapport hauteur/largeur raisonnable.
  const minRatio = 0.75; // h / w
  const maxRatio = 1.6;
  int cropX = 0, cropY = 0, cropW = srcWidth, cropH = srcHeight;
  final ratio = srcHeight / srcWidth;
  if (ratio > maxRatio) {
    cropH = (srcWidth * maxRatio).round();
    cropY = (srcHeight - cropH) ~/ 2;
  } else if (ratio < minRatio) {
    cropW = (srcHeight / minRatio).round();
    cropX = (srcWidth - cropW) ~/ 2;
  }

  final w = math.max(4, math.min(targetWidth, cropW));
  final h = math.max(4, (w * cropH / cropW).round());

  // Moyenne par bloc (box filter).
  final pixels = List<List<double>>.generate(w * h, (_) => [0, 0, 0]);
  for (int gy = 0; gy < h; gy++) {
    final y0 = cropY + (gy * cropH) ~/ h;
    final y1 = math.max(y0 + 1, cropY + ((gy + 1) * cropH) ~/ h);
    for (int gx = 0; gx < w; gx++) {
      final x0 = cropX + (gx * cropW) ~/ w;
      final x1 = math.max(x0 + 1, cropX + ((gx + 1) * cropW) ~/ w);
      double r = 0, g = 0, b = 0;
      int n = 0;
      for (int y = y0; y < y1 && y < srcHeight; y++) {
        for (int x = x0; x < x1 && x < srcWidth; x++) {
          final i = (y * srcWidth + x) * 4;
          r += rgba[i];
          g += rgba[i + 1];
          b += rgba[i + 2];
          n++;
        }
      }
      if (n == 0) n = 1;
      pixels[gy * w + gx] = [r / n, g / n, b / n];
    }
  }

  final result = quantize(pixels, colorCount, seed: seed);
  return PixelPuzzle(width: w, height: h, cells: result.labels, palette: result.palette);
}

class QuantizeResult {
  QuantizeResult(this.labels, this.palette);
  final List<int> labels;
  final List<int> palette;
}

/// K-means (initialisation k-means++) sur des pixels RGB, puis suppression
/// des couleurs trop rares. Palette triée par luminosité.
QuantizeResult quantize(List<List<double>> pixels, int k, {int seed = 1}) {
  final rnd = math.Random(seed);
  final n = pixels.length;
  k = math.max(1, math.min(k, n));

  double dist(List<double> a, List<double> b) {
    final dr = a[0] - b[0], dg = a[1] - b[1], db = a[2] - b[2];
    // Pondération perceptuelle simple.
    return 0.30 * dr * dr + 0.59 * dg * dg + 0.11 * db * db;
  }

  // k-means++
  final centers = <List<double>>[List<double>.of(pixels[rnd.nextInt(n)])];
  final d2 = List<double>.filled(n, double.infinity);
  while (centers.length < k) {
    double total = 0;
    for (int i = 0; i < n; i++) {
      final d = dist(pixels[i], centers.last);
      if (d < d2[i]) d2[i] = d;
      total += d2[i];
    }
    if (total <= 0) break;
    double r = rnd.nextDouble() * total;
    int pick = n - 1;
    for (int i = 0; i < n; i++) {
      r -= d2[i];
      if (r <= 0) {
        pick = i;
        break;
      }
    }
    centers.add(List<double>.of(pixels[pick]));
  }

  final labels = List<int>.filled(n, 0);

  void assign() {
    for (int i = 0; i < n; i++) {
      double best = double.infinity;
      int bi = 0;
      for (int c = 0; c < centers.length; c++) {
        final d = dist(pixels[i], centers[c]);
        if (d < best) {
          best = d;
          bi = c;
        }
      }
      labels[i] = bi;
    }
  }

  List<int> update() {
    final sums = List<List<double>>.generate(centers.length, (_) => [0, 0, 0]);
    final counts = List<int>.filled(centers.length, 0);
    for (int i = 0; i < n; i++) {
      final l = labels[i];
      sums[l][0] += pixels[i][0];
      sums[l][1] += pixels[i][1];
      sums[l][2] += pixels[i][2];
      counts[l]++;
    }
    for (int c = 0; c < centers.length; c++) {
      if (counts[c] > 0) {
        centers[c] = [sums[c][0] / counts[c], sums[c][1] / counts[c], sums[c][2] / counts[c]];
      }
    }
    return counts;
  }

  for (int it = 0; it < 16; it++) {
    assign();
    update();
  }

  // Supprime les couleurs trop rares (moins de 1,5 % des cases).
  final minCount = math.max(3, (n * 0.015).ceil());
  for (int pass = 0; pass < 3; pass++) {
    assign();
    final counts = update();
    final keep = <int>[];
    for (int c = 0; c < centers.length; c++) {
      if (counts[c] >= minCount) keep.add(c);
    }
    if (keep.isEmpty || keep.length == centers.length) break;
    final kept = [for (final c in keep) centers[c]];
    centers
      ..clear()
      ..addAll(kept);
  }
  assign();
  update();

  // Tri par luminosité pour une palette lisible et des index stables.
  final order = List<int>.generate(centers.length, (i) => i)
    ..sort((a, b) {
      double lum(List<double> c) => 0.30 * c[0] + 0.59 * c[1] + 0.11 * c[2];
      return lum(centers[a]).compareTo(lum(centers[b]));
    });
  final remap = List<int>.filled(centers.length, 0);
  for (int i = 0; i < order.length; i++) {
    remap[order[i]] = i;
  }
  final palette = [
    for (final c in order)
      0xFF000000 |
          (c255(centers[c][0]) << 16) |
          (c255(centers[c][1]) << 8) |
          c255(centers[c][2]),
  ];
  return QuantizeResult([for (final l in labels) remap[l]], palette);
}

int c255(double v) => v.round().clamp(0, 255).toInt();

/// Image d'exemple générée (aucune photo nécessaire) : paysage stylisé.
PixelPuzzle generateSamplePuzzle({int width = 28, int seed = 7}) {
  final rnd = math.Random(seed);
  final h = (width * 1.25).round();
  const palette = [
    0xFF2E4A3D, // sapin
    0xFF5B8C5A, // herbe
    0xFFE07A5F, // soleil couchant
    0xFFF2CC8F, // sable
    0xFF81B29A, // colline
    0xFFA8DADC, // ciel
  ];
  final cells = List<int>.filled(width * h, 5);
  final sunX = width * (0.3 + rnd.nextDouble() * 0.4), sunY = h * 0.25, sunR = width * 0.16;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < width; x++) {
      int c = 5;
      final dx = x - sunX, dy = y - sunY;
      if (dx * dx + dy * dy < sunR * sunR) c = 2;
      final hill = h * 0.48 + math.sin(x / width * math.pi * 2 + seed) * h * 0.06;
      if (y > hill) c = 4;
      final grass = h * 0.68 + math.sin(x / width * math.pi * 3 + seed * 2) * h * 0.04;
      if (y > grass) c = 1;
      if (y > h * 0.86) c = 3;
      cells[y * width + x] = c;
    }
  }
  // Quelques sapins.
  for (int t = 0; t < 3; t++) {
    final tx = 3 + rnd.nextInt(width - 6);
    final base = (h * 0.70).round();
    for (int k = 0; k < 7; k++) {
      final half = k ~/ 2;
      final y = base - 7 + k;
      for (int x = tx - half; x <= tx + half; x++) {
        if (x >= 0 && x < width && y >= 0) cells[y * width + x] = 0;
      }
    }
  }
  return PixelPuzzle(width: width, height: h, cells: cells, palette: palette);
}
