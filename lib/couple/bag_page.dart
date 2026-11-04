import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/settings.dart';
import 'cloud.dart';

/// Liste de départ de la valise maternité (modifiable ensuite).
const Map<String, List<String>> kDefaultBag = {
  'Papiers': [
    'Carte Vitale et attestation',
    'Carte de mutuelle',
    'Pièces d\'identité',
    'Dossier de grossesse, échographies, résultats d\'analyses',
    'Carte de groupe sanguin',
    'Livret de famille ou reconnaissance anticipée',
  ],
  'Pour la maman': [
    'Chemises de nuit ou grands t-shirts',
    'Peignoir et chaussons',
    'Culottes jetables ou en filet',
    'Serviettes hygiéniques spéciales maternité',
    'Soutiens-gorge d\'allaitement et coussinets',
    'Trousse de toilette',
    'Serviette de bain',
    'Tenue confortable pour la sortie',
    'Brumisateur, baume à lèvres',
  ],
  'Pour bébé': [
    '6 bodies',
    '6 pyjamas',
    '2 gilets',
    'Bonnet et chaussettes',
    'Gigoteuse',
    'Langes',
    'Serviette de bain',
    'Tenue de sortie',
    'Siège auto pour le retour',
  ],
  'Pour Axel': [
    'Vêtements de rechange',
    'Chargeurs et batterie externe',
    'En-cas et boissons',
    'Monnaie ou carte pour le parking',
    'Numéros à prévenir',
  ],
};

/// Check-list partagée de la valise maternité.
class BagPage extends StatefulWidget {
  const BagPage({super.key, required this.cloud, required this.me});

  final CoupleCloud cloud;
  final Person me;

  @override
  State<BagPage> createState() => _BagPageState();
}

class _BagPageState extends State<BagPage> {
  bool _seeded = false;

  CollectionReference<Map<String, dynamic>> get _col => widget.cloud.bag;

  /// Première ouverture : écrit la liste de départ. Identifiants fixes et
  /// fusion : si les deux téléphones le font en même temps, pas de doublons.
  void _seed() {
    if (_seeded) return;
    _seeded = true;
    int order = 0;
    for (final section in kDefaultBag.entries) {
      for (final label in section.value) {
        _col.doc('d${(order).toString().padLeft(3, '0')}').set(
          {'label': label, 'section': section.key, 'order': order},
          SetOptions(merge: true),
        );
        order++;
      }
    }
  }

  Future<void> _add(String section) async {
    final ctrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter · $section'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Ajouter')),
        ],
      ),
    );
    ctrl.dispose();
    if (label == null || label.trim().isEmpty) return;
    _col.add({'label': label.trim(), 'section': section, 'order': DateTime.now().millisecondsSinceEpoch});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Valise maternité')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty && !snap.data!.metadata.isFromCache) _seed();
          final sections = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{
            for (final s in kDefaultBag.keys) s: [],
          };
          for (final d in docs) {
            sections.putIfAbsent(d.data()['section'] as String? ?? 'Autre', () => []).add(d);
          }
          for (final l in sections.values) {
            l.sort((a, b) => ((a.data()['order'] as num?) ?? 0).compareTo((b.data()['order'] as num?) ?? 0));
          }
          final total = docs.length, done = docs.where((d) => d.data()['done'] == true).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$done / $total prêts', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 6),
                ]),
              ),
              for (final s in sections.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 4, 0),
                  child: Row(children: [
                    Expanded(
                      child: Text(s.key, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.primary)),
                    ),
                    IconButton(tooltip: 'Ajouter', icon: const Icon(Icons.add), onPressed: () => _add(s.key)),
                  ]),
                ),
                for (final d in s.value)
                  CheckboxListTile(
                    dense: true,
                    value: d.data()['done'] == true,
                    title: Text(
                      d.data()['label'] as String? ?? '',
                      style: d.data()['done'] == true
                          ? TextStyle(decoration: TextDecoration.lineThrough, color: scheme.onSurfaceVariant)
                          : null,
                    ),
                    secondary: IconButton(
                      tooltip: 'Retirer',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => d.reference.delete(),
                    ),
                    onChanged: (v) => d.reference.update({'done': v == true, 'by': widget.me.name}),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
