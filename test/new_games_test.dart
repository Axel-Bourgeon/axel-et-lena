import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:axel_lena/core/settings.dart';
import 'package:axel_lena/games/croix/engine.dart';
import 'package:axel_lena/games/motdujour/duel.dart';
import 'package:axel_lena/games/questions/questions_page.dart';
import 'package:axel_lena/tools/respiration/respiration.dart';

List<Placement> word(String w, int r, int c, {bool vertical = false}) => [
      for (int i = 0; i < w.length; i++) Placement(vertical ? r + i : r, vertical ? c : c + i, Tile(w[i])),
    ];

Map<int, Tile> apply(Map<int, Tile> board, List<Placement> p) =>
    {...board, for (final x in p) cellKey(x.r, x.c): x.tile};

void main() {
  group('Mots en croix', () {
    test('plateau symétrique, étoile au centre', () {
      expect(bonusAt(7, 7), Bonus.start);
      for (int r = 0; r < kSize; r++) {
        for (int c = 0; c < kSize; c++) {
          expect(bonusAt(r, c), bonusAt(c, r));
          expect(bonusAt(r, c), bonusAt(kSize - 1 - r, c));
        }
      }
    });

    test('sac de 101 jetons', () {
      expect(fullBag(math.Random(1)).length, 101);
      expect(kCounts.keys.toSet(), kValues.keys.toSet());
    });

    test('premier mot : doit passer par l\'étoile', () {
      expect(evaluate({}, word('CHAT', 0, 0)).ok, isFalse);
      final e = evaluate({}, word('CHAT', 7, 6));
      expect(e.ok, isTrue);
      expect(e.words.single.text, 'CHAT');
      // C3 H4 A1 T1 = 9, étoile (7,7) = mot ×2 → 18
      expect(e.score, 18);
    });

    test('mot croisé, toucher et continuité', () {
      final b = apply({}, word('CHAT', 7, 6));
      // « HOTE » vertical passant par le H en (7,7)
      final e = evaluate(b, [Placement(8, 7, const Tile('O')), Placement(9, 7, const Tile('T')), Placement(10, 7, const Tile('E'))]);
      expect(e.ok, isTrue);
      expect(e.words.first.text, 'HOTE');
      expect(evaluate(b, word('LOIN', 0, 0)).error, contains('toucher'));
      expect(evaluate(b, [Placement(8, 7, const Tile('O')), Placement(10, 7, const Tile('E'))]).error, contains('suivre'));
      expect(evaluate(b, [Placement(8, 6, const Tile('O')), Placement(9, 7, const Tile('E'))]).ok, isFalse);
    });

    test('lettre seule : mots dans les deux sens', () {
      final b = apply({}, word('LA', 7, 7));
      final e = evaluate(b, [Placement(8, 7, const Tile('E'))]);
      expect(e.words.map((w) => w.text), ['LE']);
      final e2 = evaluate(b, [Placement(7, 9, const Tile('S'))]);
      expect(e2.words.single.text, 'LAS');
    });

    test('joker à 0 point, chevalet', () {
      expect(const Tile('Z', joker: true).value, 0);
      expect(Tile.fromCode('z').joker, isTrue);
      expect(Tile.fromCode('Z').joker, isFalse);
      expect(removeFromRack(['A', '?', 'B'], [const Tile('A'), const Tile('X', joker: true)]), ['B']);
      expect(removeFromRack(['A'], [const Tile('B')]), isNull);
    });

    test('7 lettres : +50', () {
      final e = evaluate({}, word('MAISONS', 7, 4));
      expect(e.ok, isTrue);
      expect(e.score, greaterThan(kBingo));
    });

    test('dictionnaire présent et en majuscules', () {
      final lines = File('assets/words/dico.txt').readAsLinesSync();
      expect(lines.length, greaterThan(100000));
      expect(lines, containsAll(['MAISON', 'BEBE', 'ZEN']));
      expect(lines.every((l) => RegExp(r'^[A-Z]{2,15}$').hasMatch(l)), isTrue);
    });
  });

  group('Mot du jour à deux', () {
    test('motif et classement', () {
      final r = resultOf(['saint', 'sable'], 'sable');
      expect(r.won, isTrue);
      expect(r.tries, 2);
      expect(r.pattern.split('|').last, 'ggggg');
      final lost = resultOf(List.filled(6, 'saint'), 'sable');
      expect(lost.won, isFalse);
      expect(lost.rank, greaterThan(r.rank));
    });

    test('face-à-face', () {
      const a3 = DuelResult(tries: 3, won: true, pattern: '');
      const a4 = DuelResult(tries: 4, won: true, pattern: '');
      const x = DuelResult(tries: 6, won: false, pattern: '');
      final s = DuelStats({
        1: {Person.axel: a3, Person.lena: a4},
        2: {Person.axel: x, Person.lena: a4},
        3: {Person.axel: a3, Person.lena: a3},
        4: {Person.lena: a3},
      });
      expect(s.both, 3);
      expect(s.duelWins[Person.axel], 1);
      expect(s.duelWins[Person.lena], 1);
      expect(s.ties, 1);
      expect(s.played[Person.lena], 4);
      expect(s.average(Person.axel), 3);
      expect(s.dist[Person.lena]![3], 2);
    });
  });

  group('Questions de couple', () {
    test('banque valide', () {
      final cats = parseQuestions(File('assets/questions/questions.json').readAsStringSync());
      expect(cats.length, greaterThanOrEqualTo(5));
      final all = cats.expand((c) => c.questions).toList();
      expect(all.length, greaterThan(200));
      expect(all.toSet().length, all.length);
      expect(cats.map((c) => c.id).toSet().length, cats.length);
      expect(jsonDecode(File('assets/questions/questions.json').readAsStringSync()), isA<Map<String, dynamic>>());
    });

    test('pas de répétition avant d\'avoir tout vu', () {
      const c = QuestionCategory('x', 'X', ['a', 'b', 'c']);
      final pool = [for (int i = 0; i < 3; i++) QuestionRef(c, i)];
      final seen = <String>{};
      final rnd = math.Random(3);
      final got = <String>{};
      for (int i = 0; i < 3; i++) {
        final q = drawQuestion(pool, seen, rnd)!;
        got.add(q.id);
        seen.add(q.id);
      }
      expect(got.length, 3);
      expect(drawQuestion(pool, seen, rnd), isNotNull);
      expect(seen, isEmpty);
    });
  });

  group('Respiration', () {
    const r = BreathRhythm(5, 5, '');
    test('la bulle monte puis descend', () {
      expect(breathAt(0, r).level, closeTo(0, 1e-9));
      expect(breathAt(0, r).inhaling, isTrue);
      expect(breathAt(5, r).level, closeTo(1, 1e-9));
      expect(breathAt(5, r).inhaling, isFalse);
      expect(breathAt(7.5, r).level, closeTo(0.5, 1e-9));
      expect(breathAt(12, r).cycleIndex, 1);
      expect(60 / r.cycle, 6); // 6 respirations par minute
    });

    test('sons WAV', () {
      final w = glideTone(seconds: 1, rising: true);
      expect(String.fromCharCodes(w.sublist(0, 4)), 'RIFF');
      expect(w.length, 44 + 44100 * 2);
      expect(chimeTone().length, greaterThan(44));
    });
  });
}
