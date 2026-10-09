import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/photo.dart';
import 'game_page.dart';
import 'painter.dart';
import 'palette.dart';
import 'puzzle.dart';

/// Écran de préparation : choix de la photo et des réglages.
class FourmisPage extends StatefulWidget {
  const FourmisPage({super.key});

  @override
  State<FourmisPage> createState() => _FourmisPageState();
}

class _FourmisPageState extends State<FourmisPage> {
  static const _sizes = {'Petite': 22, 'Moyenne': 30, 'Grande': 40};

  String _sizeLabel = 'Petite';
  int _colors = 6;
  ColorContrast _contrast = ColorContrast.contrasted;
  int _slots = 5;

  /// Image source décodée (RGBA), conservée pour recalculer à chaque réglage.
  Uint8List? _rgba;
  int _srcW = 0, _srcH = 0;
  int _sampleSeed = 7;
  PixelPuzzle? _puzzle;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  void _rebuild() {
    final width = _sizes[_sizeLabel]!;
    final rgba = _rgba;
    setState(() {
      final base = rgba == null
          ? _limitColors(generateSamplePuzzle(width: width, seed: _sampleSeed))
          : buildPuzzleFromRgba(
              rgba: rgba,
              srcWidth: _srcW,
              srcHeight: _srcH,
              targetWidth: width,
              colorCount: _colors,
            );
      _puzzle = PixelPuzzle(
        width: base.width,
        height: base.height,
        cells: base.cells,
        palette: separatePalette(base.palette, _contrast),
      );
    });
  }

  /// Pour l'image d'exemple : ne garde que [_colors] couleurs au plus.
  PixelPuzzle _limitColors(PixelPuzzle p) {
    if (p.palette.length <= _colors) return p;
    final pixels = [
      for (final c in p.cells)
        [
          ((p.palette[c] >> 16) & 0xFF).toDouble(),
          ((p.palette[c] >> 8) & 0xFF).toDouble(),
          (p.palette[c] & 0xFF).toDouble(),
        ],
    ];
    final q = quantize(pixels, _colors);
    return PixelPuzzle(width: p.width, height: p.height, cells: q.labels, palette: q.palette);
  }

  /// [source] null : photo tirée au hasard dans la galerie.
  Future<void> _pick(ImageSource? source) async {
    setState(() => _loading = true);
    try {
      ui.Image? image;
      if (source == null) {
        image = await randomGalleryImage(maxSide: 480);
        if (image == null) throw Exception('aucune photo dans la galerie');
      } else {
        final file = await ImagePicker().pickImage(
          source: source,
          maxWidth: 480,
          maxHeight: 480,
          imageQuality: 92,
        );
        if (file == null) return;
        final codec = await ui.instantiateImageCodec(await file.readAsBytes());
        image = (await codec.getNextFrame()).image;
      }
      _rgba = await rgbaOf(image);
      _srcW = image.width;
      _srcH = image.height;
      image.dispose();
      _rebuild();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is GalleryAccessDenied ? '$e' : 'Impossible de charger l\'image ($e)'),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _surprise() {
    _rgba = null;
    _sampleSeed = math.Random().nextInt(1000);
    _rebuild();
  }

  void _play() {
    final p = _puzzle;
    if (p == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FourmisGamePage(puzzle: p, slotCount: _slots)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _puzzle;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Fourmis')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            'Ouvrez des sachets : leurs fourmis vont chercher les pixels de leur couleur. '
            'Seuls les pixels touchant l\'extérieur sont accessibles.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _loading || p == null
                    ? const Center(child: CircularProgressIndicator())
                    : CustomPaint(painter: PuzzlePreviewPainter(p)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galerie'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Photo'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pick(null),
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Au hasard'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _surprise,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Surprise'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Taille', style: text.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: [for (final s in _sizes.keys) ButtonSegment(value: s, label: Text(s))],
            selected: {_sizeLabel},
            onSelectionChanged: (v) {
              _sizeLabel = v.first;
              _rebuild();
            },
          ),
          const SizedBox(height: 16),
          Text('Couleurs : $_colors', style: text.titleSmall),
          Slider(
            value: _colors.toDouble(),
            min: 3,
            max: 10,
            divisions: 7,
            label: '$_colors',
            onChanged: (v) => setState(() => _colors = v.round()),
            onChangeEnd: (_) => _rebuild(),
          ),
          SegmentedButton<ColorContrast>(
            segments: [for (final c in ColorContrast.values) ButtonSegment(value: c, label: Text(c.label))],
            selected: {_contrast},
            showSelectedIcon: false,
            onSelectionChanged: (v) {
              _contrast = v.first;
              _rebuild();
            },
          ),
          const SizedBox(height: 16),
          Text('Emplacements : $_slots', style: text.titleSmall),
          Slider(
            value: _slots.toDouble(),
            min: 3,
            max: 7,
            divisions: 4,
            label: '$_slots',
            onChanged: (v) => setState(() => _slots = v.round()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: p == null || _loading ? null : _play,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Jouer'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}
