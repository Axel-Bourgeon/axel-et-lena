import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/games/airhockey/engine.dart';

void main() {
  test('les maillets restent dans leur camp', () {
    final g = AirHockey();
    g.setTarget(0, const Vec(0.5, 0.1)); // le joueur du bas vise le haut
    g.update(1 / 60);
    expect(g.mallets[0].y, greaterThan(g.height / 2));
    g.setTarget(1, const Vec(-3, 9)); // hors table
    g.update(1 / 60);
    expect(g.mallets[1].y, lessThan(g.height / 2));
    expect(g.mallets[1].x, greaterThanOrEqualTo(AirHockey.malletR));
  });

  test('un palet lancé droit dans le but du haut marque pour le bas', () {
    final g = AirHockey();
    g.mallets[1] = const Vec(0.1, 0.1); // gardien écarté
    g.setTarget(1, const Vec(0.1, 0.1));
    g.puck = Vec(0.5, g.height * 0.6);
    g.puckVel = const Vec(0, -3);
    for (int i = 0; i < 120 && g.scores[0] == 0; i++) {
      g.update(1 / 60);
    }
    expect(g.scores[0], 1);
    expect(g.lastScorer, 0);
    expect(g.pause, greaterThan(0));
  });

  test('le palet rebondit sur les bords et reste sur la table', () {
    final g = AirHockey();
    g.puckVel = const Vec(3, 1.3);
    for (int i = 0; i < 600; i++) {
      g.update(1 / 60);
      expect(g.puck.x, inInclusiveRange(0, 1));
    }
  });

  test('frapper le palet le met en mouvement', () {
    final g = AirHockey();
    final start = g.puck;
    g.setTarget(0, Vec(start.x, start.y + 0.2));
    g.update(1 / 60);
    g.setTarget(0, start);
    for (int i = 0; i < 5; i++) {
      g.update(1 / 60);
    }
    expect(g.puckVel.y, lessThan(0)); // part vers le haut
  });

  test('partie contre le téléphone sans plantage', () {
    final g = AirHockey(winScore: 3);
    g.puckVel = const Vec(0.4, -2);
    for (int i = 0; i < 60 * 120 && g.winner < 0; i++) {
      g.phoneControl(1 / 60);
      g.update(1 / 60);
    }
    expect(g.scores[0] + g.scores[1], greaterThanOrEqualTo(0));
  });
}
