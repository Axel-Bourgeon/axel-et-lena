import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../apps/registry.dart';
import '../core/settings.dart';
import '../core/together.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.settings});

  final AppSettings settings;

  void _openSettings(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SettingsPage(settings)),
    );
  }

  Future<void> _showTileMenu(BuildContext context, SubApp app) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    app.title,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Masquer cette tuile'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  settings.hideTile(app.id);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (BuildContext context, Widget? child) {
            final List<SubApp> visible = buildRegistry()
                .where((SubApp a) => !settings.isHidden(a.id))
                .toList();

            final List<Widget> slivers = <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Axel & Léna',
                              style: textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const _TogetherCounter(),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Réglages',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => _openSettings(context),
                      ),
                    ],
                  ),
                ),
              ),
            ];

            if (visible.isEmpty) {
              slivers.add(
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Toutes les tuiles sont masquées. '
                      'Tu peux les réafficher dans Réglages.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }

            for (final TileCategory category in TileCategory.values) {
              final List<SubApp> items = visible
                  .where((SubApp a) => a.category == category)
                  .toList();
              if (items.isEmpty) continue;

              slivers.add(
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Text(
                      category.label,
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
              slivers.add(
                SliverToBoxAdapter(
                  child: _CategoryStrip(
                    items: items,
                    onTap: (SubApp app) => app.open(context, settings),
                    onLongPress: (SubApp app) => _showTileMenu(context, app),
                  ),
                ),
              );
            }

            slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));

            return CustomScrollView(slivers: slivers);
          },
        ),
      ),
    );
  }
}

/// Tuiles d'une catégorie : bande horizontale de deux rangées. Au-delà de
/// quatre tuiles, on glisse vers la gauche ; une colonne dépasse un peu du
/// bord pour le signaler.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.items,
    required this.onTap,
    required this.onLongPress,
  });

  final List<SubApp> items;
  final void Function(SubApp app) onTap;
  final void Function(SubApp app) onLongPress;

  static const double _gap = 12;
  static const double _tileHeight = 136;

  @override
  Widget build(BuildContext context) {
    final int rows = items.length > 2 ? 2 : 1;
    final int columns = (items.length / rows).ceil();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double available = c.maxWidth - 40;
        final double tileWidth = columns <= 2
            ? (available - _gap) / 2
            : math.min(220, (available - _gap) / 2.35);
        return SizedBox(
          height: rows * _tileHeight + (rows - 1) * _gap,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: columns <= 2 ? const NeverScrollableScrollPhysics() : null,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: rows,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
              mainAxisExtent: tileWidth,
            ),
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              // Remplissage ligne par ligne (et non colonne par colonne) pour
              // garder l'ordre de lecture : 1 2 3 / 4 5 6.
              final int col = index ~/ rows, row = index % rows;
              final int i = row * columns + col;
              if (i >= items.length) return const SizedBox.shrink();
              final SubApp app = items[i];
              return _Tile(
                app: app,
                onTap: () => onTap(app),
                onLongPress: () => onLongPress(app),
              );
            },
          ),
        );
      },
    );
  }
}

/// « Ensemble depuis X jours », avec le détail en années / mois / jours.
class _TogetherCounter extends StatelessWidget {
  const _TogetherCounter();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime now = DateTime.now();
    final TogetherSpan span = togetherSpan(
      kTogetherSince,
      DateTime.utc(now.year, now.month, now.day),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              const TextSpan(text: 'Ensemble depuis '),
              TextSpan(
                text: formatThousands(span.days),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: span.days > 1 ? ' jours ' : ' jour '),
              TextSpan(
                text: '♥',
                style: TextStyle(color: scheme.primary),
              ),
            ],
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          span.isAnniversary
              ? 'Joyeux anniversaire : ${span.years} ans aujourd\'hui !'
              : span.detail,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.app,
    required this.onTap,
    required this.onLongPress,
  });

  final SubApp app;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface.withValues(alpha: 0.75),
                ),
                child: Icon(app.icon, color: scheme.primary, size: 22),
              ),
              const Spacer(),
              Text(
                app.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                app.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
