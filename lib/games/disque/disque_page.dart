import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'deck.dart';

enum _Phase { clue, guess, result }

const _zoneColors = [Color(0xFFF2B33D), Color(0xFFE5794B), Color(0xFFD9485B)]; // 2, 3, 4 points

/// Le Disque (inspiré de Longueur d'onde) : l'un voit la cible et donne un
/// indice, l'autre place l'aiguille entre les deux propositions.
class DisquePage extends StatefulWidget {
  const DisquePage({super.key});

  @override
  State<DisquePage> createState() => _DisquePageState();
}

class _DisquePageState extends State<DisquePage> {
  static const _names = ['Axel', 'Léna'];

  final _rnd = math.Random();
  DisqueDeck? _deck;
  late Prompt _prompt;
  int _target = 50;
  double _guess = 50;
  _Phase _phase = _Phase.clue;
  bool _showTarget = false;
  int _giver = 0;
  int _score = 0;
  int _rounds = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final deck = DisqueDeck.fromJson(await rootBundle.loadString('assets/disque/concepts.json'));
    if (!mounted) return;
    setState(() => _deck = deck);
    _newCard();
  }

  void _newCard() {
    setState(() {
      _prompt = _deck!.draw(_rnd);
      _target = 3 + _rnd.nextInt(95);
      _guess = 50;
      _showTarget = false;
      _phase = _Phase.clue;
    });
  }

  void _validate() {
    final pts = DisqueDeck.score(_target, _guess.round());
    HapticFeedback.mediumImpact();
    setState(() {
      _score += pts;
      _rounds++;
      _phase = _Phase.result;
    });
  }

  void _nextRound() {
    _giver = 1 - _giver;
    _newCard();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (_deck == null) {
      return Scaffold(appBar: AppBar(title: const Text('Le Disque')), body: const Center(child: CircularProgressIndicator()));
    }
    final guesser = 1 - _giver;
    final targetVisible = (_phase == _Phase.clue && _showTarget) || _phase == _Phase.result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Le Disque'),
        actions: [IconButton(tooltip: 'Règles', icon: const Icon(Icons.help_outline), onPressed: _rules)],
      ),
      body: SafeArea(
        child: ListView(
          // Pendant que l'aiguille bouge, la page ne défile pas.
          physics: _phase == _Phase.guess ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              'Équipe : $_score point${_score > 1 ? 's' : ''} en $_rounds manche${_rounds > 1 ? 's' : ''}',
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              switch (_phase) {
                _Phase.clue => '${_names[_giver]} regarde la cible, ${_names[guesser]} ferme les yeux',
                _Phase.guess => '${_names[guesser]} place l\'aiguille',
                _Phase.result => _resultLabel(),
              },
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            if (_prompt.theme != null) ...[
              const SizedBox(height: 4),
              Text('Thème : ${_prompt.theme}', textAlign: TextAlign.center, style: text.bodySmall),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Label(_prompt.left, Alignment.centerLeft)),
                const SizedBox(width: 12),
                Expanded(child: _Label(_prompt.right, Alignment.centerRight)),
              ],
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 2 / 1.08,
              child: LayoutBuilder(builder: (context, c) {
                final size = Size(c.maxWidth, c.maxHeight);
                void setFrom(Offset p) {
                  if (_phase != _Phase.guess) return;
                  final center = Offset(size.width / 2, size.width / 2);
                  double a = math.atan2(center.dy - p.dy, p.dx - center.dx);
                  // Doigt sous le centre : on reste au bord le plus proche.
                  if (a < 0) a = p.dx < center.dx ? math.pi : 0;
                  setState(() => _guess = (1 - a / math.pi) * 100);
                }

                // Événements bruts : le défilement de la page ne vole pas le geste.
                return Listener(
                  onPointerDown: (e) => setFrom(e.localPosition),
                  onPointerMove: (e) => setFrom(e.localPosition),
                  child: CustomPaint(
                    size: size,
                    painter: _DiscPainter(
                      target: _target,
                      showTarget: targetVisible,
                      guess: _phase == _Phase.clue ? null : _guess,
                      scheme: scheme,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            ..._actions(context),
          ],
        ),
      ),
    );
  }

  String _resultLabel() {
    final pts = DisqueDeck.score(_target, _guess.round());
    return pts == 4 ? 'En plein dans le mille ! +4' : (pts == 0 ? 'Raté… 0 point' : '+$pts points');
  }

  List<Widget> _actions(BuildContext context) {
    switch (_phase) {
      case _Phase.clue:
        return [
          if (!_showTarget)
            FilledButton.icon(
              onPressed: () => setState(() => _showTarget = true),
              icon: const Icon(Icons.visibility_outlined),
              label: Text('${_names[_giver]} : voir la cible'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            )
          else ...[
            Text(
              'Donne un exemple qui se situe à peu près là entre les deux propositions.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(() {
                _showTarget = false;
                _phase = _Phase.guess;
              }),
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('Cacher la cible et deviner'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _newCard,
            icon: const Icon(Icons.shuffle),
            label: const Text('Autres propositions'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        ];
      case _Phase.guess:
        return [
          FilledButton.icon(
            onPressed: _validate,
            icon: const Icon(Icons.check),
            label: const Text('Valider'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ];
      case _Phase.result:
        return [
          FilledButton.icon(
            onPressed: _nextRound,
            icon: const Icon(Icons.swap_horiz),
            label: Text('Manche suivante : ${_names[1 - _giver]} donne l\'indice'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ];
    }
  }

  void _rules() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Règles'),
        content: const Text(
          'Deux propositions s\'opposent sur le disque. L\'un regarde où se trouve la cible '
          '(l\'autre ferme les yeux), puis donne un exemple qui se situe à peu près à cet '
          'endroit : par exemple « une pizza » entre Sandwich et Tarte.\n\n'
          'L\'autre place l\'aiguille. En plein centre : 4 points, puis 3 et 2 en s\'éloignant.',
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.alignment);
  final String text;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
      alignment: alignment,
      child: Text(
        text,
        textAlign: alignment == Alignment.centerLeft ? TextAlign.left : TextAlign.right,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer),
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  _DiscPainter({required this.target, required this.showTarget, required this.guess, required this.scheme});
  final int target;
  final bool showTarget;
  final double? guess;
  final ColorScheme scheme;

  /// 0 → gauche (angle π), 100 → droite (angle 0).
  double _angle(double v) => math.pi * (1 - v / 100);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 4;
    final c = Offset(size.width / 2, size.width / 2);
    final disc = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(disc, math.pi, math.pi, true, Paint()..color = scheme.surfaceContainerHighest);

    if (showTarget) {
      // Zones 2, 3 puis 4 points, de la plus large à la plus étroite.
      final zones = [DisqueDeck.zone2, DisqueDeck.zone3, DisqueDeck.zone4];
      for (int k = 0; k < 3; k++) {
        final lo = (target - zones[k]).clamp(0, 100).toDouble();
        final hi = (target + zones[k]).clamp(0, 100).toDouble();
        // Angles canvas : sens horaire depuis l'axe x, donc négatifs vers le haut.
        final start = -_angle(lo);
        final sweep = _angle(lo) - _angle(hi);
        canvas.drawArc(disc, start, sweep, true, Paint()..color = _zoneColors[k]);
      }
      final tp = TextPainter(
        text: TextSpan(text: '$target', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      final a = _angle(target.toDouble());
      tp.paint(canvas, c + Offset(math.cos(a), -math.sin(a)) * (r * 0.85) - Offset(tp.width / 2, tp.height / 2));
    }

    // Graduations.
    final tick = Paint()
      ..color = scheme.outline
      ..strokeWidth = 1.5;
    for (int v = 0; v <= 100; v += 10) {
      final a = _angle(v.toDouble());
      final dir = Offset(math.cos(a), -math.sin(a));
      canvas.drawLine(c + dir * (r * 0.93), c + dir * r, tick);
    }
    canvas.drawArc(
      disc,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = scheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final g = guess;
    if (g != null) {
      final a = _angle(g);
      final tip = c + Offset(math.cos(a), -math.sin(a)) * (r * 0.95);
      canvas.drawLine(
        c,
        tip,
        Paint()
          ..color = scheme.primary
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(c, r * 0.08, Paint()..color = scheme.primary);
  }

  @override
  bool shouldRepaint(covariant _DiscPainter old) => true;
}
