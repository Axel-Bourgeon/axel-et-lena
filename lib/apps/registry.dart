import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/launcher.dart';
import '../core/settings.dart';
import '../couple/baby_page.dart';
import '../couple/bag_page.dart';
import '../couple/conseils_page.dart';
import '../couple/contractions_page.dart';
import '../couple/cloud.dart';
import '../couple/couple_gate.dart';
import '../couple/messages_page.dart';
import '../couple/notes_page.dart';
import '../games/airhockey/airhockey_page.dart';
import '../games/cestun10/cestun10_page.dart';
import '../games/devinetete/devinetete_page.dart';
import '../games/disque/disque_page.dart';
import '../games/fourmis/fourmis_page.dart';
import '../games/motdujour/motdujour_page.dart';
import '../games/picross/picross_page.dart';
import '../games/pipopipette/pipopipette_page.dart';
import '../games/puissance4/puissance4_page.dart';
import '../games/taquin/taquin_page.dart';
import '../tools/des/des_page.dart';

enum TileCategory {
  couple('Couple'),
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
  Future<void> openCouple(
    BuildContext context,
    AppSettings settings,
    String title,
    Widget Function(CoupleCloud cloud, Person me) page,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CoupleGate(
          title: title,
          settings: settings,
          builder: (BuildContext context, CoupleCloud cloud, Person me) => page(cloud, me),
        ),
      ),
    );
  }

  return <SubApp>[
    SubApp(
      id: 'messages',
      title: 'Messages',
      subtitle: 'Une petite alerte pour l\'autre',
      icon: Icons.notifications_active_outlined,
      category: TileCategory.couple,
      open: (BuildContext context, AppSettings settings) => openCouple(
        context,
        settings,
        'Messages',
        (CoupleCloud cloud, Person me) => MessagesPage(cloud: cloud, me: me),
      ),
    ),
    SubApp(
      id: 'bebe',
      title: 'Bébé agenda',
      subtitle: 'Biberons, couches, dodos',
      icon: Icons.child_care_outlined,
      category: TileCategory.couple,
      open: (BuildContext context, AppSettings settings) => openCouple(
        context,
        settings,
        'Bébé agenda',
        (CoupleCloud cloud, Person me) => BabyPage(cloud: cloud, me: me),
      ),
    ),
    SubApp(
      id: 'conseils',
      title: 'Conseils bébé',
      subtitle: 'Repères officiels par âge',
      icon: Icons.menu_book_outlined,
      category: TileCategory.couple,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const ConseilsPage()),
        );
      },
    ),
    SubApp(
      id: '1000jours',
      title: '1000 premiers jours',
      subtitle: 'Le site officiel',
      icon: Icons.public,
      category: TileCategory.couple,
      open: (BuildContext context, AppSettings settings) async {
        final bool ok = await launchUrl(
          Uri.parse('https://www.1000-premiers-jours.fr/fr'),
          mode: LaunchMode.externalApplication,
        );
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Impossible d'ouvrir le site")),
          );
        }
      },
    ),
    SubApp(
      id: 'contractions',
      title: 'Contractions',
      subtitle: 'Minuteur partagé',
      icon: Icons.timer_outlined,
      category: TileCategory.couple,
      open: (BuildContext context, AppSettings settings) => openCouple(
        context,
        settings,
        'Contractions',
        (CoupleCloud cloud, Person me) => ContractionsPage(cloud: cloud, me: me),
      ),
    ),
    SubApp(
      id: 'valise',
      title: 'Valise maternité',
      subtitle: 'Check-list à deux',
      icon: Icons.luggage_outlined,
      category: TileCategory.couple,
      open: (BuildContext context, AppSettings settings) => openCouple(
        context,
        settings,
        'Valise maternité',
        (CoupleCloud cloud, Person me) => BagPage(cloud: cloud, me: me),
      ),
    ),
    SubApp(
      id: 'notes',
      title: 'Notes',
      subtitle: 'Nos notes partagées',
      icon: Icons.sticky_note_2_outlined,
      category: TileCategory.couple,
      open: (BuildContext context, AppSettings settings) => openCouple(
        context,
        settings,
        'Notes',
        (CoupleCloud cloud, Person me) => NotesPage(cloud: cloud, me: me),
      ),
    ),
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
      id: 'motdujour',
      title: 'Mot du jour',
      subtitle: 'Le même mot pour nous deux',
      icon: Icons.abc_outlined,
      category: TileCategory.soloGames,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const MotDuJourPage()),
        );
      },
    ),
    SubApp(
      id: 'picross',
      title: 'Picross',
      subtitle: 'Retrouver une photo case par case',
      icon: Icons.grid_4x4_outlined,
      category: TileCategory.soloGames,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const PicrossPage()),
        );
      },
    ),
    SubApp(
      id: 'taquin',
      title: 'Taquin',
      subtitle: 'Une photo à remettre en ordre',
      icon: Icons.apps_outlined,
      category: TileCategory.soloGames,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const TaquinPage()),
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
      id: 'pipopipette',
      title: 'Pipopipette',
      subtitle: 'Fermer le plus de carrés',
      icon: Icons.border_all_outlined,
      category: TileCategory.duoGames,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const PipopipettePage()),
        );
      },
    ),
    SubApp(
      id: 'airhockey',
      title: 'Air hockey',
      subtitle: 'Chacun son côté de l\'écran',
      icon: Icons.sports_hockey_outlined,
      category: TileCategory.duoGames,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AirHockeyPage()),
        );
      },
    ),
    SubApp(
      id: 'devinetete',
      title: 'Devine-tête',
      subtitle: 'Qui est sur ton front ?',
      icon: Icons.face_retouching_natural,
      category: TileCategory.duoGames,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const DevineTetePage()),
        );
      },
    ),
    SubApp(
      id: 'disque',
      title: 'Le Disque',
      subtitle: 'Deviner où se cache la cible',
      icon: Icons.speed_outlined,
      category: TileCategory.duoGames,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const DisquePage()),
        );
      },
    ),
    SubApp(
      id: 'cestun10',
      title: "C'est un 10, mais…",
      subtitle: 'Un nombre secret de 0 à 9',
      icon: Icons.looks_one_outlined,
      category: TileCategory.duoGames,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const CestUn10Page()),
        );
      },
    ),
    SubApp(
      id: 'des',
      title: 'Dés',
      subtitle: 'Pile ou face, D4 à D100, formules',
      icon: Icons.casino_outlined,
      category: TileCategory.tools,
      open: (BuildContext context, AppSettings settings) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const DesPage()),
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
