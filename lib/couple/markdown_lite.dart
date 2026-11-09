import 'package:flutter/material.dart';

/// Markdown simplifié pour les notes :
/// `**gras**`, `*italique*` ou `_italique_`, `# Titre`, `## Sous-titre`,
/// listes `* élément` / `- élément`, cases `- [ ] à faire` / `- [x] fait`.
enum MdKind { paragraph, heading1, heading2, bullet, checkbox, blank }

class MdLine {
  const MdLine(this.kind, this.text, {this.checked = false, this.indent = 0});
  final MdKind kind;

  /// Texte sans le préfixe de liste ou de titre.
  final String text;
  final bool checked;

  /// Niveau d'indentation (2 espaces = 1 niveau).
  final int indent;
}

final _check = RegExp(r'^(\s*)[-*+]\s+\[([ xX])\]\s?(.*)$');
final _bullet = RegExp(r'^(\s*)[-*+]\s+(.*)$');

MdLine parseLine(String line) {
  if (line.trim().isEmpty) return const MdLine(MdKind.blank, '');
  final c = _check.firstMatch(line);
  if (c != null) {
    return MdLine(MdKind.checkbox, c.group(3)!, checked: c.group(2) != ' ', indent: c.group(1)!.length ~/ 2);
  }
  final b = _bullet.firstMatch(line);
  if (b != null) return MdLine(MdKind.bullet, b.group(2)!, indent: b.group(1)!.length ~/ 2);
  if (line.startsWith('## ')) return MdLine(MdKind.heading2, line.substring(3));
  if (line.startsWith('# ')) return MdLine(MdKind.heading1, line.substring(2));
  return MdLine(MdKind.paragraph, line);
}

/// Inverse la case à cocher de la ligne [index] de [body].
String toggleCheckbox(String body, int index) {
  final lines = body.split('\n');
  if (index < 0 || index >= lines.length) return body;
  lines[index] = lines[index].replaceFirstMapped(
    RegExp(r'^(\s*[-*+]\s+)\[([ xX])\]'),
    (m) => '${m.group(1)}[${m.group(2) == ' ' ? 'x' : ' '}]',
  );
  return lines.join('\n');
}

/// Préfixe à répéter sur la ligne suivante quand on appuie sur Entrée au
/// bout d'un élément de liste (null si la ligne n'est pas une liste).
String? continuationPrefix(String line) {
  final c = RegExp(r'^(\s*[-*+]\s+)\[[ xX]\]\s').firstMatch(line);
  if (c != null) return '${c.group(1)}[ ] ';
  final b = RegExp(r'^(\s*[-*+]\s+)').firstMatch(line);
  return b?.group(1);
}

final _inline = RegExp(r'\*\*(.+?)\*\*|\*(\S(?:.*?\S)?)\*|_(\S(?:.*?\S)?)_');

/// Gras et italique dans une ligne.
List<InlineSpan> inlineSpans(String text, TextStyle base) {
  final out = <InlineSpan>[];
  int last = 0;
  for (final m in _inline.allMatches(text)) {
    if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start)));
    if (m.group(1) != null) {
      out.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
    } else {
      out.add(TextSpan(text: m.group(2) ?? m.group(3), style: const TextStyle(fontStyle: FontStyle.italic)));
    }
    last = m.end;
  }
  if (last < text.length) out.add(TextSpan(text: text.substring(last)));
  return out;
}

/// Affichage d'une note. [onToggle] reçoit l'index de ligne d'une case cochée.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.body, this.onToggle});

  final String body;
  final void Function(int lineIndex)? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge!.copyWith(height: 1.4);
    final lines = body.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < lines.length; i++) _line(context, i, parseLine(lines[i]), base),
      ],
    );
  }

  Widget _line(BuildContext context, int i, MdLine l, TextStyle base) {
    final theme = Theme.of(context);
    Widget rich(TextStyle style) => Text.rich(TextSpan(style: style, children: inlineSpans(l.text, style)));
    final pad = EdgeInsets.only(left: 20.0 * l.indent);
    switch (l.kind) {
      case MdKind.blank:
        return const SizedBox(height: 10);
      case MdKind.heading1:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: rich(theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700)),
        );
      case MdKind.heading2:
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: rich(theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
        );
      case MdKind.paragraph:
        return rich(base);
      case MdKind.bullet:
        return Padding(
          padding: pad,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 20, child: Text('•', style: base)),
            Expanded(child: rich(base)),
          ]),
        );
      case MdKind.checkbox:
        final style = l.checked
            ? base.copyWith(decoration: TextDecoration.lineThrough, color: theme.colorScheme.onSurfaceVariant)
            : base;
        return Padding(
          padding: pad,
          child: InkWell(
            onTap: onToggle == null ? null : () => onToggle!(i),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 32,
                height: 28,
                child: Checkbox(
                  value: l.checked,
                  visualDensity: VisualDensity.compact,
                  onChanged: onToggle == null ? null : (_) => onToggle!(i),
                ),
              ),
              Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: rich(style))),
            ]),
          ),
        );
    }
  }
}
