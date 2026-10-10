import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// « C'est un 10, mais… » : un nombre secret de 0 à 9. Celui qui le lit
/// complète la phrase (« c'est un 10, mais il ronfle » = 3…), l'autre devine.
class CestUn10Page extends StatefulWidget {
  const CestUn10Page({super.key});

  @override
  State<CestUn10Page> createState() => _CestUn10PageState();
}

enum _Phase { ready, secret, guessing, result }

class _CestUn10PageState extends State<CestUn10Page> {
  static const _names = ['Axel', 'Léna'];

  final _rnd = math.Random();
  _Phase _phase = _Phase.ready;
  int _reader = 0; // qui lit le nombre
  int _number = 0;
  int? _guess;
  bool _peeking = false;
  final List<int> _scores = [0, 0];

  int get _guesser => 1 - _reader;

  void _draw() {
    HapticFeedback.selectionClick();
    setState(() {
      _number = _rnd.nextInt(10);
      _guess = null;
      _phase = _Phase.secret;
    });
  }

  /// 3 points si exact, 1 point à un près. Les deux marquent : c'est un jeu
  /// d'équipe autant que de devinette.
  int _points(int guess) => guess == _number ? 3 : ((guess - _number).abs() == 1 ? 1 : 0);

  void _answer(int g) {
    final pts = _points(g);
    HapticFeedback.mediumImpact();
    setState(() {
      _guess = g;
      _scores[_reader] += pts;
      _scores[_guesser] += pts;
      _phase = _Phase.result;
    });
  }

  void _next() {
    setState(() {
      _reader = 1 - _reader;
      _phase = _Phase.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("C'est un 10, mais…"),
        actions: [
          IconButton(tooltip: 'Règles', icon: const Icon(Icons.help_outline), onPressed: _rules),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Score d\'équipe : ${_scores[0]}',
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Expanded(child: Center(child: _body(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    switch (_phase) {
      case _Phase.ready:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_names[_reader]} lit le nombre', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('${_names[_guesser]}, ne regarde pas !', style: text.bodyLarge),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _draw,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Tirer un nombre'),
              style: FilledButton.styleFrom(minimumSize: const Size(220, 56)),
            ),
          ],
        );
      case _Phase.secret:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Maintiens pour voir le nombre en cachette', style: text.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Listener(
              onPointerDown: (_) => setState(() => _peeking = true),
              onPointerUp: (_) => setState(() => _peeking = false),
              onPointerCancel: (_) => setState(() => _peeking = false),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: _peeking ? scheme.primary : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(32),
                ),
                alignment: Alignment.center,
                child: _peeking
                    ? Text('$_number', style: TextStyle(fontSize: 110, fontWeight: FontWeight.w900, color: scheme.onPrimary))
                    : Icon(Icons.visibility_outlined, size: 64, color: scheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 24),
            Text('« C\'est un 10, mais… »', style: text.titleLarge?.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => setState(() => _phase = _Phase.guessing),
              child: Text('${_names[_guesser]} devine'),
            ),
          ],
        );
      case _Phase.guessing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_names[_guesser]}, quel est le nombre ?', style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (int g = 0; g <= 9; g++)
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => _answer(g),
                      child: Text('$g', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ],
        );
      case _Phase.result:
        final pts = _points(_guess!);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('C\'était…', style: text.titleMedium),
            Text('$_number', style: TextStyle(fontSize: 110, fontWeight: FontWeight.w900, color: scheme.primary)),
            Text(
              pts == 3 ? 'Exactement ! +3' : (pts == 1 ? 'À un près : +1' : '${_names[_guesser]} a dit $_guess…'),
              style: text.titleLarge,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.swap_horiz),
              label: Text('Au tour de ${_names[_guesser]} de lire'),
              style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
            ),
          ],
        );
    }
  }

  void _rules() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Règles'),
        content: const Text(
          'L\'un tire un nombre de 0 à 9 et le regarde en cachette. Il dit à l\'autre '
          '« C\'est un 10, mais… » et complète la phrase avec un défaut plus ou moins grave '
          'selon le nombre (9 : un tout petit défaut, 0 : rédhibitoire).\n\n'
          'L\'autre devine le nombre. Exact : 3 points pour l\'équipe, à un près : 1 point.',
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
}
