import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/couple/baby_log.dart';
import 'package:axel_lena/couple/cloud.dart';

void main() {
  test('codes d\'espace lisibles et normalisés', () {
    final code = CoupleCloud.newCode(math.Random(1));
    expect(code.length, 10);
    expect(RegExp(r'^[A-HJKMNP-Z2-9]{10}$').hasMatch(code), isTrue);
    expect(CoupleCloud.normalizeCode(' abcde-23456 '), 'ABCDE23456');
  });

  test('« il y a … »', () {
    final now = DateTime(2027, 5, 10, 14, 0);
    expect(agoLabel(now.subtract(const Duration(seconds: 20)), now: now), "à l'instant");
    expect(agoLabel(now.subtract(const Duration(minutes: 45)), now: now), 'il y a 45 min');
    expect(agoLabel(now.subtract(const Duration(hours: 2, minutes: 5)), now: now), 'il y a 2 h 05');
    expect(agoLabel(now.subtract(const Duration(hours: 3)), now: now), 'il y a 3 h');
    expect(agoLabel(DateTime(2027, 5, 8, 22, 40), now: now), 'le 8 mai à 22:40');
  });

  test('agenda bébé : dernière entrée par type et lait sur 24 h', () {
    final now = DateTime(2027, 5, 10, 14, 0);
    final entries = [
      BabyEntry(kind: BabyKind.bottle, at: now.subtract(const Duration(hours: 1)), by: 'lena', ml: 120),
      BabyEntry(kind: BabyKind.diaper, at: now.subtract(const Duration(hours: 2)), by: 'axel', diaper: Diaper.dirty),
      BabyEntry(kind: BabyKind.bottle, at: now.subtract(const Duration(hours: 4)), by: 'axel', ml: 90, note: 'a tout bu'),
      BabyEntry(kind: BabyKind.bottle, at: now.subtract(const Duration(hours: 30)), by: 'axel', ml: 100),
    ];
    final latest = latestByKind(entries);
    expect(latest[BabyKind.bottle]!.ml, 120);
    expect(latest[BabyKind.diaper]!.details, 'Caca');
    expect(latest.containsKey(BabyKind.sleep), isFalse);
    expect(bottleMlLast24h(entries, now), 210);
    expect(entries[2].details, '90 mL · a tout bu');
    expect(entries[0].toMap()['kind'], 'bottle');
  });
}
