import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/core/together.dart';

void main() {
  final since = DateTime.utc(2017, 6, 1);

  test('nombre de jours et détail', () {
    final s = togetherSpan(since, DateTime.utc(2026, 10, 9));
    expect(s.days, 3417);
    expect(s.years, 9);
    expect(s.months, 4);
    expect(s.restDays, 8);
    expect(s.detail, '9 ans, 4 mois et 8 jours');
    expect(s.isAnniversary, isFalse);
  });

  test('anniversaire', () {
    final s = togetherSpan(since, DateTime.utc(2027, 6, 1));
    expect(s.isAnniversary, isTrue);
    expect(s.years, 10);
  });

  test('jour du mois inférieur au jour de départ', () {
    final s = togetherSpan(DateTime.utc(2017, 1, 31), DateTime.utc(2017, 3, 1));
    expect(s.months, 1);
    expect(s.restDays, 1);
  });

  test('décompte bébé', () {
    final b = BabyCountdown(DateTime.utc(2027, 5, 1), DateTime.utc(2026, 11, 3));
    expect(b.daysLeft, 179);
    expect(b.label, 'Bébé arrive dans 179 jours');
    expect(b.pregnancyLabel, '15 SA + 3 j');
    expect(BabyCountdown(DateTime.utc(2027, 5, 1), DateTime.utc(2027, 4, 30)).label, 'Bébé arrive demain !');
    expect(BabyCountdown(DateTime.utc(2027, 5, 1), DateTime.utc(2027, 5, 3)).pregnancyLabel, isEmpty);
  });

  test('séparateur de milliers', () {
    expect(formatThousands(3417), '3 417');
    expect(formatThousands(999), '999');
    expect(formatThousands(1234567), '1 234 567');
  });
}
