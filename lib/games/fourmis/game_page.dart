import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'engine.dart';
import 'painter.dart';
import 'puzzle.dart';

class FourmisGamePage extends StatefulWidget {
  const FourmisGamePage({super.key, required this.puzzle, this.slotCount = 5});

  final PixelPuzzle puzzle;
  final int slotCount;

  @override
  State<FourmisGamePage> createState() => _FourmisGamePageState();
}

class _FourmisGamePageState extends State<FourmisGamePage> with SingleTickerProviderStateMixin {
  late FourmisGame _game;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  int _seed = DateTime.now().millisecondsSinceEpoch & 0xFFFF;

  static const double _slotRowHeight = 78;

  @override
  void initState() {
    super.initState();
    _newGame();
    _ticker = createTicker(_tick)..start();
  }

  void _newGame() {
    _seed++;
    _game = FourmisGame(source: widget.puzzle, slotCount: widget.slotCount, seed: _seed);
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _time += dt;
    _game.update(dt);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _take(int col) {
    if (!_game.takeFromColumn(col)) {
      if (_game.columns[col].isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Tous les emplacements sont occupés'),
            duration: Duration(milliseconds: 900),
          ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.puzzle.cells.where((c) => c >= 0).length;
    final progress = total == 0 ? 1.0 : 1 - _game.remaining / total;

    return Scaffold(
      appBar: AppBar(
        title: Text('${(progress * 100).floor()} %'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(value: progress, minHeight: 3),
        ),
        actions: [
          IconButton(
            tooltip: 'Recommencer',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_newGame),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final layout = GameLayout(
                      Size(constraints.maxWidth, constraints.maxHeight),
                      _game,
                      slotRowHeight: _slotRowHeight,
                    );
                    _game.spawnPoints = layout.spawnPoints();
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: GamePainter(game: _game, layout: layout, scheme: scheme, time: _time),
                    );
                  }),
                ),
                const Divider(height: 1),
                _Market(game: _game, onTake: _take),
              ],
            ),
            if (_game.won) _overlayWon(context),
            if (!_game.won && _game.stuck) _overlayStuck(context),
          ],
        ),
      ),
    );
  }

  Widget _overlayWon(BuildContext context) {
    final t = _game.elapsed.round();
    final time = '${t ~/ 60} min ${(t % 60).toString().padLeft(2, '0')} s';
    return _Overlay(
      children: [
        Text('Bravo !', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: AspectRatio(
            aspectRatio: widget.puzzle.width / widget.puzzle.height,
            child: CustomPaint(painter: PuzzlePreviewPainter(widget.puzzle)),
          ),
        ),
        const SizedBox(height: 12),
        Text('${_game.moves} sachets ouverts · $time'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Autre image')),
            FilledButton(onPressed: () => setState(_newGame), child: const Text('Rejouer')),
          ],
        ),
      ],
    );
  }

  Widget _overlayStuck(BuildContext context) {
    return _Overlay(
      children: [
        Text('Les fourmis sont coincées', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Aucun sachet ouvert ne peut atteindre un pixel de sa couleur.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton(onPressed: () => setState(_newGame), child: const Text('Recommencer')),
            if (_game.canAddSlot)
              FilledButton.icon(
                onPressed: () => setState(_game.addSlot),
                icon: const Icon(Icons.add),
                label: const Text('Un emplacement de plus'),
              ),
          ],
        ),
      ],
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: scheme.scrim.withValues(alpha: 0.35),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    );
  }
}

/// Colonnes de sachets : on ne peut prendre que celui du dessus.
class _Market extends StatelessWidget {
  const _Market({required this.game, required this.onTake});
  final FourmisGame game;
  final void Function(int col) onTake;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 132,
      child: Row(
        children: [
          for (int c = 0; c < game.columns.length; c++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTake(c),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  // SizedBox.expand : sans enfant ni taille, un CustomPaint
                  // mesure 0×0 et les sachets ne s'affichent pas.
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: _ColumnPainter(game, game.columns[c], scheme),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColumnPainter extends CustomPainter {
  _ColumnPainter(this.game, this.bags, this.scheme);
  final FourmisGame game;
  final List<Bag> bags;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (bags.isEmpty) return;
    // Aperçu des deux sachets suivants (petits, derrière).
    final previewH = size.height * 0.22;
    for (int k = 2; k >= 1; k--) {
      if (k >= bags.length) continue;
      final w = size.width * (0.55 - 0.1 * k);
      final r = Rect.fromCenter(
        center: Offset(size.width / 2, previewH * (k == 2 ? 0.45 : 1.0)),
        width: w,
        height: previewH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()..color = Color(game.puzzle.palette[bags[k].color]).withValues(alpha: 0.75),
      );
    }
    final front = bags.first;
    final bagW = size.width * 0.72;
    final bagH = size.height * 0.72;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - bagH / 2),
      width: bagW,
      height: bagH,
    );
    paintBag(canvas, rect, Color(game.puzzle.palette[front.color]), '${front.size}');
    if (bags.length > 3) {
      final tp = TextPainter(
        text: TextSpan(
          text: '+${bags.length - 1}',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width, 0));
    }
  }

  @override
  bool shouldRepaint(covariant _ColumnPainter oldDelegate) => true;
}
