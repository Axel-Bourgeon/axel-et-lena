import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/settings.dart';
import 'cloud.dart';
import 'markdown_lite.dart';

/// Notes partagées : quelques notes que l'on écrit et modifie à deux, avec
/// une mise en forme simple (gras, italique, listes, cases à cocher).
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

  void _actions(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final title = (d['title'] as String? ?? '').trim();
    final body = d['body'] as String? ?? '';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copier la note'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: title.isEmpty ? body : '$title\n\n$body'));
              Navigator.pop(sheet);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note copiée')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Supprimer'),
            onTap: () async {
              Navigator.pop(sheet);
              if (await _confirmDelete(context)) doc.reference.delete();
            },
          ),
        ]),
      ),
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
            separatorBuilder: (context, i) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final title = (d['title'] as String? ?? '').trim();
              final body = (d['body'] as String? ?? '').trim();
              final at = (d['updatedAt'] as Timestamp?)?.toDate();
              final by = Person.values.where((p) => p.name == d['by']).firstOrNull;
              final firstLine = body.isEmpty ? '' : parseLine(body.split('\n').first).text;
              return ListTile(
                title: Text(title.isEmpty ? 'Sans titre' : title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    if (firstLine.isNotEmpty) firstLine.replaceAll('*', '').replaceAll('_', ''),
                    if (at != null) '${by?.label ?? ''} ${agoLabel(at)}'.trim(),
                  ].join('\n'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _open(context, id: docs[i].id),
                onLongPress: () => _actions(context, docs[i]),
              );
            },
          );
        },
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
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
  return ok == true;
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
  final _bodyFocus = FocusNode();
  Timer? _debounce;
  bool _loaded = false;
  bool _dirty = false;
  bool _exists = false;
  late bool _editing = widget.isNew;
  String _previousBody = '';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      _loaded = true;
    } else {
      _sub = widget.ref.snapshots().listen(_onRemote);
    }
  }

  /// Modifications venant de Firestore. On ne touche jamais aux champs pendant
  /// la saisie (sinon le curseur saute à la fin du texte), ni à l'écho de nos
  /// propres écritures.
  void _onRemote(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data();
    if (d == null) return;
    _exists = true;
    if (_loaded && (_editing || _dirty || s.metadata.hasPendingWrites)) return;
    setState(() {
      _title.text = d['title'] as String? ?? '';
      _body.text = d['body'] as String? ?? '';
      _previousBody = _body.text;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    _save();
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _changed() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _save);
  }

  /// Entrée au bout d'un élément de liste : on continue la liste (ou on la
  /// termine si l'élément était vide).
  void _onBodyChanged(String v) {
    final sel = _body.selection;
    final grew = v.length == _previousBody.length + 1;
    if (grew && sel.isCollapsed && sel.baseOffset > 0 && v[sel.baseOffset - 1] == '\n') {
      final before = v.substring(0, sel.baseOffset - 1);
      final lineStart = before.lastIndexOf('\n') + 1;
      final line = before.substring(lineStart);
      final prefix = continuationPrefix(line);
      if (prefix != null) {
        if (line.trim() == prefix.trim()) {
          // Élément vide : on sort de la liste.
          final t = v.substring(0, lineStart) + v.substring(sel.baseOffset);
          _body.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: lineStart));
        } else {
          final t = v.substring(0, sel.baseOffset) + prefix + v.substring(sel.baseOffset);
          _body.value = TextEditingValue(
            text: t,
            selection: TextSelection.collapsed(offset: sel.baseOffset + prefix.length),
          );
        }
      }
    }
    _previousBody = _body.text;
    _changed();
  }

  void _save() {
    if (!_dirty) return;
    _dirty = false;
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty && !_exists) return;
    _exists = true;
    widget.ref.set({
      'title': _title.text,
      'body': _body.text,
      'updatedAt': Timestamp.now(),
      'by': widget.me.name,
    });
  }

  void _saveNow() {
    _debounce?.cancel();
    _dirty = true;
    _save();
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Note enregistrée'), duration: Duration(seconds: 1)));
  }

  /// Entoure la sélection (ou insère au curseur) avec [mark].
  void _wrap(String mark) {
    final v = _body.value;
    final s = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final selected = v.text.substring(s.start, s.end);
    final t = v.text.replaceRange(s.start, s.end, '$mark$selected$mark');
    _body.value = TextEditingValue(
      text: t,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: s.start + mark.length)
          : TextSelection(baseOffset: s.start, extentOffset: s.end + 2 * mark.length),
    );
    _previousBody = _body.text;
    _changed();
    _bodyFocus.requestFocus();
  }

  /// Ajoute [prefix] au début de la ligne du curseur.
  void _prefixLine(String prefix) {
    final v = _body.value;
    final pos = v.selection.isValid ? v.selection.start : v.text.length;
    final lineStart = v.text.lastIndexOf('\n', pos == 0 ? 0 : pos - 1) + 1;
    final t = v.text.replaceRange(lineStart, lineStart, prefix);
    _body.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: pos + prefix.length));
    _previousBody = _body.text;
    _changed();
    _bodyFocus.requestFocus();
  }

  void _toggle(int line) {
    _body.text = toggleCheckbox(_body.text, line);
    _previousBody = _body.text;
    _dirty = true;
    _save();
    setState(() {});
  }

  Future<void> _delete() async {
    if (!await _confirmDelete(context) || !mounted) return;
    _dirty = false;
    _debounce?.cancel();
    widget.ref.delete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_editing)
            IconButton(tooltip: 'Enregistrer', icon: const Icon(Icons.check), onPressed: _saveNow)
          else
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
          IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy),
            onPressed: () {
              final t = _title.text.trim();
              Clipboard.setData(ClipboardData(text: t.isEmpty ? _body.text : '$t\n\n${_body.text}'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note copiée')));
            },
          ),
          if (_exists || !widget.isNew)
            IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: _editing ? _editor(text) : _viewer(text),
            ),
    );
  }

  Widget _viewer(TextTheme text) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () => setState(() => _editing = true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(_title.text.trim().isEmpty ? 'Sans titre' : _title.text, style: text.headlineSmall),
          const SizedBox(height: 12),
          MarkdownView(body: _body.text, onToggle: _toggle),
          const SizedBox(height: 24),
          Text('Touche ✎ (ou double-touche) pour modifier', style: text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _editor(TextTheme text) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: _title,
          onChanged: (_) => _changed(),
          textCapitalization: TextCapitalization.sentences,
          style: text.headlineSmall,
          decoration: const InputDecoration(hintText: 'Titre', border: InputBorder.none),
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _body,
            focusNode: _bodyFocus,
            onChanged: _onBodyChanged,
            autofocus: widget.isNew,
            maxLines: null,
            expands: true,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Écris ici…\n\n**gras**  *italique*\n* liste\n- [ ] à faire',
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      Material(
        elevation: 2,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(tooltip: 'Gras', icon: const Icon(Icons.format_bold), onPressed: () => _wrap('**')),
          IconButton(tooltip: 'Italique', icon: const Icon(Icons.format_italic), onPressed: () => _wrap('*')),
          IconButton(tooltip: 'Liste', icon: const Icon(Icons.format_list_bulleted), onPressed: () => _prefixLine('* ')),
          IconButton(tooltip: 'Case à cocher', icon: const Icon(Icons.check_box_outlined), onPressed: () => _prefixLine('- [ ] ')),
          IconButton(tooltip: 'Titre', icon: const Icon(Icons.title), onPressed: () => _prefixLine('## ')),
        ]),
      ),
    ]);
  }
}
