import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/games/motdujour/engine.dart';

List<String> _lines(String path) =>
    File(path).readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

void main() {
  const a = LetterState.absent, p = LetterState.present, c = LetterState.correct;

  test('couleurs, y compris les lettres en double', () {
    expect(WordOfTheDay.score('table', 'table'), [c, c, c, c, c]);
    expect(WordOfTheDay.score('balle', 'table'), [p, c, a, c, c]);
    // Un seul E dans la réponse : un seul E coloré.
    expect(WordOfTheDay.score('eeeee', 'arbre'), [a, a, a, a, c]);
    expect(WordOfTheDay.score('arret', 'terre'), [a, p, c, p, p]);
  });

  test('même mot pour une même date, quel que soit l\'ordre de la liste', () {
    final words = ['aimer', 'table', 'pomme', 'fleur', 'livre'];
    final w1 = WordOfTheDay(answers: words, valid: {});
    final w2 = WordOfTheDay(answers: words.reversed.toList(), valid: {});
    for (int d = 0; d < 20; d++) {
      expect(w1.wordFor(d), w2.wordFor(d));
    }
    // Chaque mot sort une fois par cycle.
    expect({for (int d = 0; d < 5; d++) w1.wordFor(d)}.length, 5);
  });

  test('numéro du jour', () {
    expect(WordOfTheDay.dayIndex(DateTime(2026, 10, 9, 23, 59)), 0);
    expect(WordOfTheDay.dayIndex(DateTime(2026, 10, 10, 0, 1)), 1);
  });

  test('accents retirés', () {
    expect(normalizeWord('Élève'), 'eleve');
    expect(normalizeWord('cœur'), 'coeur');
  });

  test('listes de mots fournies : 5 lettres a-z, réponses toutes acceptées', () {
    final answers = _lines('assets/words/answers.txt');
    final valid = _lines('assets/words/valid.txt').toSet();
    expect(answers.length, greaterThan(1000));
    final re = RegExp(r'^[a-z]{5}$');
    expect(answers.every(re.hasMatch), isTrue);
    expect(valid.every(re.hasMatch), isTrue);
    expect(answers.every(valid.contains), isTrue);
  });

  test('texte à partager', () {
    final t = shareText(0, ['arbre', 'table'], 'table');
    expect(t, contains('2/6'));
    expect(t, contains('🟩🟩🟩🟩🟩'));
  });
}
