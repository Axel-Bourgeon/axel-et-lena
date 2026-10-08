import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/games/fourmis/palette.dart';

/// Écart de teinte approximatif (rouge-vert / bleu-jaune) entre deux couleurs.
int _hueGap(int a, int b) {
  int ch(int c, int s) => (c >> s) & 0xFF;
  final da = (ch(a, 16) - ch(a, 8)) - (ch(b, 16) - ch(b, 8));
  final db = (ch(a, 8) - ch(a, 0)) - (ch(b, 8) - ch(b, 0));
  return da.abs() + db.abs();
}

void main() {
  // Paysage typique : 3 verts et 3 gris.
  const landscape = [0xFF2E4A3D, 0xFF4F7A4A, 0xFF7FA36B, 0xFF6E6E6E, 0xFF9A9A9A, 0xFFC8C8C8];

  int minHueGap(List<int> p) {
    int m = 1 << 30;
    for (int i = 0; i < p.length; i++) {
      for (int j = i + 1; j < p.length; j++) {
        final g = _hueGap(p[i], p[j]);
        if (g < m) m = g;
      }
    }
    return m;
  }

  test('« Fidèles » ne change rien', () {
    expect(separatePalette(landscape, ColorContrast.faithful), landscape);
  });

  for (final c in [ColorContrast.contrasted, ColorContrast.strong]) {
    test('${c.label} : les couleurs se distinguent davantage par la teinte', () {
      final out = separatePalette(landscape, c);
      expect(out.length, landscape.length);
      expect(out.every((v) => (v >> 24) == 0xFF), isTrue);
      expect(minHueGap(out), greaterThan(minHueGap(landscape) + 8));
    });
  }

  test('déterministe et sans plantage sur des couleurs identiques', () {
    const same = [0xFF808080, 0xFF808080, 0xFF808080];
    final a = separatePalette(same, ColorContrast.contrasted);
    expect(a, separatePalette(same, ColorContrast.contrasted));
    expect(a.toSet().length, 3);
  });
}
