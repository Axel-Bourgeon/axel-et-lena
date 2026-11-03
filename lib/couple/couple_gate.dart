import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/settings.dart';
import '../home/settings_page.dart';
import 'cloud.dart';
import 'notifier.dart';

/// Écran d'accès commun aux applis du couple : vérifie que Firebase est
/// configuré, que l'on sait qui utilise ce téléphone, et que les deux
/// téléphones sont reliés. Affiche [builder] quand tout est prêt.
class CoupleGate extends StatefulWidget {
  const CoupleGate({super.key, required this.title, required this.settings, required this.builder});

  final String title;
  final AppSettings settings;
  final Widget Function(BuildContext context, CoupleCloud cloud, Person me) builder;

  @override
  State<CoupleGate> createState() => _CoupleGateState();
}

class _CoupleGateState extends State<CoupleGate> {
  CoupleCloud? _cloud;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  String? _createdCode;
  final _codeField = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _codeField.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final c = await CoupleCloud.instance();
      if (mounted) setState(() => _cloud = c);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await CoupleNotifier.start(widget.settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final cloud = _cloud;
        final me = widget.settings.me;
        if (cloud != null && me != null && cloud.paired && _createdCode == null) {
          return widget.builder(context, cloud, me);
        }
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: Padding(padding: const EdgeInsets.all(24), child: _setup(context, cloud, me)),
        );
      },
    );
  }

  Widget _setup(BuildContext context, CoupleCloud? cloud, Person? me) {
    final text = Theme.of(context).textTheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!CoupleCloud.configured) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        title: 'Bientôt disponible',
        body: 'Cette appli partagée a besoin du cloud (Firebase), qui n\'est pas encore configuré.',
      );
    }
    if (cloud == null || _error != null) {
      return _Message(
        icon: Icons.wifi_off_outlined,
        title: 'Connexion impossible',
        body: 'Vérifie la connexion internet pour la première utilisation.\n\n${_error ?? ''}',
        action: FilledButton(
          onPressed: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _init();
          },
          child: const Text('Réessayer'),
        ),
      );
    }
    if (me == null) {
      return _Message(
        icon: Icons.person_outline,
        title: 'À qui est ce téléphone ?',
        body: 'Choisis une fois pour toutes, pour que l\'autre sache qui a écrit quoi.',
        action: Wrap(spacing: 12, children: [
          for (final p in Person.values)
            FilledButton.tonal(onPressed: () => widget.settings.setMe(p), child: Text('Je suis ${p.label}')),
        ]),
      );
    }
    final code = _createdCode;
    if (code != null) {
      return ListView(children: [
        Text('Notre espace est créé', style: text.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Sur le téléphone de ${me.other.label}, ouvre cette appli et choisis « J\'ai un code », puis saisis :',
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        SelectableText(
          '${code.substring(0, 5)} ${code.substring(5)}',
          textAlign: TextAlign.center,
          style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 4),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            icon: const Icon(Icons.copy),
            label: const Text('Copier le code'),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => setState(() => _createdCode = null), child: const Text('C\'est fait')),
      ]);
    }
    return ListView(children: [
      Text('Relier nos deux téléphones', style: text.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(
        'À faire une seule fois : l\'un crée notre espace, l\'autre le rejoint avec le code affiché.',
        textAlign: TextAlign.center,
        style: text.bodyMedium,
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () => _run(() async {
                  final c = await cloud.create();
                  if (mounted) setState(() => _createdCode = c);
                }),
        icon: const Icon(Icons.add_home_outlined),
        label: const Text('Créer notre espace'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      const SizedBox(height: 28),
      Text('J\'ai un code', style: text.titleMedium),
      const SizedBox(height: 8),
      TextField(
        controller: _codeField,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'ABCDE 23456'),
      ),
      const SizedBox(height: 8),
      FilledButton.tonal(
        onPressed: _busy
            ? null
            : () => _run(() async {
                  await cloud.join(_codeField.text);
                  if (mounted) setState(() {});
                }),
        child: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Rejoindre'),
      ),
      const SizedBox(height: 24),
      TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SettingsPage(widget.settings)),
        ),
        child: Text('Ce téléphone est celui de ${me.label} (modifier)'),
      ),
    ]);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: scheme.primary),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    );
  }
}
