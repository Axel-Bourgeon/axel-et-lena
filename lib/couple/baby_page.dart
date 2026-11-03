import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/settings.dart';
import 'baby_log.dart';
import 'cloud.dart';

/// Agenda bébé partagé : dernier biberon, dernière couche… avec commentaires.
class BabyPage extends StatefulWidget {
  const BabyPage({super.key, required this.cloud, required this.me});

  final CoupleCloud cloud;
  final Person me;

  @override
  State<BabyPage> createState() => _BabyPageState();
}

class _BabyPageState extends State<BabyPage> {
  static const _summaryKinds = [BabyKind.bottle, BabyKind.diaper, BabyKind.breast, BabyKind.sleep];
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Rafraîchit les « il y a … » chaque minute.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _who(String by) => Person.values.where((p) => p.name == by).firstOrNull?.label ?? '';

  Future<void> _edit({BabyEntry? entry, BabyKind? kind}) async {
    final result = await showModalBottomSheet<BabyEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EntrySheet(entry: entry, kind: kind ?? entry!.kind, me: widget.me),
    );
    if (result == null) return;
    HapticFeedback.lightImpact();
    // Sans await : hors ligne, l'écriture est gardée et envoyée plus tard.
    if (entry?.id != null) {
      widget.cloud.baby.doc(entry!.id).set(result.toMap());
    } else {
      widget.cloud.baby.add(result.toMap());
    }
  }

  Future<void> _delete(BabyEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('${e.kind.label} de ${timeLabel(e.at)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) widget.cloud.baby.doc(e.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Bébé agenda')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickKind(context),
        icon: const Icon(Icons.add),
        label: const Text('Noter'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.cloud.baby.orderBy('at', descending: true).limit(200).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final entries = [for (final d in snap.data!.docs) BabyEntry.fromDoc(d)];
          final latest = latestByKind(entries);
          final now = DateTime.now();
          final ml24 = bottleMlLast24h(entries, now);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Row(children: [
                for (final k in _summaryKinds.take(2)) Expanded(child: _summary(context, k, latest[k], now)),
              ]),
              Row(children: [
                for (final k in _summaryKinds.skip(2)) Expanded(child: _summary(context, k, latest[k], now)),
              ]),
              if (ml24 > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Lait sur 24 h : $ml24 mL', textAlign: TextAlign.center, style: text.bodyMedium),
                ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Rien de noté pour l\'instant.', textAlign: TextAlign.center, style: text.bodyMedium),
                ),
              ..._history(context, entries, scheme),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(BuildContext context, BabyKind k, BabyEntry? e, DateTime now) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _edit(kind: k),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${k.emoji} ${k.label}', style: text.labelLarge),
              const SizedBox(height: 4),
              Text(e == null ? '—' : agoLabel(e.at, now: now), style: text.titleMedium),
              if (e != null && e.details.isNotEmpty)
                Text(e.details, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
              Text('Toucher pour noter', style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _history(BuildContext context, List<BabyEntry> entries, ColorScheme scheme) {
    final out = <Widget>[];
    String? day;
    for (final e in entries) {
      final d = _dayTitle(e.at);
      if (d != day) {
        day = d;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
          child: Text(d, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ));
      }
      out.add(ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Text(e.kind.emoji, style: const TextStyle(fontSize: 24)),
        title: Text('${timeLabel(e.at)}  ${e.kind.label}'),
        subtitle: Text([if (e.details.isNotEmpty) e.details, _who(e.by)].where((s) => s.isNotEmpty).join(' — ')),
        onTap: () => _edit(entry: e),
        onLongPress: () => _delete(e),
      ));
    }
    return out;
  }

  String _dayTitle(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    return dateLabel(t);
  }

  void _pickKind(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Wrap(children: [
          for (final k in BabyKind.values)
            ListTile(
              leading: Text(k.emoji, style: const TextStyle(fontSize: 24)),
              title: Text(k.label),
              onTap: () {
                Navigator.pop(sheet);
                _edit(kind: k);
              },
            ),
        ]),
      ),
    );
  }
}

/// Saisie ou modification d'une entrée.
class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.entry, required this.kind, required this.me});
  final BabyEntry? entry;
  final BabyKind kind;
  final Person me;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late DateTime _at = widget.entry?.at ?? DateTime.now();
  late Diaper? _diaper = widget.entry?.diaper ?? (widget.kind == BabyKind.diaper ? Diaper.wet : null);
  late final _ml = TextEditingController(text: widget.entry?.ml?.toString() ?? '');
  late final _note = TextEditingController(text: widget.entry?.note ?? '');

  @override
  void dispose() {
    _ml.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (t == null) return;
    setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (d == null) return;
    setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${k.emoji} ${k.label}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(dateLabel(_at)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule),
                label: Text(timeLabel(_at)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (k == BabyKind.bottle)
            TextField(
              controller: _ml,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Quantité bue (mL)', border: OutlineInputBorder()),
            ),
          if (k == BabyKind.diaper)
            SegmentedButton<Diaper>(
              showSelectedIcon: false,
              segments: [for (final d in Diaper.values) ButtonSegment(value: d, label: Text(d.label))],
              selected: {_diaper!},
              onSelectionChanged: (s) => setState(() => _diaper = s.first),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Commentaire', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              BabyEntry(
                kind: k,
                at: _at,
                by: widget.entry?.by ?? widget.me.name,
                ml: int.tryParse(_ml.text),
                diaper: k == BabyKind.diaper ? _diaper : null,
                note: _note.text.trim(),
              ),
            ),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
