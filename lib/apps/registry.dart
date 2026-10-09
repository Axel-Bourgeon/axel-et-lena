import 'package:flutter/material.dart';

import '../core/launcher.dart';
import '../core/settings.dart';
import '../games/fourmis/fourmis_page.dart';
import '../games/puissance4/puissance4_page.dart';

enum TileCategory {
  soloGames('Jeux solo'),
  duoGames('Jeux à deux'),
  tools('Outils'),
  links('Liens');

  const TileCategory(this.label);

  final String label;
}

class SubApp {
  const SubApp({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    required this.open,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final TileCategory category;
  final Future<void> Function(BuildContext context, AppSettings settings) open;
}

/// Liste de toutes les sous-applis. Pour en ajouter une : ajouter une entrée ici.
List<SubApp> buildRegistry() {
  return <SubApp>[
    SubApp(
      id: 'fourmis',
      title: 'Fourmis',
      subtitle: 'Photo pixellisée à vider',
      icon: Icons.bug_report_outlined,
      category: TileCategory.soloGames,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const FourmisPage()),
        );
      },
    ),
    SubApp(
      id: 'puissance4',
      title: 'Puissance 4',
      subtitle: 'À deux ou contre le téléphone',
      icon: Icons.grid_on_outlined,
      category: TileCategory.duoGames,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const Puissance4Page()),
        );
      },
    ),
    SubApp(
      id: 'habitkit',
      title: 'HabitKit',
      subtitle: 'Nos habitudes',
      icon: Icons.check_circle_outline,
      category: TileCategory.tools,
      open: (BuildContext context, AppSettings settings) {
        return Launcher.openHabitKit(context);
      },
    ),
    SubApp(
      id: 'agenda',
      title: 'Agenda',
      subtitle: 'Google Agenda ou Outlook (Réglages)',
      icon: Icons.calendar_month_outlined,
      category: TileCategory.tools,
      open: (BuildContext context, AppSettings settings) {
        return Launcher.openCalendar(context, settings.calendarApp);
      },
    ),
    SubApp(
      id: 'discord',
      title: 'Discord',
      subtitle: 'Serveur Léna et Axel',
      icon: Icons.forum_outlined,
      category: TileCategory.links,
      open: (BuildContext context, AppSettings settings) {
        return Launcher.openDiscordServer(context, settings.discordServerId);
      },
    ),
  ];
}
