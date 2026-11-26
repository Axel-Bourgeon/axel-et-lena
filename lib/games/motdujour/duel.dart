import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../../couple/cloud.dart';
import 'engine.dart';

/// Résultat d'une personne pour un jour donné.
class DuelResult {
  const DuelResult({required this.tries, required this.won, required this.pattern});

  final int tries;
  final bool won;

  /// Couleurs des essais, sans les lettres : « ayagg|ggggg » (g = bien placée,
  /// y = mal placée, a = absente).
  final String pattern;

  static DuelResult? fromMap(Object? m) {
    if (m is! Map) return null;
    final tries = m['tries'], won = m['won'];
    if (tries is! int || won is! bool) return null;
    return DuelResult(tries: tries, won: won, pattern: (m['pattern'] as String?) ?? '');
  }

  Map<String, Object> toMap() => {'tries': tries, 'won': won, 'pattern': pattern, 'at': Timestamp.now()};

  /// Pour le classement du jour : moins d'essais = mieux, perdu = 7.
  int get rank => won ? tries : WordOfTheDay.maxTries + 1;

  String get short => won ? '$tries/${WordOfTheDay.maxTries}' : 'X/${WordOfTheDay.maxTries}';
}

DuelResult resultOf(List<String> guesses, String answer) {
  final won = guesses.isNotEmpty && guesses.last == answer;
  final pattern = guesses
      .map((g) => WordOfTheDay.score(g, answer)
          .map((s) => switch (s) {
                LetterState.correct => 'g',
                LetterState.present => 'y',
                LetterState.absent => 'a',
              })
          .join())
      .join('|');
  return DuelResult(tries: guesses.length, won: won, pattern: pattern);
}

/// Bilan des jours où les deux ont joué, et statistiques de chacun.
class DuelStats {
  DuelStats(Map<int, Map<Person, DuelResult>> days) {
    for (final entry in days.entries) {
      final r = entry.value;
      for (final p in Person.values) {
        final x = r[p];
        if (x == null) continue;
        played[p] = played[p]! + 1;
        if (x.won) {
          wins[p] = wins[p]! + 1;
          triesOnWins[p] = triesOnWins[p]! + x.tries;
          dist[p]![x.tries - 1]++;
        }
      }
      final a = r[Person.axel], l = r[Person.lena];
      if (a == null || l == null) continue;
      both++;
      if (a.rank < l.rank) {
        duelWins[Person.axel] = duelWins[Person.axel]! + 1;
      } else if (l.rank < a.rank) {
        duelWins[Person.lena] = duelWins[Person.lena]! + 1;
      } else {
        ties++;
      }
    }
  }

  final Map<Person, int> played = {for (final p in Person.values) p: 0};
  final Map<Person, int> wins = {for (final p in Person.values) p: 0};
  final Map<Person, int> triesOnWins = {for (final p in Person.values) p: 0};
  final Map<Person, List<int>> dist = {for (final p in Person.values) p: List.filled(WordOfTheDay.maxTries, 0)};
  final Map<Person, int> duelWins = {for (final p in Person.values) p: 0};
  int both = 0;
  int ties = 0;

  /// Moyenne d'essais sur les mots trouvés (null si aucun).
  double? average(Person p) => wins[p]! == 0 ? null : triesOnWins[p]! / wins[p]!;
}

Map<int, Map<Person, DuelResult>> parseDays(Iterable<Map<String, dynamic>> docs) {
  final out = <int, Map<Person, DuelResult>>{};
  for (final d in docs) {
    final day = d['day'];
    if (day is! int) continue;
    final m = <Person, DuelResult>{};
    for (final p in Person.values) {
      final r = DuelResult.fromMap(d[p.name]);
      if (r != null) m[p] = r;
    }
    if (m.isNotEmpty) out[day] = m;
  }
  return out;
}

/// Envoi des résultats dans l'espace du couple.
class MotDuJourSync {
  MotDuJourSync(this.cloud, this.me);

  final CoupleCloud cloud;
  final Person me;

  Future<void> upload(int day, DuelResult r) =>
      cloud.motdujour.doc('$day').set({'day': day, me.name: r.toMap()}, SetOptions(merge: true));

  /// Prévient l'autre (sans dévoiler le mot).
  Future<void> announce(int day, DuelResult r) => cloud.ping(
        me.name,
        'Mot du jour n° ${day + 1}',
        r.won
            ? '${me.label} a trouvé en ${r.tries} essai${r.tries > 1 ? 's' : ''} ! À toi de jouer.'
            : "${me.label} n'a pas trouvé aujourd'hui… À toi de faire mieux !",
      );

