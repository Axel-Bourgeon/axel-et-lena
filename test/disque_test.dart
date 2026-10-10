import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/games/disque/deck.dart';

void main() {
  final deck = DisqueDeck.fromJson(File('assets/disque/concepts.json').readAsStringSync());

  test('la banque de concepts est bien remplie', () {
    expect(deck.pairs.length, greaterThanOrEqualTo(200));
    expect(deck.themes.length, greaterThanOrEqualTo(10));
    expect(deck.themes.values.every((v) => v.length >= 10), isTrue);
    for (final p in deck.pairs) {
      expect(p.left.trim(), isNotEmpty);
      expect(p.right.trim(), isNotEmpty);
      expect(p.left, isNot(p.right));
    }
    // JSON propre (pas de clés inattendues).
    final raw = jsonDecode(File('assets/disque/concepts.json').readAsStringSync()) as Map;
    expect(raw.keys.toSet(), {'pairs', 'themes'});
  });

  test('tirages : deux propositions différentes, thèmes et couples', () {
    final rnd = math.Random(4);
    int fromTheme = 0;
    for (int i = 0; i < 500; i++) {
      final p = deck.draw(rnd);
      expect(p.left, isNot(p.right));
      if (p.theme != null) {
        fromTheme++;
        expect(deck.themes[p.theme]!, containsAll([p.left, p.right]));
      }
    }
    expect(fromTheme, inInclusiveRange(80, 230)); // ~30 %
  });

  test('points selon l\'écart', () {
    expect(DisqueDeck.score(50, 50), 4);
    expect(DisqueDeck.score(50, 54), 4);
    expect(DisqueDeck.score(50, 59), 3);
    expect(DisqueDeck.score(50, 33), 2);
    expect(DisqueDeck.score(50, 80), 0);
  });
}
