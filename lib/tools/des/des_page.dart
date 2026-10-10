import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dice.dart';

class DesPage extends StatefulWidget {
  const DesPage({super.key});

  @override
  State<DesPage> createState() => _DesPageState();
}

/// Ce qui est affiché : un lancer de dés ou un pile ou face.
class _Outcome {
  _Outcome.roll(DiceRoll this.roll) : coinHeads = null;
  _Outcome.coin(bool this.coinHeads) : roll = null;
  final DiceRoll? roll;
  final bool? coinHeads;

  String get title => roll != null ? roll!.formula.label : 'Pile ou face';
  String get result => roll != null ? '${roll!.total}' : (coinHeads! ? 'Face' : 'Pile');
}

class _DesPageState extends State<DesPage> with SingleTickerProviderStateMixin {
  static const _quick = [4, 6, 8, 12, 20, 100];

  final _rnd = math.Random();
  final _controller = TextEditingController(text: '5D6 + 3');
  late final AnimationController _anim;
  _Outcome? _current;
  final List<_Outcome> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) HapticFeedback.mediumImpact();
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _show(_Outcome o) {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      if (_current != null) _history.insert(0, _current!);
      if (_history.length > 12) _history.removeLast();
      _current = o;
    });
    _anim.forward(from: 0);
  }

  void _rollFormula(String text) {
    try {
      _show(_Outcome.roll(DiceFormula.parse(text).roll(_rnd)));
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final o = _current;
    final rolling = _anim.isAnimating;
    return Scaffold(
      appBar: AppBar(title: const Text('Dés')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SizedBox(
            height: 230,
            child: o == null
                ? Center(child: Text('Choisis un dé', style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant)))
                : _Stage(outcome: o, t: _anim.value, rnd: _rnd, color: scheme.primary),
          ),
          if (o != null) ...[
            Center(child: Text(o.title, style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant))),
            AnimatedOpacity(
              opacity: rolling ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Column(children: [
                Text(o.result, style: text.displayMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (o.roll != null && !o.roll!.isSingleDie)
                  Text(o.roll!.detail, textAlign: TextAlign.center, style: text.bodyMedium),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: () => _show(_Outcome.coin(_rnd.nextBool())),
                child: const Text('Pile ou face'),
              ),
              for (final s in _quick)
                FilledButton.tonal(
                  onPressed: () => _rollFormula('d$s'),
                  child: Text('D$s'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Formule',
                    hintText: 'ex. 5D6 + 3, 2D20 − 1, D%',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: _rollFormula,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: () => _rollFormula(_controller.text),
                  child: const Text('Lancer'),
                ),
              ),
            ],
          ),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Précédents', style: text.titleSmall),
            for (final h in _history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(h.title),
                subtitle: h.roll != null && !h.roll!.isSingleDie ? Text(h.roll!.detail) : null,
                trailing: Text(h.result, style: text.titleMedium),
                onTap: h.roll != null ? () => _rollFormula(h.roll!.formula.label.replaceAll('−', '-')) : null,
              ),
          ],
        ],
      ),
    );
  }
}