  Stream<Map<Person, DuelResult>> watchDay(int day) => cloud.motdujour
      .doc('$day')
      .snapshots()
      .map((s) => parseDays([if (s.data() != null) s.data()!])[day] ?? {});
}

const _green = Color(0xFF4E9A5B);
const _yellow = Color(0xFFD4A72C);

/// Petite grille de couleurs (sans lettres).
class MiniGrid extends StatelessWidget {
  const MiniGrid(this.pattern, {super.key, this.cell = 9});

  final String pattern;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = pattern.isEmpty ? const <String>[] : pattern.split('|');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in rows)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in r.split(''))
                Container(
                  width: cell,
                  height: cell,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: switch (c) {
                      'g' => _green,
                      'y' => _yellow,
                      _ => scheme.outlineVariant,
                    },
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Face-à-face : qui trouve le plus vite, jour après jour.
class DuelPage extends StatelessWidget {
  const DuelPage({super.key, required this.cloud, required this.me, required this.engine, required this.today, required this.todayDone});

  final CoupleCloud cloud;
  final Person me;
  final WordOfTheDay engine;
  final int today;

  /// Le mot du jour n'est dévoilé que si on a fini sa partie.
  final bool todayDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face-à-face')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cloud.motdujour.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final days = parseDays(snap.data!.docs.map((d) => d.data()));
          if (days.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucune partie enregistrée pour l\'instant.')));
          }
          final stats = DuelStats(days);
          final order = days.keys.toList()..sort((a, b) => b.compareTo(a));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Summary(stats),
              const SizedBox(height: 20),
              Text('Jour par jour', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final day in order) _DayTile(day: day, results: days[day]!, word: (day < today || todayDone) ? engine.wordFor(day).toUpperCase() : null),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.s);
  final DuelStats s;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget col(Person p) {
      final avg = s.average(p);
      final played = s.played[p]!;
      final maxD = s.dist[p]!.fold<int>(1, (m, v) => v > m ? v : m);
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.label, style: text.titleMedium, textAlign: TextAlign.center),
            Text('${s.duelWins[p]}', style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            Text('victoire${s.duelWins[p]! > 1 ? 's' : ''}', style: text.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              '$played partie${played > 1 ? 's' : ''} · ${played == 0 ? '–' : '${(s.wins[p]! * 100 / played).round()} %'} trouvés',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            Text('Moyenne : ${avg == null ? '–' : avg.toStringAsFixed(2).replaceAll('.', ',')} essais', style: text.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            for (int i = 0; i < WordOfTheDay.maxTries; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(children: [
                  SizedBox(width: 14, child: Text('${i + 1}', style: text.bodySmall)),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.1 + 0.9 * s.dist[p]![i] / maxD,
                      child: Container(
                        color: p == Person.axel ? scheme.primary : scheme.tertiary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.centerRight,
                        child: Text('${s.dist[p]![i]}', style: TextStyle(fontSize: 11, color: p == Person.axel ? scheme.onPrimary : scheme.onTertiary)),
                      ),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [col(Person.axel), const SizedBox(width: 16), col(Person.lena)]),
          const SizedBox(height: 8),
          Text('${s.both} jour${s.both > 1 ? 's' : ''} joués tous les deux · ${s.ties} égalité${s.ties > 1 ? 's' : ''}', style: text.bodySmall),
        ]),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.results, required this.word});

  final int day;
  final Map<Person, DuelResult> results;
  final String? word;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = WordOfTheDay.epoch.add(Duration(days: day));
    final a = results[Person.axel], l = results[Person.lena];
    Person? winner;
    if (a != null && l != null && a.rank != l.rank) winner = a.rank < l.rank ? Person.axel : Person.lena;
    Widget side(Person p, DuelResult? r) => Expanded(
          child: Column(children: [
            Text(
              '${p.label} ${r?.short ?? '—'}${winner == p ? ' 🏆' : ''}',
              style: text.bodyMedium?.copyWith(fontWeight: winner == p ? FontWeight.w700 : null),
            ),
            const SizedBox(height: 4),
            if (r != null) MiniGrid(r.pattern) else Text('pas joué', style: text.bodySmall),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(children: [
          Text('N° ${day + 1} · ${dateLabel(date)}${word == null ? '' : ' · $word'}', style: text.titleSmall),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [side(Person.axel, a), side(Person.lena, l)]),
        ]),
      ),
    );
  }
}
