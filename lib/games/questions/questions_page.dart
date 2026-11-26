import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings.dart';

class QuestionCategory {
  const QuestionCategory(this.id, this.name, this.questions);
  final String id;
  final String name;
  final List<String> questions;
}

/// Une question repérée par sa catégorie et sa place : « rire:12 ».
class QuestionRef {
  const QuestionRef(this.category, this.index);
  final QuestionCategory category;
  final int index;
  String get id => '${category.id}:$index';
  String get text => category.questions[index];
}

List<QuestionCategory> parseQuestions(String json) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  return [
    for (final c in data['categories'] as List<dynamic>)
      QuestionCategory(
        c['id'] as String,
        c['name'] as String,
        [for (final q in c['questions'] as List<dynamic>) q as String],
      ),
  ];
}

/// Tire une question pas encore posée parmi [pool] ; quand tout a été posé,
/// on repart de zéro (seen est alors vidé pour ces questions).
QuestionRef? drawQuestion(List<QuestionRef> pool, Set<String> seen, math.Random rnd) {
  if (pool.isEmpty) return null;
  var fresh = pool.where((q) => !seen.contains(q.id)).toList();
  if (fresh.isEmpty) {
    seen.removeAll(pool.map((q) => q.id));
    fresh = pool;
  }
  return fresh[rnd.nextInt(fresh.length)];
}

class QuestionsPage extends StatefulWidget {
  const QuestionsPage({super.key});

  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage> {
  static const _kSeen = 'questions.seen';
  static const _kFavs = 'questions.favs';
  static const _kCats = 'questions.categories';

  final _rnd = math.Random();
  List<QuestionCategory>? _cats;
  SharedPreferences? _prefs;
  Set<String> _seen = {};
  Set<String> _favs = {};
  Set<String> _enabled = {};
  QuestionRef? _current;
  Person _asker = Person.axel;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = parseQuestions(await rootBundle.loadString('assets/questions/questions.json'));
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _cats = cats;
      _prefs = p;
      _seen = (p.getStringList(_kSeen) ?? const []).toSet();
      _favs = (p.getStringList(_kFavs) ?? const []).toSet();
      final saved = p.getStringList(_kCats);
      _enabled = saved == null || saved.isEmpty ? cats.map((c) => c.id).toSet() : saved.toSet();
      _asker = Person.values[_rnd.nextInt(2)];
    });
    _next(first: true);
  }

  List<QuestionRef> get _pool => [
        for (final c in _cats!)
          if (_enabled.contains(c.id))
            for (int i = 0; i < c.questions.length; i++) QuestionRef(c, i),
      ];

  void _next({bool first = false}) {
    final q = drawQuestion(_pool, _seen, _rnd);
    setState(() {
      _current = q;
      if (!first) {
        _asker = _asker.other;
        _count++;
      }
    });
    if (q != null) {
      _seen.add(q.id);
      _prefs!.setStringList(_kSeen, _seen.toList());
    }
  }

  void _toggleFav() {
    final q = _current;
    if (q == null) return;
    setState(() => _favs.contains(q.id) ? _favs.remove(q.id) : _favs.add(q.id));
    _prefs!.setStringList(_kFavs, _favs.toList());
  }

  void _toggleCat(String id) {
    if (_enabled.contains(id) && _enabled.length == 1) return;
    setState(() => _enabled.contains(id) ? _enabled.remove(id) : _enabled.add(id));
    _prefs!.setStringList(_kCats, _enabled.toList());
    final q = _current;
    if (q != null && !_enabled.contains(q.category.id)) _next(first: true);
  }

  QuestionRef? _byId(String id) {
    final parts = id.split(':');
    if (parts.length != 2) return null;
    final c = _cats!.where((c) => c.id == parts[0]).firstOrNull;
    final i = int.tryParse(parts[1]);
    if (c == null || i == null || i >= c.questions.length) return null;
    return QuestionRef(c, i);
  }

  void _showFavs() {
    final favs = _favs.map(_byId).whereType<QuestionRef>().toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scroll) => favs.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Touche ☆ sur une question pour la garder ici.')))
            : ListView(controller: scroll, children: [
                for (final q in favs)
                  ListTile(
                    title: Text(q.text),
                    subtitle: Text(q.category.name),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _current = q);
                    },
                  ),
              ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cats = _cats;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final q = _current;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questions de couple'),
        actions: [IconButton(tooltip: 'Favorites', icon: const Icon(Icons.star_outline), onPressed: cats == null ? null : _showFavs)],
      ),
      body: cats == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      for (final c in cats)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(c.name),
                            selected: _enabled.contains(c.id),
                            onSelected: (_) => _toggleCat(c.id),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0).abs() > 200) _next();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(a), child: child),
                        ),
                        child: q == null
                            ? const SizedBox.shrink()
                            : Card(
                                key: ValueKey('${q.id}-$_count'),
                                color: _asker == Person.axel ? scheme.primaryContainer : scheme.tertiaryContainer,
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                    Row(children: [
                                      Expanded(
                                        child: Text(
                                          '${_asker.label} demande à ${_asker.other.label}',
                                          style: text.titleSmall,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Garder',
                                        onPressed: _toggleFav,
                                        icon: Icon(_favs.contains(q.id) ? Icons.star : Icons.star_outline),
                                      ),
                                    ]),
                                    Expanded(
                                      child: Center(
                                        child: SingleChildScrollView(
                                          child: Text(
                                            q.text,
                                            textAlign: TextAlign.center,
                                            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(q.category.name, textAlign: TextAlign.center, style: text.labelMedium),
                                  ]),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _next(first: true),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        child: const Text('Autre question'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => _next(),
                        icon: const Icon(Icons.swap_horiz),
                        label: Text('À ${_asker.other.label} de demander'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
    );
  }
}