/// Zone animée : les dés roulent puis s'arrêtent sur leur valeur.
class _Stage extends StatelessWidget {
  const _Stage({required this.outcome, required this.t, required this.rnd, required this.color});
  final _Outcome outcome;
  final double t;
  final math.Random rnd;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final done = t >= 1;
    if (outcome.coinHeads != null) {
      // Pièce qui tourne sur elle-même (4 tours qui ralentissent) et finit
      // sur la bonne face.
      final e = Curves.easeOutCubic.transform(t);
      final angle = e * math.pi * 8 + (outcome.coinHeads! ? 0 : math.pi);
      final faceShown = math.cos(angle) >= 0 ? 'F' : 'P';
      return Center(
        child: Transform.scale(
          scaleX: math.cos(angle).abs().clamp(0.05, 1.0),
          scaleY: 1,
          child: CircleAvatar(
            radius: 70,
            backgroundColor: const Color(0xFFD4A72C),
            child: Text(
              done ? (outcome.coinHeads! ? 'F' : 'P') : faceShown,
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
      );
    }
    final roll = outcome.roll!;
    final dice = <(int sides, int value)>[];
    for (int i = 0; i < roll.formula.terms.length; i++) {
      final term = roll.formula.terms[i];
      if (term.isConstant) continue;
      for (final v in roll.results[i]) {
        dice.add((term.sides, v));
      }
    }
    final shown = dice.take(12).toList();
    final size = shown.length == 1 ? 150.0 : (shown.length <= 4 ? 90.0 : 62.0);
    return Center(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          for (int k = 0; k < shown.length; k++)
            _AnimatedDie(
              sides: shown[k].$1,
              value: shown[k].$2,
              // Petit décalage entre les dés pour qu'ils ne s'arrêtent pas tous ensemble.
              t: ((t * 1.15) - k * 0.03).clamp(0.0, 1.0),
              size: size,
              color: color,
              seed: k,
            ),
          if (dice.length > shown.length)
            SizedBox(width: size, height: size, child: Center(child: Text('+${dice.length - shown.length}'))),
        ],
      ),
    );
  }
}

class _AnimatedDie extends StatelessWidget {
  const _AnimatedDie({
    required this.sides,
    required this.value,
    required this.t,
    required this.size,
    required this.color,
    required this.seed,
  });
  final int sides, value;
  final double t, size;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeOutCubic.transform(t);
    // Rotation qui ralentit, rebonds en taille, faces qui défilent.
    final angle = (1 - e) * (1 - e) * math.pi * (4 + seed % 3);
    final bounce = 1 + 0.12 * math.sin(e * math.pi * 3) * (1 - e);
    final step = (math.pow(e, 0.6) * 14).floor();
    final face = t >= 1 ? value : 1 + (math.Random(step * 7919 + seed * 31 + value).nextInt(sides));
    return Transform.rotate(
      angle: angle,
      child: Transform.scale(
        scale: bounce,
        child: CustomPaint(
          size: Size.square(size),
          painter: _DiePainter(sides, '$face', color),
        ),
      ),
    );
  }
}

/// Silhouette simplifiée du dé selon son nombre de faces.
class _DiePainter extends CustomPainter {
  _DiePainter(this.sides, this.label, this.color);
  final int sides;
  final String label;
  final Color color;

  Path _polygon(Size s, int n, double rot, double inset) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - inset;
    final p = Path();
    for (int i = 0; i < n; i++) {
      final a = rot + i * 2 * math.pi / n;
      final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.04;
    final Path shape = switch (sides) {
      4 => _polygon(size, 3, -math.pi / 2, inset),
      6 => Path()
        ..addRRect(RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(size.width * 0.12),
          Radius.circular(size.width * 0.16),
        )),
      8 => _polygon(size, 4, -math.pi / 2, inset),
      10 || 100 => _polygon(size, 5, -math.pi / 2, inset),
      12 => _polygon(size, 5, -math.pi / 2, inset),
      20 => _polygon(size, 6, -math.pi / 2, inset),
      _ => Path()..addOval((Offset.zero & size).deflate(inset)),
    };
    canvas.drawShadow(shape, Colors.black, 4, false);
    canvas.drawPath(shape, Paint()..color = color);
    if (sides == 12 || sides == 20) {
      // Facette intérieure pour évoquer le volume.
      final inner = _polygon(size, sides == 12 ? 5 : 3, sides == 12 ? -math.pi / 2 : math.pi / 2, size.width * 0.22);
      canvas.drawPath(
        inner,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size.width * (label.length >= 3 ? 0.26 : 0.34),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = sides == 4 ? size.height * 0.1 : 0.0;
    tp.paint(canvas, size.center(Offset(-tp.width / 2, -tp.height / 2 + dy)));
  }

  @override
  bool shouldRepaint(covariant _DiePainter old) => old.label != label || old.sides != sides || old.color != color;
}
