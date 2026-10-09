import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings.dart';

/// Ouverture d'applis externes (HabitKit, Discord, agenda) via le canal natif
/// défini dans MainActivity.kt, avec repli sur url_launcher.
class Launcher {
  Launcher._();

  static const MethodChannel _channel = MethodChannel('axel_lena/launcher');

  static const String habitKitPackage = 'com.roehl.habitkit';
  static const String discordPackage = 'com.discord';

  static Future<bool> _openApp(String package) async {
    final bool? ok = await _channel.invokeMethod<bool>(
      'openApp',
      <String, dynamic>{'package': package},
    );
    return ok ?? false;
  }

  static Future<bool> _openUrlInPackage(String url, String package) async {
    final bool? ok = await _channel.invokeMethod<bool>(
      'openUrlInPackage',
      <String, dynamic>{'url': url, 'package': package},
    );
    return ok ?? false;
  }

  static Future<bool> _launchExternal(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      return false;
    }
  }

  static void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ouvre l'appli [package] (éventuellement sur [deepLink]), ou sa fiche
  /// Play Store si elle n'est pas installée.
  static Future<void> _openAppOrStore(
    BuildContext context,
    String package,
    String name, {
    String? deepLink,
  }) async {
    try {
      if (deepLink != null && await _openUrlInPackage(deepLink, package)) {
        return;
      }
      if (await _openApp(package)) return;

      bool ok = await _launchExternal('market://details?id=$package');
      if (!ok) {
        ok = await _launchExternal(
          'https://play.google.com/store/apps/details?id=$package',
        );
      }
      if (!ok && context.mounted) {
        _snack(context, "Impossible d'ouvrir $name ni le Play Store.");
      }
    } on PlatformException {
      if (context.mounted) _snack(context, "Impossible d'ouvrir $name.");
    } on MissingPluginException {
      if (context.mounted) _snack(context, "Impossible d'ouvrir $name.");
    }
  }

  /// Ouvre HabitKit, ou sa fiche Play Store s'il n'est pas installé.
  static Future<void> openHabitKit(BuildContext context) {
    return _openAppOrStore(context, habitKitPackage, 'HabitKit');
  }

  /// Ouvre l'agenda choisi dans les Réglages (Google Agenda ou Outlook).
  static Future<void> openCalendar(BuildContext context, CalendarApp app) {
    return _openAppOrStore(
      context,
      app.package,
      app.label,
      deepLink: app.deepLink,
    );
  }

  /// Ouvre le serveur Discord (appli Discord si possible, sinon navigateur).
  static Future<void> openDiscordServer(
    BuildContext context,
    String serverId,
  ) async {
    final String id = serverId.trim();
    if (id.isEmpty) {
      _snack(
        context,
        "Renseigne l'identifiant du serveur Discord dans Réglages.",
      );
      return;
    }
    final String url = 'https://discord.com/channels/$id';
    try {
      final bool opened = await _openUrlInPackage(url, discordPackage);
      if (opened) return;

      final bool ok = await _launchExternal(url);
      if (!ok && context.mounted) {
        _snack(context, "Impossible d'ouvrir Discord.");
      }
    } on PlatformException {
      if (context.mounted) _snack(context, "Impossible d'ouvrir Discord.");
    } on MissingPluginException {
      if (context.mounted) _snack(context, "Impossible d'ouvrir Discord.");
    }
  }
}
