import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/couple/contractions.dart';

/// Contractions de [seconds] s toutes les [every] min, sur [minutes] min,
/// la plus récente en premier.
List<Contraction> series(DateTime now, {required int every, required int minutes, int seconds = 60}) {
  final out = <Contraction>[];
  for (int t = minutes; t >= 0; t -= every) {
    final start = now.subtract(Duration(minutes: t, seconds: seconds + 5));
    out.add(Contraction(start: start, end: start.add(Duration(seconds: seconds))));
  }
  return out.reversed.toList();
}

void main() {
  final now = DateTime(2027, 4, 28, 3, 0);

  test('5-1-1 atteint : toutes les 5 min pendant 1 h, 1 min chacune', () {
    final s = contractionStats(series(now, every: 5, minutes: 60), now);
    expect(s.regular, isTrue);
    expect(s.avgInterval!.inMinutes, 5);
    expect(s.avgDuration!.inSeconds, 60);
  });

  test('pas encore : toutes les 8 min', () {
    expect(contractionStats(series(now, every: 8, minutes: 60), now).regular, isFalse);
  });

  test('pas encore : depuis 30 min seulement', () {
    expect(contractionStats(series(now, every: 5, minutes: 30), now).regular, isFalse);
  });

  test('pas encore : contractions trop courtes', () {
    expect(contractionStats(series(now, every: 5, minutes: 60, seconds: 25), now).regular, isFalse);
  });

  test('contraction en cours ignorée pour la durée moyenne', () {
    final list = [Contraction(start: now.subtract(const Duration(seconds: 20))), ...series(now, every: 5, minutes: 20)];
    final s = contractionStats(list, now);
    expect(s.countLastHour, list.length);
    expect(s.avgDuration!.inSeconds, 60);
  });

  test('libellés de durée', () {
    expect(durationLabel(const Duration(seconds: 55)), '55 s');
    expect(durationLabel(const Duration(minutes: 4, seconds: 30)), '4 min 30');
    expect(durationLabel(const Duration(minutes: 5)), '5 min');
  });
}
