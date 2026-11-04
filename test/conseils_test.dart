import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/couple/conseils.dart';

void main() {
  final book = AdviceBook.fromJson(File('assets/conseils/conseils.json').readAsStringSync());

  test('contenu complet et cohérent', () {
    final themeIds = book.themes.map((t) => t.id).toSet();
    expect(book.advice.length, greaterThanOrEqualTo(20));
    expect(book.advice.map((a) => a.id).toSet().length, book.advice.length, reason: 'ids uniques');
    for (final a in book.advice) {
      expect(themeIds, contains(a.theme), reason: a.id);
      expect(a.sources, isNotEmpty, reason: '${a.id} doit citer une source');
      expect(a.sources.every((s) => s.url.startsWith('https://')), isTrue, reason: a.id);
      expect(a.minMonths, lessThan(a.maxMonths), reason: a.id);
      expect(a.body.trim(), isNotEmpty);
    }
    // Chaque thème a au moins un conseil.
    for (final t in themeIds) {
      expect(book.advice.any((a) => a.theme == t), isTrue, reason: t);
    }
  });

  test('numéros d\'urgence', () {
    final numbers = {for (final n in book.numbers) n.number};
    expect(numbers, containsAll(['15', '112', '119']));
    expect(book.numbers.firstWhere((n) => n.number == '0140054848').display, '01 40 05 48 48');
  });

  test('filtres âge et recherche', () {
    final choke = book.advice.firstWhere((a) => a.id == 'etouffement-bebe');
    expect(choke.coversRange(0, 3), isTrue);
    expect(choke.coversRange(12, 24), isFalse);
    expect(choke.matches('etouffe'), isTrue); // sans accent
    expect(choke.matches('biberon'), isFalse);
    expect(choke.ageLabel, '0–12 mois');
    expect(book.advice.firstWhere((a) => a.id == 'couchage').ageLabel, 'Tous âges');
    expect(book.advice.firstWhere((a) => a.id == 'eveil-9-24').ageLabel, '9–24 mois');
  });
}
