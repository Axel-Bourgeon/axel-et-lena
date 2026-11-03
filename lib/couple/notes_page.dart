import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/settings.dart';
import 'cloud.dart';

/// Notes partagées : quelques notes que l'on écrit et modifie à deux.
class NotesPage extends StatelessWidget {
  const NotesPage({super.key, required this.cloud, required this.me});

  final CoupleCloud cloud;
  final Person me;

  Future<void> _open(BuildContext context, {String? id}) async {
    final ref = id == null ? cloud.notes.doc() : cloud.notes.doc(id);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => _NoteEditor(ref: ref, me: me, isNew: id == null)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouvelle note',
        onPressed: () => _open(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cloud.notes.orderBy('updatedAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('Aucune note. Touche + pour en créer une.', style: text.bodyMedium));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final title = (d['title'] as String? ?? '').trim();
              final body = (d['body'] as String? ?? '').trim();
              final at = (d['updatedAt'] as Timestamp?)?.toDate();
              final by = Person.values.where((p) => p.name == d['by']).firstOrNull;
              return ListTile(
                title: Text(title.isEmpty ? 'Sans titre' : title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    if (body.isNotEmpty) body.split('\n').first,
                    if (at != null) '${by?.label ?? ''} ${agoLabel(at)}'.trim(),
                  ].join('\n'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _open(context, id: docs[i].id),
              );
            },
          );
        },
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.ref, required this.me, required this.isNew});
  final DocumentReference<Map<String, dynamic>> ref;
  final Person me;
  final bool isNew;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  Timer? _debounce;
  bool _loaded = false;
  bool _dirty = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      _loaded = true;
    } else {
      // Suit les modifications de l'autre tant qu'on n'écrit pas soi-même.
      _sub = widget.ref.snapshots().listen((s) {
        final d = s.data();
        if (d == null || _dirty) return;
        setState(() {
          _title.text = d['title'] as String? ?? '';
          _body.text = d['body'] as String? ?? '';
          _loaded = true;
        });
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    _save();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _save);
  }

  void _save() {
    if (!_dirty) return;
    _dirty = false;
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty && widget.isNew) return;
    widget.ref.set({
      'title': _title.text,
      'body': _body.text,
      'updatedAt': Timestamp.now(),
      'by': widget.me.name,
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette note ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _dirty = false;
    _debounce?.cancel();
    widget.ref.delete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!widget.isNew) IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(children: [
                TextField(
                  controller: _title,
                  onChanged: (_) => _changed(),
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: const InputDecoration(hintText: 'Titre', border: InputBorder.none),
                ),
                Expanded(
                  child: TextField(
                    controller: _body,
                    onChanged: (_) => _changed(),
                    autofocus: widget.isNew,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Écris ici…', border: InputBorder.none),
                  ),
                ),
              ]),
            ),
    );
  }
}
