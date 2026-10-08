import 'dart:math' as math;

/// Niveau d'écartement des couleurs de la palette.
enum ColorContrast {
  faithful('Fidèles', 0, 0, 0),
  contrasted('Contrastées', 0.40, 0.19, 0.011),
  strong('Extrêmes', 0.35, 0.23, 0.013);

  const ColorContrast(this.label, this.lightnessWeight, this.baseGap, this.gapPerColor);

  final String label;

  /// Poids de la clarté dans la distance : faible => les couleurs doivent
  /// surtout se distinguer par leur teinte (pas « vert foncé / vert clair »).
  final double lightnessWeight;
  final double baseGap;
  final double gapPerColor;

  /// Écart minimal visé entre deux couleurs (plus serré s'il y en a beaucoup).
  double minGap(int k) => math.max(0.10, baseGap - gapPerColor * k);
}

/// Éloigne les couleurs de [palette] (ARGB) les unes des autres pour qu'elles
/// soient faciles à distinguer, quitte à s'écarter de l'image d'origine.
///
/// Travaille dans l'espace perceptuel Oklab : les paires trop proches sont
/// repoussées (surtout en teinte), avec un léger rappel vers la couleur
/// d'origine et un maintien dans le gamut sRGB.
List<int> separatePalette(List<int> palette, ColorContrast contrast, {int seed = 1}) {
  final k = palette.length;
  if (contrast == ColorContrast.faithful || k < 2) return palette;
  final rnd = math.Random(seed);
  final lw = contrast.lightnessWeight;
  final gap = contrast.minGap(k);

  final orig = [for (final c in palette) _toLab(c)];
  final pts = [for (final p in orig) List<double>.of(p)];

  double dist(List<double> p, List<double> q) {
    final dl = lw * (p[0] - q[0]), da = p[1] - q[1], db = p[2] - q[2];
    return math.sqrt(dl * dl + da * da + db * db);
  }

  for (int it = 0; it < 400; it++) {
    bool moved = false;
    for (int i = 0; i < k; i++) {
      for (int j = i + 1; j < k; j++) {
        final p = pts[i], q = pts[j];
        final d = dist(p, q);
        if (d >= gap) continue;
        moved = true;
        var u = [lw * (q[0] - p[0]), q[1] - p[1], q[2] - p[2]];
        final n = math.sqrt(u[0] * u[0] + u[1] * u[1] + u[2] * u[2]);
        if (n < 1e-6) {
          final a = rnd.nextDouble() * 2 * math.pi;
          u = [0, math.cos(a), math.sin(a)];
        } else {
          u = [u[0] / n, u[1] / n, u[2] / n];
        }
        // Petite composante aléatoire en teinte : évite que deux gris ne
        // s'écartent qu'en clarté.
        final a = rnd.nextDouble() * 2 * math.pi;
        u[1] += 0.3 * math.cos(a);
        u[2] += 0.3 * math.sin(a);
        final push = (gap - d) / 2 * 1.05;
        p[0] -= u[0] * push / lw * 0.5;
        q[0] += u[0] * push / lw * 0.5;
        p[1] -= u[1] * push;
        q[1] += u[1] * push;
        p[2] -= u[2] * push;
        q[2] += u[2] * push;
      }
    }
    for (int i = 0; i < k; i++) {
      for (int c = 0; c < 3; c++) {
        pts[i][c] += (orig[i][c] - pts[i][c]) * 0.02;
      }
      pts[i] = _clampGamut(pts[i]);
    }
    if (!moved && it > 5) break;
  }
  return [for (final p in pts) _fromLab(p)];
}

double _srgbToLinear(int c) {
  final v = c / 255;
  return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

int _linearToSrgb(double c) {
  final v = c.clamp(0.0, 1.0);
  final s = v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
  return (s * 255).round().clamp(0, 255);
}

double _cbrt(double x) => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

List<double> _toLab(int argb) {
  final r = _srgbToLinear((argb >> 16) & 0xFF);
  final g = _srgbToLinear((argb >> 8) & 0xFF);
  final b = _srgbToLinear(argb & 0xFF);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  ];
}

List<double> _labToLinear(List<double> lab) {
  final l0 = lab[0] + 0.3963377774 * lab[1] + 0.2158037573 * lab[2];
  final m0 = lab[0] - 0.1055613458 * lab[1] - 0.0638541728 * lab[2];
  final s0 = lab[0] - 0.0894841775 * lab[1] - 1.2914855480 * lab[2];
  final l = l0 * l0 * l0, m = m0 * m0 * m0, s = s0 * s0 * s0;
  return [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  ];
}

/// Garde la clarté dans une plage lisible et réduit la saturation jusqu'à
/// rentrer dans sRGB (la teinte est conservée).
List<double> _clampGamut(List<double> lab) {
  final l = lab[0].clamp(0.18, 0.95).toDouble();
  double a = lab[1], b = lab[2];
  for (int i = 0; i < 30; i++) {
    if (_labToLinear([l, a, b]).every((v) => v >= -1e-4 && v <= 1 + 1e-4)) break;
    a *= 0.9;
    b *= 0.9;
  }
  return [l, a, b];
}

int _fromLab(List<double> lab) {
  final rgb = _labToLinear(lab);
  return 0xFF000000 | (_linearToSrgb(rgb[0]) << 16) | (_linearToSrgb(rgb[1]) << 8) | _linearToSrgb(rgb[2]);
}
