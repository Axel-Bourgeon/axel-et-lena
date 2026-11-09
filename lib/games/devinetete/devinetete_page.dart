import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Devine-tête : l'un tient le téléphone sur son front avec la photo d'un
/// personnage, et pose des questions fermées pour deviner qui c'est.
class DevineTetePage extends StatefulWidget {
  const DevineTetePage({super.key});

  @override
  State<DevineTetePage> createState() => _DevineTetePageState();
}

class _DevineTetePageState extends State<DevineTetePage> {
  List<File> _photos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Les photos sont copiées dans le dossier de l'appli pour être gardées.
  Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/devinetete');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<void> _load() async {
    final d = await _dir();
    final files = d.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
    if (mounted) {
      setState(() {
        _photos = files;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
    if (picked.isEmpty) return;
    final d = await _dir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < picked.length; i++) {
      final ext = picked[i].path.contains('.') ? picked[i].path.split('.').last : 'jpg';
      await File(picked[i].path).copy('${d.path}/${stamp}_$i.$ext');
    }
    await _load();
  }

  Future<void> _remove(File f) async {
    await f.delete();
    await _load();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer toutes les photos ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true) return;
    for (final f in _photos) {
      await f.delete();
    }
    await _load();
  }

  void _play() {
    final deck = List<File>.of(_photos)..shuffle(math.Random());
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _GamePage(deck: deck)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devine-tête'),
        actions: [
          if (_photos.isNotEmpty)
            IconButton(tooltip: 'Tout retirer', icon: const Icon(Icons.delete_sweep_outlined), onPressed: _clear),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Text(
                  'Télécharge des photos de personnages (célébrités, héros de films…), ajoute-les ici, '
                  'puis lance la partie : celui qui devine tient le téléphone sur son front, écran vers '
                  'l\'autre, et pose des questions auxquelles on répond par oui ou non.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Ajouter des photos'),
                ),
                const SizedBox(height: 16),
                if (_photos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Aucune photo pour l\'instant.', textAlign: TextAlign.center, style: text.bodyMedium),
                  )
                else ...[
                  Text('${_photos.length} photo${_photos.length > 1 ? 's' : ''} (appui long pour retirer)',
                      style: text.bodySmall),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (final f in _photos)
                        GestureDetector(
                          onLongPress: () => _remove(f),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(f, fit: BoxFit.cover, cacheWidth: 240),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _photos.isEmpty ? null : _play,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Jouer'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ],
            ),
    );
  }
}

class _GamePage extends StatefulWidget {
  const _GamePage({required this.deck});
  final List<File> deck;

  @override
  State<_GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<_GamePage> {
  int _index = 0;
  int _found = 0;
  int _skipped = 0;
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // L'écran ne doit surtout pas se mettre en veille pendant la partie.
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  bool get _over => _index >= widget.deck.length;

  void _next({required bool found}) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (found) {
        _found++;
      } else {
        _skipped++;
      }
      _index++;
      _clock
        ..reset()
        ..start();
    });
  }

  String get _time {
    final s = _clock.elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_over) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Partie terminée', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text('$_found trouvé${_found > 1 ? 's' : ''} · $_skipped passé${_skipped > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Retour')),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: Image.file(widget.deck[_index], fit: BoxFit.contain),
        ),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Text(
              '${_index + 1} / ${widget.deck.length}   ·   $_time',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16, shadows: [Shadow(blurRadius: 4)]),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: SafeArea(
            child: Row(children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _next(found: false),
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Passer'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _next(found: true),
                  icon: const Icon(Icons.check),
                  label: const Text('Trouvé !'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: const Color(0xFF4E9A5B),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: SafeArea(
            child: IconButton(
              tooltip: 'Quitter',
              color: Colors.white70,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ]),
    );
  }
}
