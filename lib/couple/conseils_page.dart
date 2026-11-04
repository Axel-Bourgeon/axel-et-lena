import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'conseils.dart';

/// Conseils bébé : repères issus de sources officielles, consultables hors ligne.
class ConseilsPage extends StatefulWidget {
  const ConseilsPage({super.key});

  @override
  State<ConseilsPage> createState() => _ConseilsPageState();
}

class _ConseilsPageState extends State<ConseilsPage> {
  AdviceBook? _book;
  String? _theme;
  int? _range; // index dans kAgeRanges
  String _query = '';

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/conseils/conseils.json').then((s) {
      if (mounted) setState(() => _book = AdviceBook.fromJson(s));
    });
  }

  List<Advice> get _filtered {
    final book = _book!;
    return [
      for (final a in book.advice)
        if ((_theme == null || a.theme == _theme) &&
            (_range == null || a.coversRange(kAgeRanges[_range!].$2, kAgeRanges[_range!].$3)) &&
            a.matches(_query))
          a,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conseils bébé'),
        actions: [
          IconButton(
            tooltip: 'Numéros d\'urgence',
            icon: Icon(Icons.call, color: scheme.error),
            onPressed: book == null ? null : () => _numbers(context, book),
          ),
        ],
      ),
      body: book == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Card(
                  color: scheme.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.emergency, color: scheme.onErrorContainer),
                    title: Text('Urgence : 15 ou 112', style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w700)),
                    subtitle: Text('Toucher pour voir tous les numéros', style: TextStyle(color: scheme.onErrorContainer)),
                    onTap: () => _numbers(context, book),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Chercher (fièvre, biberon, bain…)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (int i = 0; i < kAgeRanges.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(kAgeRanges[i].$1),
                          selected: _range == i,
                          onSelected: (s) => setState(() => _range = s ? i : null),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final t in book.themes)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(t.label),
                          selected: _theme == t.id,
                          onSelected: (s) => setState(() => _theme = s ? t.id : null),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                for (final a in _filtered)
                  Card(
                    child: ListTile(
                      leading: a.urgent ? Icon(Icons.warning_amber_rounded, color: scheme.error) : null,
                      title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${book.themes.firstWhere((t) => t.id == a.theme).label} · ${a.ageLabel}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => _AdvicePage(advice: a)),
                      ),
                    ),
                  ),
                if (_filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Aucun conseil ne correspond.', textAlign: TextAlign.center, style: text.bodyMedium),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Repères issus de sources officielles (Assurance maladie, Santé publique France, Croix-Rouge…), '
                  'cités dans chaque fiche. Ils ne remplacent pas l\'avis d\'un médecin, d\'une sage-femme ou de la PMI.',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  void _numbers(BuildContext context, AdviceBook book) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final n in book.numbers)
            ListTile(
              leading: const Icon(Icons.call),
              title: Text('${n.label} · ${n.display}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(n.detail),
              onTap: () => launchUrl(Uri(scheme: 'tel', path: n.number)),
            ),
        ]),
      ),
    );
  }
}

class _AdvicePage extends StatelessWidget {
  const _AdvicePage({required this.advice});
  final Advice advice;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(advice.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (advice.urgent)
            Card(
              color: scheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.call, color: scheme.onErrorContainer),
                title: Text('Appeler le 15', style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w700)),
                onTap: () => launchUrl(Uri(scheme: 'tel', path: '15')),
              ),
            ),
          Text(advice.ageLabel, style: text.labelLarge?.copyWith(color: scheme.primary)),
          const SizedBox(height: 8),
          SelectableText(advice.body, style: text.bodyLarge?.copyWith(height: 1.45)),
          const SizedBox(height: 24),
          Text('Sources', style: text.titleSmall),
          for (final s in advice.sources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.open_in_new, size: 18),
              title: Text(s.name),
              onTap: () => launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
            ),
          const SizedBox(height: 12),
          Text(
            'En cas de doute, appelez votre médecin, la PMI ou le 15.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
