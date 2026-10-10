import 'package:flutter_test/flutter_test.dart';

import 'package:axel_lena/apps/registry.dart';

void main() {
  test('le registre contient des ids uniques et les sous-applis attendues', () {
    final List<SubApp> apps = buildRegistry();
    final List<String> ids = apps.map((SubApp a) => a.id).toList();

    expect(ids.toSet().length, ids.length);
    expect(ids, containsAll(<String>['fourmis', 'habitkit', 'discord', 'des', 'cestun10', 'disque']));
  });

  test('les catégories ont un libellé français', () {
    expect(TileCategory.soloGames.label, 'Jeux solo');
    expect(TileCategory.duoGames.label, 'Jeux à deux');
    expect(TileCategory.tools.label, 'Outils');
    expect(TileCategory.links.label, 'Liens');
  });
}
