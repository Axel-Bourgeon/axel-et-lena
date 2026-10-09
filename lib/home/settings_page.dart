import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../apps/registry.dart';
import '../core/settings.dart';

const String kAppVersion = '0.1.0';

class SettingsPage extends StatefulWidget {
  const SettingsPage(this.settings, {super.key});

  final AppSettings settings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _discordController;

  @override
  void initState() {
    super.initState();
    _discordController =
        TextEditingController(text: widget.settings.discordServerId);
  }

  @override
  void dispose() {
    _discordController.dispose();
    super.dispose();
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = widget.settings;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (BuildContext context, Widget? child) {
            final List<SubApp> hiddenApps = buildRegistry()
                .where((SubApp a) => settings.isHidden(a.id))
                .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: <Widget>[
                _sectionTitle(context, 'Thème'),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('Système'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Clair'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Sombre'),
                      ),
                    ],
                    selected: <ThemeMode>{settings.themeMode},
                    onSelectionChanged: (Set<ThemeMode> selection) {
                      if (selection.isNotEmpty) {
                        settings.setThemeMode(selection.first);
                      }
                    },
                  ),
                ),
                _sectionTitle(context, 'Couleur'),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: <Widget>[
                    for (final Color color in kSeedChoices)
                      _ColorDot(
                        color: color,
                        selected: color.toARGB32() == settings.seedColor,
                        onTap: () => settings.setSeedColor(color.toARGB32()),
                      ),
                  ],
                ),
                _sectionTitle(context, 'Discord'),
                TextField(
                  controller: _discordController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Identifiant du serveur',
                    border: OutlineInputBorder(),
                    helperMaxLines: 4,
                    helperText: 'Discord → Paramètres → Avancés → Mode '
                        'développeur, puis appui long sur le serveur → '
                        "Copier l'identifiant",
                  ),
                  onChanged: (String value) {
                    settings.setDiscordServerId(value);
                  },
                ),
                _sectionTitle(context, 'Agenda'),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<CalendarApp>(
                    showSelectedIcon: false,
                    segments: <ButtonSegment<CalendarApp>>[
                      for (final CalendarApp c in CalendarApp.values)
                        ButtonSegment<CalendarApp>(
                          value: c,
                          label: Text(c.label),
                        ),
                    ],
                    selected: <CalendarApp>{settings.calendarApp},
                    onSelectionChanged: (Set<CalendarApp> selection) {
                      if (selection.isNotEmpty) {
                        settings.setCalendarApp(selection.first);
                      }
                    },
                  ),
                ),
                _sectionTitle(context, 'Tuiles masquées'),
                if (hiddenApps.isEmpty)
                  Text(
                    'Aucune tuile masquée.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final SubApp app in hiddenApps)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(app.icon),
                      title: Text(app.title),
                      subtitle: Text(app.category.label),
                      trailing: TextButton(
                        onPressed: () => settings.showTile(app.id),
                        child: const Text('Afficher'),
                      ),
                    ),
                _sectionTitle(context, 'À propos'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Axel & Léna'),
                  subtitle: const Text('Version $kAppVersion'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Couleur',
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }
}
