import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/settings.dart';
import 'cloud.dart';
import 'notifier.dart';

/// Alertes entre nous deux : pas une messagerie, juste le dernier message de
/// chacun, qui arrive en notification chez l'autre.
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, required this.cloud, required this.me});

  final CoupleCloud cloud;
  final Person me;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  static const _quick = [
    'Tu me manques ❤️',
    'J\'arrive !',
    'Appelle-moi quand tu peux',
    'Je pense à toi',
    'Bébé bouge ! 👶',
    'Tu rentres à quelle heure ?',
    'Bonne nuit 🌙',
    'Urgent, rappelle-moi',
  ];

  final _field = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    // Sans await : hors ligne, l'envoi part tout seul à la reconnexion.
    widget.cloud.alerts.doc(widget.me.name).set({
      'text': t,
      'at': Timestamp.now(),
      'from': widget.me.name,
    });
    _field.clear();
    if (mounted) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Envoyé à ${widget.me.other.label}'), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.me.other;
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _LastMessage(ref: widget.cloud.alerts.doc(other.name), title: 'De ${other.label}', incoming: true),
            const SizedBox(height: 10),
            _LastMessage(ref: widget.cloud.alerts.doc(widget.me.name), title: 'Mon dernier message', incoming: false),
            const SizedBox(height: 24),
            Text('Envoyer à ${other.label}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in _quick) ActionChip(label: Text(q), onPressed: _sending ? null : () => _send(q)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _field,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 300,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Un petit mot…'),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: IconButton.filled(
                    onPressed: _sending ? null : () => _send(_field.text),
                    icon: const Icon(Icons.send),
                  ),
                ),
              ],
            ),
            Text(
              'Appli fermée, ${other.label} reçoit la notification dans les 15 minutes environ ; '
              'appli ouverte, tout de suite.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LastMessage extends StatelessWidget {
  const _LastMessage({required this.ref, required this.title, required this.incoming});
  final DocumentReference<Map<String, dynamic>> ref;
  final String title;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final at = (data?['at'] as Timestamp?)?.toDate();
        if (incoming && at != null) CoupleNotifier.markSeen(at);
        return Card(
          color: incoming ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  if (at != null) Text(agoLabel(at), style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: 6),
                Text(
                  data?['text'] as String? ?? (snap.hasData ? 'Aucun message pour l\'instant' : '…'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
