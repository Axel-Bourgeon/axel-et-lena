import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine.dart';

const _green = Color(0xFF4E9A5B);
const _yellow = Color(0xFFD4A72C);

class MotDuJourPage extends StatefulWidget {
  const MotDuJourPage({super.key});

  @override
  State<MotDuJourPage> createState() => _MotDuJourPageState();
}

class _MotDuJourPageState extends State<MotDuJourPage> {
  WordOfTheDay? _engine;
  SharedPreferences? _prefs;
  late int _day;
  late String _answer;
  final List<String> _guesses = [];
  String _typing = '';
  bool _shake = false;

  String get _key => 'motdujour.$_day';
  bool get _won => _guesses.isNotEmpty && _guesses.last == _answer;
  bool get _over => _won || _guesses.length >= WordOfTheDay.maxTries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // rootBundle : pas de context utilisable avant le premier build.
    final bundle = rootBundle;
    List<String> lines(String s) => s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final answers = lines(await bundle.loadString('assets/words/answers.txt'));
    final valid = lines(await bundle.loadString('assets/words/valid.txt')).toSet();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _engine = WordOfTheDay(answers: answers, valid: valid);
      _prefs = prefs;
      _day = WordOfTheDay.dayIndex(DateTime.now());
      _answer = _engine!.wordFor(_day);
      _guesses
        ..clear()
        ..addAll(prefs.getStringList(_key) ?? const []);
    });
  }

  void _type(String letter) {
    if (_over || _typing.length >= WordOfTheDay.length) return;
    setState(() => _typing += letter);
  }

  void _back() {
    if (_over || _typing.isEmpty) return;
    setState(() => _typing = _typing.substring(0, _typing.length - 1));
  }

  Future<void> _enter() async {
    if (_over) return;
    if (_typing.length < WordOfTheDay.length) {
      _refuse('Il faut 5 lettres');
      return;
    }
    if (!_engine!.isValid(_typing)) {
      _refuse('Mot inconnu');
      return;
    }
    setState(() {
      _guesses.add(_typing);
      _typing = '';
    });
    await _prefs!.setStringList(_key, _guesses);
    if (_over) await _recordStats();
  }

  void _refuse(String message) {
    HapticFeedback.mediumImpact();
    setState(() => _shake = true);
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _shake = false);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 1200)));
  }

  Future<void> _recordStats() async {
    final p = _prefs!;
    if (p.getInt('motdujour.lastPlayed') == _day) return;
    await p.setInt('motdujour.lastPlayed', _day);
    await p.setInt('motdujour.played', (p.getInt('motdujour.played') ?? 0) + 1);
    if (_won) {
      await p.setInt('motdujour.wins', (p.getInt('motdujour.wins') ?? 0) + 1);
      final streak = p.getInt('motdujour.lastWin') == _day - 1 ? (p.getInt('motdujour.streak') ?? 0) + 1 : 1;
      await p.setInt('motdujour.streak', streak);
      await p.setInt('motdujour.lastWin', _day);
      if (streak > (p.getInt('motdujour.best') ?? 0)) await p.setInt('motdujour.best', streak);
      final dist = List<String>.of(p.getStringList('motdujour.dist') ?? List.filled(WordOfTheDay.maxTries, '0'));
      dist[_guesses.length - 1] = '${int.parse(dist[_guesses.length - 1]) + 1}';
      await p.setStringList('motdujour.dist', dist);
    } else {
      await p.setInt('motdujour.streak', 0);
    }
    if (mounted) setState(() {});
  }

  Map<String, LetterState> get _keyStates {
    final out = <String, LetterState>{};
    for (final g in _guesses) {
      final s = WordOfTheDay.score(g, _answer);
      for (int i = 0; i < g.length; i++) {
        final prev = out[g[i]];
        if (prev == null || s[i].index > prev.index) out[g[i]] = s[i];
      }
    }
    return out;
  }

  Color _stateColor(LetterState s, ColorScheme scheme) => switch (s) {
        LetterState.correct => _green,
        LetterState.present => _yellow,
        LetterState.absent => scheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_engine == null) {
      return Scaffold(appBar: AppBar(title: const Text('Mot du jour')), body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Mot du jour n° ${_day + 1}'),
        actions: [
          IconButton(tooltip: 'Statistiques', icon: const Icon(Icons.bar_chart), onPressed: _showStats),
          IconButton(tooltip: 'Règles', icon: const Icon(Icons.help_outline), onPressed: _showRules),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AspectRatio(
                    aspectRatio: WordOfTheDay.length / WordOfTheDay.maxTries,
                    child: Column(
                      children: [
                        for (int r = 0; r < WordOfTheDay.maxTries; r++) Expanded(child: _row(r, scheme)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_over) _endPanel(context),
            if (!_over) _keyboard(scheme),
          ],
        ),
      ),
    );
  }

  Widget _row(int r, ColorScheme scheme) {
    final done = r < _guesses.length;
    final word = done ? _guesses[r] : (r == _guesses.length ? _typing : '');
    final states = done ? WordOfTheDay.score(word, _answer) : null;
    final shaking = _shake && r == _guesses.length;
    return AnimatedSlide(
      offset: shaking ? const Offset(0.03, 0) : Offset.zero,
      duration: const Duration(milliseconds: 60),
      child: Row(
        children: [
          for (int i = 0; i < WordOfTheDay.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 250 + i * 90),
                  decoration: BoxDecoration(
                    color: states == null ? null : _stateColor(states[i], scheme),
                    borderRadius: BorderRadius.circular(8),
                    border: states == null
                        ? Border.all(color: i < word.length ? scheme.onSurfaceVariant : scheme.outlineVariant, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        i < word.length ? word[i].toUpperCase() : '',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: states == null ? scheme.onSurface : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _keyboard(ColorScheme scheme) {
    final states = _keyStates;
    Widget key(String label, VoidCallback onTap, {int flex = 2, Color? color, Widget? icon}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: Material(
            color: color ?? scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onTap,
              child: SizedBox(
                height: 52,
                child: Center(
                  child: icon ??
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: color == null ? scheme.onSurface : Colors.white,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget letter(String l) {
      final s = states[l];
      return key(l.toUpperCase(), () => _type(l), color: s == null ? null : _stateColor(s, scheme));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Column(
        children: [
          Row(children: [for (final l in 'azertyuiop'.split('')) letter(l)]),
          Row(children: [for (final l in 'qsdfghjklm'.split('')) letter(l)]),
          Row(children: [
            key('Entrée', _enter, flex: 4),
            for (final l in 'wxcvbn'.split('')) letter(l),
            key('', _back, flex: 4, icon: const Icon(Icons.backspace_outlined)),
          ]),
        ],
      ),
    );
  }

  Widget _endPanel(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Text(
            _won
                ? 'Trouvé en ${_guesses.length} essai${_guesses.length > 1 ? 's' : ''} !'
                : 'Perdu… le mot était ${_answer.toUpperCase()}',
            style: text.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('Nouveau mot demain à minuit.', style: text.bodySmall),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: shareText(_day, _guesses, _answer)));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Résultat copié : colle-le dans Discord !')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copier mon résultat'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showStats,
            icon: const Icon(Icons.bar_chart),
            label: const Text('Statistiques'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        ],
      ),
    );
  }

  void _showStats() {
    final p = _prefs!;
    final played = p.getInt('motdujour.played') ?? 0;
    final wins = p.getInt('motdujour.wins') ?? 0;
    final dist = (p.getStringList('motdujour.dist') ?? List.filled(WordOfTheDay.maxTries, '0')).map(int.parse).toList();
    final maxD = dist.fold<int>(1, (m, v) => v > m ? v : m);
    final yesterday = _day > 0 ? _engine!.wordFor(_day - 1).toUpperCase() : null;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        Widget stat(String v, String l) => Expanded(
              child: Column(children: [
                Text(v, style: Theme.of(context).textTheme.headlineSmall),
                Text(l, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ]),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  stat('$played', 'parties'),
                  stat(played == 0 ? '–' : '${(wins * 100 / played).round()} %', 'réussites'),
                  stat('${p.getInt('motdujour.streak') ?? 0}', 'série en cours'),
                  stat('${p.getInt('motdujour.best') ?? 0}', 'meilleure série'),
                ]),
                const SizedBox(height: 20),
                for (int i = 0; i < dist.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      SizedBox(width: 18, child: Text('${i + 1}')),
                      Expanded(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.08 + 0.92 * dist[i] / maxD,
                          child: Container(
                            color: _won && i == _guesses.length - 1 ? _green : scheme.outline,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            alignment: Alignment.centerRight,
                            child: Text('${dist[i]}', style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                if (yesterday != null) ...[
                  const SizedBox(height: 16),
                  Text("Mot d'hier : $yesterday", textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRules() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Règles'),
        content: const Text(
          'Trouve le mot de 5 lettres en 6 essais. Les accents ne comptent pas.\n\n'
          'Vert : bonne lettre, bonne place.\n'
          'Jaune : lettre présente ailleurs.\n'
          'Gris : lettre absente.\n\n'
          'Le mot est le même pour Axel et Léna, et change chaque jour à minuit.',
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
}
