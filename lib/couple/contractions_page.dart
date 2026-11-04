import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/settings.dart';
import 'cloud.dart';
import 'contractions.dart';

/// Minuteur de contractions partagé : l'un ou l'autre peut appuyer, les deux
/// téléphones voient la même liste.
class ContractionsPage extends StatefulWidget {
  const ContractionsPage({super.key, required this.cloud, required this.me});

  final CoupleCloud cloud;
  final Person me;

  @override
  State<ContractionsPage> createState() => _ContractionsPageState();
}

class _ContractionsPageState extends State<ContractionsPage> {
  Timer? _tick;
  bool _alertSent = false;

  CollectionReference<Map<String, dynamic>> get _col => widget.cloud.contractions;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _toggle(Contraction? ongoing) {
    HapticFeedback.heavyImpact();
    if (ongoing != null) {
      _col.doc(ongoing.id).update({'end': Timestamp.now()});
    } else {
      _col.add({'start': Timestamp.now(), 'end': null, 'by': widget.me.name});
    }
  }

  /// Prévient l'autre (appli Messages) quand les contractions deviennent régulières.
  void _maybeAlert(ContractionStats s) {
    if (!s.regular || _alertSent) return;
    _alertSent = true;
    widget.cloud.alerts.doc(widget.me.name).set({
      'text': 'Contractions régulières : toutes les ${durationLabel(s.avgInterval!)} depuis 1 h',
      'at': Timestamp.now(),
      'from': widget.me.name,
    });
  }

  Future<void> _clear(List<Contraction> list) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tout effacer ?'),
        content: const Text('La liste des contractions sera vidée sur les deux téléphones.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Effacer')),
        ],
      ),
    );
    if (ok != true) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final c in list) {
      batch.delete(_col.doc(c.id));
    }
    batch.commit();
    _alertSent = false;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _col.orderBy('start', descending: true).limit(100).snapshots(),
      builder: (context, snap) {
        final list = [for (final d in snap.data?.docs ?? const []) Contraction.fromDoc(d)];
        final now = DateTime.now();
        final ongoing = list.where((c) => c.ongoing).firstOrNull;
        final stats = contractionStats(list, now);
        _maybeAlert(stats);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Contractions'),
            actions: [
              IconButton(tooltip: 'Repères', icon: const Icon(Icons.help_outline), onPressed: _help),
              if (list.isNotEmpty)
                IconButton(tooltip: 'Tout effacer', icon: const Icon(Icons.delete_sweep_outlined), onPressed: () => _clear(list)),
            ],
          ),
          body: !snap.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Center(
                      child: SizedBox.square(
                        dimension: 210,
                        child: FilledButton(
                          onPressed: () => _toggle(ongoing),
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: ongoing != null ? scheme.error : scheme.primary,
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(ongoing != null ? 'Fin' : 'Début', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                            if (ongoing != null)
                              Text(durationLabel(now.difference(ongoing.start)), style: const TextStyle(fontSize: 22)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (stats.regular)
                      Card(
                        color: scheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Contractions régulières depuis 1 h. Suivez les consignes de votre maternité '
                            '(${widget.me.other.label} a été ${widget.me.other == Person.lena ? 'prévenue' : 'prévenu'}).',
                            style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    Row(children: [
                      _Stat('Dernière heure', '${stats.countLastHour}'),
                      _Stat('Écart moyen', stats.avgInterval == null ? '—' : durationLabel(stats.avgInterval!)),
                      _Stat('Durée moyenne', stats.avgDuration == null ? '—' : durationLabel(stats.avgDuration!)),
                    ]),
                    const SizedBox(height: 16),
                    for (int i = 0; i < list.length; i++)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Text(timeLabel(list[i].start), style: text.titleMedium),
                        title: Text(list[i].ongoing ? 'En cours…' : 'Durée ${durationLabel(list[i].duration!)}'),
                        trailing: i + 1 < list.length
                            ? Text('écart ${durationLabel(list[i].start.difference(list[i + 1].start))}')
                            : null,
                        onLongPress: () => _col.doc(list[i].id).delete(),
                      ),
                  ],
                ),
        );
      },
    );
  }

  void _help() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repères'),
        content: const SingleChildScrollView(
          child: Text(
            'Appuie sur « Début » quand la contraction commence et sur « Fin » quand elle s\'arrête. '
            'L\'écart se mesure d\'un début de contraction au suivant.\n\n'
            'Repère souvent donné pour un premier bébé : des contractions toutes les 5 minutes, '
            'durant environ 1 minute, depuis 1 heure. Les consignes de votre maternité priment : '
            'appelez-la en cas de doute.\n\n'
            'Sans attendre : perte des eaux, saignements, fièvre, bébé qui bouge moins, douleur '
            'intense et continue → appelez la maternité ou le 15.',
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(children: [
        Text(value, style: text.titleLarge),
        Text(label, textAlign: TextAlign.center, style: text.bodySmall),
      ]),
    );
  }
}
