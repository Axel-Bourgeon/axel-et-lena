import 'package:flutter/material.dart';

import '../apps/registry.dart';
import '../core/settings.dart';
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
                            Text(
                              'Notre petit coin à nous',
                              style: textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
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
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 172,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final SubApp app = items[index];
                        return _Tile(
                          app: app,
                          onTap: () {
                            app.open(context, settings);
                          },
                          onLongPress: () {
                            _showTileMenu(context, app);
                          },
                        );
                      },
                      childCount: items.length,
                    ),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface.withValues(alpha: 0.75),
                ),
                child: Icon(app.icon, color: scheme.primary),
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
