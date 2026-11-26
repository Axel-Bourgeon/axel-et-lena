import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/settings.dart';
import '../../couple/cloud.dart';
import 'engine.dart';

/// Dictionnaire (Lexique 3.83), chargé une seule fois.
Set<String>? _dico;
Future<Set<String>> _loadDico() async {
  if (_dico != null) return _dico!;
  final s = await rootBundle.loadString('assets/words/dico.txt');
  _dico = s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toSet();
  return _dico!;
}

/// Lettre en attente sur le plateau (pas encore jouée).
class _Pending {
  _Pending(this.rackIndex, this.tile);
  final int rackIndex;
  final Tile tile;
}

class CroixPage extends StatefulWidget {
  const CroixPage({super.key, required this.cloud, required this.me});

  final CoupleCloud cloud;
  final Person me;

  @override
  State<CroixPage> createState() => _CroixPageState();
}

class _CroixPageState extends State<CroixPage> {
  DocumentReference<Map<String, dynamic>> get _ref => widget.cloud.games.doc('croix');
  DocumentReference<Map<String, dynamic>> get _historyRef => widget.cloud.games.doc('croix_history');

  final Map<int, _Pending> _pending = {};
  int? _selected; // index dans le chevalet affiché
  List<int> _order = []; // ordre d'affichage du chevalet
  String _rackSig = '';
  bool _busy = false;

  Person get me => widget.me;

  @override
  void initState() {
    super.initState();
    _loadDico();
  }

  // ---------------------------------------------------------------- actions

  Future<void> _newGame() async {
    final rnd = math.Random.secure();
    final bag = fullBag(rnd);
    final racks = <String, List<String>>{};
    for (final p in Person.values) {
      racks[p.name] = bag.sublist(0, kRackSize);
      bag.removeRange(0, kRackSize);
    }
    final starter = Person.values[rnd.nextInt(2)];
    await _ref.set({
      'status': 'playing',
      'turn': starter.name,
      'board': <String, String>{},
      'bag': bag,
      'racks': racks,
      'scores': {for (final p in Person.values) p.name: 0},
      'passes': 0,
      'moves': 0,
      'last': {'by': '', 'text': 'Nouvelle partie : ${starter.label} commence.'},
      'startedAt': Timestamp.now(),
    });
    _clearLocal();
    if (starter != me) {
      widget.cloud.ping(me.name, 'Mots en croix', '${me.label} a lancé une partie : à toi de commencer !').catchError((Object _) {});
    }
  }

  void _clearLocal() => setState(() {
        _pending.clear();
        _selected = null;
      });

