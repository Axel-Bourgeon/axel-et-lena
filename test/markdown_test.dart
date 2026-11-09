import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axel_lena/couple/markdown_lite.dart';

void main() {
  test('lignes', () {
    expect(parseLine('* lait').kind, MdKind.bullet);
    expect(parseLine('- pain').text, 'pain');
    expect(parseLine('  * sous-élément').indent, 1);
    final c = parseLine('- [x] couches');
    expect(c.kind, MdKind.checkbox);
    expect(c.checked, isTrue);
    expect(c.text, 'couches');
    expect(parseLine('* [ ] bavoirs').checked, isFalse);
    expect(parseLine('# Courses').kind, MdKind.heading1);
    expect(parseLine('## Bébé').kind, MdKind.heading2);
    expect(parseLine('').kind, MdKind.blank);
    expect(parseLine('*pas une liste*').kind, MdKind.paragraph);
  });

  test('cocher / décocher', () {
    const body = 'Courses\n- [ ] lait\n- [x] pain';
    expect(toggleCheckbox(body, 1), 'Courses\n- [x] lait\n- [x] pain');
    expect(toggleCheckbox(body, 2), 'Courses\n- [ ] lait\n- [ ] pain');
    expect(toggleCheckbox(body, 0), body);
  });

  test('continuation des listes', () {
    expect(continuationPrefix('* lait'), '* ');
    expect(continuationPrefix('  - pain'), '  - ');
    expect(continuationPrefix('- [x] fait'), '- [ ] ');
    expect(continuationPrefix('texte'), isNull);
  });

  test('gras et italique', () {
    final spans = inlineSpans('du **gras**, de l\'*italique* et du _penché_', const TextStyle());
    final texts = spans.map((s) => (s as TextSpan).text).toList();
    expect(texts, ['du ', 'gras', ', de l\'', 'italique', ' et du ', 'penché']);
    expect((spans[1] as TextSpan).style!.fontWeight, FontWeight.w700);
    expect((spans[3] as TextSpan).style!.fontStyle, FontStyle.italic);
  });
}