  /// Exécute un coup dans une transaction (refusé si ce n'est plus notre tour).
  Future<void> _transact(String Function(Map<String, dynamic> d, Transaction tx) apply, {String? pingText}) async {
    setState(() => _busy = true);
    try {
      await _ref.firestore.runTransaction((tx) async {
        final snap = await tx.get(_ref);
        final d = snap.data();
        if (d == null || d['status'] != 'playing') throw const CoupleException('La partie est terminée');
        if (d['turn'] != me.name) throw const CoupleException("Ce n'est pas ton tour");
        final err = apply(d, tx);
        if (err.isNotEmpty) throw CoupleException(err);
      });
      _clearLocal();
      if (pingText != null) widget.cloud.ping(me.name, 'Mots en croix', pingText).catchError((Object _) {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is CoupleException ? e.message : 'Impossible de jouer (connexion ?) : réessaie.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static List<String> _list(Object? o) => [for (final x in (o as List<dynamic>? ?? const [])) x as String];
  static Map<String, int> _scores(Object? o) =>
      {for (final p in Person.values) p.name: ((o as Map<String, dynamic>?)?[p.name] as num?)?.toInt() ?? 0};

  /// Fin de partie : points restants sur les chevalets.
  Map<String, Object> _endGame(Map<String, int> scores, Map<String, List<String>> racks, Person? finisher, String reason) {
    final s = Map<String, int>.of(scores);
    for (final p in Person.values) {
      final v = rackValue(racks[p.name]!);
      s[p.name] = s[p.name]! - v;
      if (finisher != null && p != finisher) s[finisher.name] = s[finisher.name]! + v;
    }
    final a = s[Person.axel.name]!, l = s[Person.lena.name]!;
    final winner = a == l ? '' : (a > l ? Person.axel.name : Person.lena.name);
    return {'status': 'over', 'scores': s, 'winner': winner, 'endText': reason};
  }

  void _recordHistory(Transaction tx, Map<String, Object> end) {
    final s = end['scores'] as Map<String, int>;
    tx.set(
      _historyRef,
      {
        'results': FieldValue.arrayUnion([
          {...s, 'winner': end['winner'], 'at': Timestamp.now()},
        ]),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _play(Map<String, dynamic> d) async {
    final board = boardFromMap(d['board'] as Map<String, dynamic>?);
    final placed = [for (final e in _pending.entries) Placement(e.key ~/ kSize, e.key % kSize, e.value.tile)];
    final eval = evaluate(board, placed);
    if (!eval.ok) {
      _snack(eval.error!);
      return;
    }
    final dico = await _loadDico();
    final unknown = eval.words.map((w) => w.text).where((w) => !dico.contains(w)).toSet();
    if (unknown.isNotEmpty && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mot inconnu'),
          content: Text(
            '${unknown.join(', ')} ${unknown.length > 1 ? "ne sont pas" : "n'est pas"} dans le dictionnaire de l\'appli.\n\n'
            'Si vous êtes d\'accord tous les deux, tu peux jouer quand même.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Jouer quand même')),
          ],
        ),
      );
      if (go != true) return;
    }
    final mainWord = eval.words.first.text;
    await _transact((d, tx) {
      final board = boardFromMap(d['board'] as Map<String, dynamic>?);
      final check = evaluate(board, placed);
      if (!check.ok) return check.error!;
      final racks = {for (final p in Person.values) p.name: _list((d['racks'] as Map<String, dynamic>)[p.name])};
      final left = removeFromRack(racks[me.name]!, placed.map((p) => p.tile));
      if (left == null) return 'Ton chevalet a changé : réessaie';
      final bag = _list(d['bag']);
      final draw = math.min(kRackSize - left.length, bag.length);
      left.addAll(bag.sublist(0, draw));
      bag.removeRange(0, draw);
      racks[me.name] = left;
      final scores = _scores(d['scores']);
      scores[me.name] = scores[me.name]! + check.score;
      final text = '${me.label} a joué ${check.words.map((w) => w.text).join(', ')} : ${check.score} pts'
          '${placed.length == kRackSize ? ' (les 7 lettres !)' : ''}';
      final update = <String, Object>{
        for (final p in placed) 'board.${cellId(p.r, p.c)}': p.tile.code,
        'bag': bag,
        'racks': racks,
        'scores': scores,
        'passes': 0,
        'moves': ((d['moves'] as num?)?.toInt() ?? 0) + 1,
        'turn': me.other.name,
        'last': {'by': me.name, 'text': text, 'cells': [for (final p in placed) cellId(p.r, p.c)]},
      };
      if (left.isEmpty && bag.isEmpty) {
        final end = _endGame(scores, racks, me, '${me.label} a posé sa dernière lettre.');
        update.addAll(end);
        _recordHistory(tx, end);
      }
      tx.update(_ref, update);
      return '';
    }, pingText: 'À toi ! ${me.label} a joué $mainWord (${eval.score} pts).');
  }

  Future<void> _pass() async {
    final ok = await _confirm('Passer ton tour ?', 'Si vous passez chacun 3 fois de suite, la partie s\'arrête.');
    if (!ok) return;
    await _transact((d, tx) {
      final passes = ((d['passes'] as num?)?.toInt() ?? 0) + 1;
      final update = <String, Object>{
        'passes': passes,
        'turn': me.other.name,
        'last': {'by': me.name, 'text': '${me.label} a passé son tour.'},
      };
      if (passes >= 6) {
        final racks = {for (final p in Person.values) p.name: _list((d['racks'] as Map<String, dynamic>)[p.name])};
        final end = _endGame(_scores(d['scores']), racks, null, 'Trois tours passés chacun.');
        update.addAll(end);
        _recordHistory(tx, end);
      }
      tx.update(_ref, update);
      return '';
    }, pingText: 'À toi ! ${me.label} a passé son tour.');
  }

  Future<void> _swap(List<String> rack, int bagCount) async {
    if (bagCount < kRackSize) {
      _snack('Il faut au moins $kRackSize lettres dans le sac pour échanger');
      return;
    }
    final chosen = await showDialog<Set<int>>(context: context, builder: (_) => _SwapDialog(rack: rack));
    if (chosen == null || chosen.isEmpty) return;
    await _transact((d, tx) {
      final racks = {for (final p in Person.values) p.name: _list((d['racks'] as Map<String, dynamic>)[p.name])};
      final mine = racks[me.name]!;
      if (mine.join() != rack.join()) return 'Ton chevalet a changé : réessaie';
      final bag = _list(d['bag']);
      final out = [for (final i in chosen) mine[i]];
      final keep = [for (int i = 0; i < mine.length; i++) if (!chosen.contains(i)) mine[i]];
      keep.addAll(bag.sublist(0, out.length));
      bag.removeRange(0, out.length);
      bag.addAll(out);
      bag.shuffle(math.Random.secure());
      racks[me.name] = keep;
      tx.update(_ref, {
        'bag': bag,
        'racks': racks,
        'passes': ((d['passes'] as num?)?.toInt() ?? 0) + 1,
        'turn': me.other.name,
        'last': {'by': me.name, 'text': '${me.label} a échangé ${out.length} lettre${out.length > 1 ? 's' : ''}.'},
      });
      return '';
    }, pingText: 'À toi ! ${me.label} a échangé des lettres.');
  }

  Future<void> _resign(Map<String, dynamic> d) async {
    final ok = await _confirm('Abandonner la partie ?', '${me.other.label} gagnera cette partie.');
    if (!ok) return;
    try {
      await _ref.firestore.runTransaction((tx) async {
        final snap = await tx.get(_ref);
        final d = snap.data();
        if (d == null || d['status'] != 'playing') return;
        final end = <String, Object>{
          'status': 'over',
          'winner': me.other.name,
          'endText': '${me.label} a abandonné.',
        };
        tx.update(_ref, end);
        _recordHistory(tx, {...end, 'scores': _scores(d['scores'])});
      });
      _clearLocal();
    } catch (_) {
      _snack('Impossible (connexion ?) : réessaie.');
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
          ],
        ),
      ) ==
      true;

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  // ------------------------------------------------------------ pose locale

  Future<void> _tapCell(int r, int c, Map<int, Tile> board, List<String> rack) async {
    final k = cellKey(r, c);
    if (_pending.containsKey(k)) {
      setState(() => _pending.remove(k));
      return;
    }
    if (board.containsKey(k)) return;
    final sel = _selected;
    if (sel == null) {
      _snack('Choisis d\'abord une lettre de ton chevalet');
      return;
    }
    final rackIndex = _order[sel];
    var letter = rack[rackIndex];
    final joker = letter == kJoker;
    if (joker) {
      final chosen = await showDialog<String>(context: context, builder: (_) => const _JokerDialog());
      if (chosen == null) return;
      letter = chosen;
    }
    setState(() {
      _pending[k] = _Pending(rackIndex, Tile(letter, joker: joker));
      _selected = null;
    });
  }

  void _syncRack(List<String> rack) {
    final sig = rack.join();
    if (sig == _rackSig && _order.length == rack.length) return;
    _rackSig = sig;
    _order = List.generate(rack.length, (i) => i);
    _pending.clear();
    _selected = null;
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mots en croix'),
            actions: [
              IconButton(tooltip: 'Règles', icon: const Icon(Icons.help_outline), onPressed: _showRules),
              if (d != null && d['status'] == 'playing')
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'resign') _resign(d);
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'resign', child: Text('Abandonner la partie'))],
                ),
            ],
          ),
          body: !snap.hasData
              ? (snap.hasError
                  ? const Center(child: Text('Connexion impossible'))
                  : const Center(child: CircularProgressIndicator()))
              : (d == null || d['status'] != 'playing')
                  ? _lobby(context, d)
                  : _game(context, d),
        );
      },
    );
  }

  Widget _lobby(BuildContext context, Map<String, dynamic>? last) {
    final text = Theme.of(context).textTheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _historyRef.snapshots(),
      builder: (context, h) {
        final results = (h.data?.data()?['results'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
        final wins = {for (final p in Person.values) p.name: results.where((r) => r['winner'] == p.name).length};
        return ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.grid_on, size: 56),
          const SizedBox(height: 12),
          Text('Mots en croix', style: text.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'Chacun son tour, quand vous voulez : l\'autre reçoit une notification quand c\'est à lui de jouer.',
            textAlign: TextAlign.center,
          ),
          if (last != null && last['status'] == 'over') ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text('Dernière partie', style: text.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    Person.values.map((p) => '${p.label} ${_scores(last['scores'])[p.name]}').join('  –  '),
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${last['endText'] ?? ''} ${_winnerText(last['winner'] as String?)}',
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
            ),
          ],
          if (results.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Parties gagnées : ${Person.values.map((p) => '${p.label} ${wins[p.name]}').join(' · ')}',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _newGame,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Nouvelle partie'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ]);
      },
    );
  }

  String _winnerText(String? w) {
    final p = Person.values.where((p) => p.name == w).firstOrNull;
    return p == null ? 'Égalité !' : '${p.label} gagne !';
  }

  Widget _game(BuildContext context, Map<String, dynamic> d) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final board = boardFromMap(d['board'] as Map<String, dynamic>?);
    final rack = _list((d['racks'] as Map<String, dynamic>?)?[me.name]);
    final bag = _list(d['bag']);
    final scores = _scores(d['scores']);
    final myTurn = d['turn'] == me.name;
    final last = d['last'] as Map<String, dynamic>?;
    final lastCells = _list(last?['cells']).toSet();
    _syncRack(rack);

    final placed = [for (final e in _pending.entries) Placement(e.key ~/ kSize, e.key % kSize, e.value.tile)];
    final eval = placed.isEmpty ? null : evaluate(board, placed);
    final usedIdx = _pending.values.map((p) => p.rackIndex).toSet();

    Widget score(Person p) {
      final active = d['turn'] == p.name;
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: active ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? scheme.primary : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            Expanded(child: Text(p == me ? '${p.label} (toi)' : p.label, overflow: TextOverflow.ellipsis)),
            Text('${scores[p.name]}', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        ),
      );
    }

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(children: [score(Person.axel), const SizedBox(width: 8), score(Person.lena)]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${myTurn ? 'À toi de jouer' : 'Au tour de ${me.other.label}'} · ${bag.length} lettre${bag.length > 1 ? 's' : ''} dans le sac'
            '${last?['text'] != null ? '\n${last!['text']}' : ''}',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: InteractiveViewer(
                maxScale: 3,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(children: [
                    for (int r = 0; r < kSize; r++)
                      Expanded(
                        child: Row(children: [
                          for (int c = 0; c < kSize; c++)
                            Expanded(child: _cell(r, c, board, rack, lastCells, scheme)),
                        ]),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        // Chevalet
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Row(children: [
            for (int i = 0; i < _order.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: usedIdx.contains(_order[i])
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                          )
                        : GestureDetector(
                            onTap: () => setState(() => _selected = _selected == i ? null : i),
                            child: _TileView(
                              letter: rack[_order[i]],
                              joker: rack[_order[i]] == kJoker,
                              selected: _selected == i,
                            ),
                          ),
                  ),
                ),
              ),
            for (int i = _order.length; i < kRackSize; i++) const Expanded(child: SizedBox()),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
          child: Row(children: [
            IconButton(
              tooltip: _pending.isEmpty ? 'Mélanger' : 'Reprendre les lettres',
              onPressed: () => setState(() {
                if (_pending.isNotEmpty) {
                  _pending.clear();
                } else {
                  _order.shuffle();
                }
                _selected = null;
              }),
              icon: Icon(_pending.isEmpty ? Icons.shuffle : Icons.undo),
            ),
            IconButton(
              tooltip: 'Échanger des lettres',
              onPressed: myTurn && !_busy ? () => _swap(rack, bag.length) : null,
              icon: const Icon(Icons.swap_vert),
            ),
            IconButton(
              tooltip: 'Passer',
              onPressed: myTurn && !_busy ? _pass : null,
              icon: const Icon(Icons.skip_next_outlined),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: FilledButton(
                onPressed: myTurn && !_busy && eval != null && eval.ok ? () => _play(d) : null,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(
                  eval == null
                      ? (myTurn ? 'Pose des lettres' : 'Pas ton tour')
                      : (eval.ok ? 'Jouer · ${eval.score} pts' : eval.error!),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _cell(int r, int c, Map<int, Tile> board, List<String> rack, Set<String> lastCells, ColorScheme scheme) {
    final k = cellKey(r, c);
    final placed = board[k];
    final pending = _pending[k]?.tile;
    Widget child;
    if (placed != null || pending != null) {
      child = _TileView(
        letter: (placed ?? pending)!.letter,
        joker: (placed ?? pending)!.joker,
        pending: pending != null,
        recent: placed != null && lastCells.contains(cellId(r, c)),
        small: true,
      );
    } else {
      final b = bonusAt(r, c);
      final color = switch (b) {
        Bonus.tw => const Color(0xFFD9603B),
        Bonus.dw => const Color(0xFFE9A3A0),
        Bonus.tl => const Color(0xFF3F7FBF),
        Bonus.dl => const Color(0xFFA9CBE8),
        Bonus.start => const Color(0xFFE9A3A0),
        Bonus.none => scheme.surfaceContainerHighest,
      };
      child = Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        alignment: Alignment.center,
        child: b == Bonus.none
            ? null
            : FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: Text(
                    b.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: b == Bonus.tw || b == Bonus.tl ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
      );
    }
    return GestureDetector(
      onTap: () => _tapCell(r, c, board, rack),
      child: Padding(padding: const EdgeInsets.all(0.8), child: child),
    );
  }

  void _showRules() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Règles'),
        content: const SingleChildScrollView(
          child: Text(
            'Touche une lettre de ton chevalet, puis une case du plateau. Touche une lettre posée pour la reprendre.\n\n'
            '• Le premier mot passe par l\'étoile centrale.\n'
            '• Ensuite, chaque mot touche une lettre déjà posée, sur une seule ligne ou colonne.\n'
            '• Tous les mots formés comptent.\n'
            '• L×2 / L×3 : la lettre compte double / triple. M×2 / M×3 : tout le mot compte double / triple (seulement quand on y pose une lettre).\n'
            '• Poser ses 7 lettres d\'un coup : +50 points.\n'
            '• Le joker (étoile, 0 point) remplace la lettre de ton choix.\n'
            '• Échanger des lettres ou passer fait perdre son tour.\n\n'
            'La partie finit quand le sac est vide et qu\'un joueur a posé toutes ses lettres : il gagne les points restant chez l\'autre. '
            'Elle finit aussi après 3 tours passés chacun.\n\n'
            'Dictionnaire : Lexique 3.83 (lexique.org). Un mot inconnu peut être joué quand même si vous êtes d\'accord.',
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
}

class _TileView extends StatelessWidget {
  const _TileView({
    required this.letter,
    this.joker = false,
    this.selected = false,
    this.pending = false,
    this.recent = false,
    this.small = false,
  });

  final String letter;
  final bool joker, selected, pending, recent, small;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = pending
        ? const Color(0xFFFFE08A)
        : (selected ? scheme.primary : (recent ? const Color(0xFFF3D9A4) : const Color(0xFFF4E6C8)));
    final fg = selected ? scheme.onPrimary : const Color(0xFF3B2A14);
    final shown = letter == kJoker ? '★' : letter;
    final value = joker ? 0 : (kValues[letter] ?? 0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(small ? 3 : 6),
        border: Border.all(color: pending ? const Color(0xFFB8860B) : const Color(0xFFC9B48A), width: pending ? 1.5 : 1),
        boxShadow: small ? null : const [BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Stack(children: [
        Center(
          child: FittedBox(
            child: Padding(
              padding: EdgeInsets.all(small ? 2 : 6),
              child: Text(
                shown,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: joker && letter != kJoker ? const Color(0xFF8A5A00) : fg,
                ),
              ),
            ),
          ),
        ),
        if (letter != kJoker)
          Positioned(
            right: small ? 1 : 3,
            bottom: small ? 0 : 2,
            child: Text('$value', style: TextStyle(fontSize: small ? 6 : 10, color: fg, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}

class _JokerDialog extends StatelessWidget {
  const _JokerDialog();

  @override
  Widget build(BuildContext context) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return AlertDialog(
      title: const Text('Le joker devient…'),
      content: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final l in letters.split(''))
          SizedBox(
            width: 40,
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => Navigator.pop(context, l),
              child: Text(l, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

class _SwapDialog extends StatefulWidget {
  const _SwapDialog({required this.rack});
  final List<String> rack;

  @override
  State<_SwapDialog> createState() => _SwapDialogState();
}

class _SwapDialogState extends State<_SwapDialog> {
  final Set<int> _chosen = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Échanger quelles lettres ?'),
      content: Wrap(spacing: 6, runSpacing: 6, children: [
        for (int i = 0; i < widget.rack.length; i++)
          GestureDetector(
            onTap: () => setState(() => _chosen.contains(i) ? _chosen.remove(i) : _chosen.add(i)),
            child: SizedBox.square(
              dimension: 42,
              child: _TileView(letter: widget.rack[i], joker: widget.rack[i] == kJoker, selected: _chosen.contains(i)),
            ),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(
          onPressed: _chosen.isEmpty ? null : () => Navigator.pop(context, _chosen),
          child: Text('Échanger (${_chosen.length})'),
        ),
      ],
    );
  }
}
