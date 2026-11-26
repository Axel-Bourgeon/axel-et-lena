import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'respiration.dart';

enum BreathSignal {
  visual('Bulle', Icons.bubble_chart_outlined),
  sound('Son', Icons.music_note_outlined),
  both('Les deux', Icons.all_inclusive);

  const BreathSignal(this.label, this.icon);
  final String label;
  final IconData icon;

  bool get showsBubble => this != sound;
  bool get plays => this != visual;
}

/// Réglages de la séance (rythme, durée, signal).
class RespirationPage extends StatefulWidget {
  const RespirationPage({super.key});

  @override
  State<RespirationPage> createState() => _RespirationPageState();
}

class _RespirationPageState extends State<RespirationPage> {
  SharedPreferences? _prefs;
  int _rhythm = 0;
  int _minutes = 5;
  BreathSignal _signal = BreathSignal.both;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _rhythm = (p.getInt('respi.rhythm') ?? 0).clamp(0, kRhythms.length - 1);
        _minutes = p.getInt('respi.minutes') ?? 5;
        _signal = BreathSignal.values.where((s) => s.name == p.getString('respi.signal')).firstOrNull ?? BreathSignal.both;
      });
    });
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setInt('respi.rhythm', _rhythm);
    p.setInt('respi.minutes', _minutes);
    p.setString('respi.signal', _signal.name);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Respiration')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Suis la bulle : elle monte quand tu inspires, elle descend quand tu expires. '
            'Six respirations par minute, pendant quelques minutes, aident à se calmer (cohérence cardiaque).',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text('Durée', style: text.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 3, label: Text('3 min')),
              ButtonSegment(value: 4, label: Text('4 min')),
              ButtonSegment(value: 5, label: Text('5 min')),
            ],
            selected: {_minutes},
            onSelectionChanged: (s) => setState(() {
              _minutes = s.first;
              _save();
            }),
          ),
          const SizedBox(height: 24),
          Text('Signal', style: text.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<BreathSignal>(
            segments: [
              for (final s in BreathSignal.values) ButtonSegment(value: s, label: Text(s.label), icon: Icon(s.icon)),
            ],
            selected: {_signal},
            onSelectionChanged: (s) => setState(() {
              _signal = s.first;
              _save();
            }),
          ),
          const SizedBox(height: 6),
          Text(
            _signal == BreathSignal.sound
                ? 'Écran sombre : ferme les yeux, une note monte à l\'inspiration et descend à l\'expiration.'
                : (_signal == BreathSignal.both ? 'La bulle et une note douce en même temps.' : 'Seulement la bulle, en silence.'),
            style: text.bodySmall,
          ),
          const SizedBox(height: 24),
          Text('Rythme', style: text.titleMedium),
          RadioGroup<int>(
            groupValue: _rhythm,
            onChanged: (v) => setState(() {
              _rhythm = v ?? 0;
              _save();
            }),
            child: Column(children: [
              for (int i = 0; i < kRhythms.length; i++)
                RadioListTile<int>(value: i, title: Text(kRhythms[i].label), contentPadding: EdgeInsets.zero),
            ]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => _SessionPage(rhythm: kRhythms[_rhythm], minutes: _minutes, signal: _signal),
            )),
            icon: const Icon(Icons.play_arrow),
            label: Text('Commencer · $_minutes min'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          ),
        ],
      ),
    );
  }
}

class _SessionPage extends StatefulWidget {
  const _SessionPage({required this.rhythm, required this.minutes, required this.signal});

  final BreathRhythm rhythm;
  final int minutes;
  final BreathSignal signal;

  @override
  State<_SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<_SessionPage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final AudioPlayer _player = AudioPlayer();
  late final Uint8List _inSound, _outSound, _chime;
  Duration _elapsed = Duration.zero;
  bool? _lastInhaling;
  bool _done = false;

  double get _total => widget.minutes * 60.0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _inSound = glideTone(seconds: widget.rhythm.inhale.toDouble(), rising: true);
    _outSound = glideTone(seconds: widget.rhythm.exhale.toDouble(), rising: false);
    _chime = chimeTone();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration d) {
    if (_done) return;
    final t = d.inMicroseconds / 1e6;
    if (t >= _total) {
      _finish();
      return;
    }
    final s = breathAt(t, widget.rhythm);
    if (s.inhaling != _lastInhaling) {
      _lastInhaling = s.inhaling;
      if (widget.signal.plays) _play(s.inhaling ? _inSound : _outSound);
      HapticFeedback.selectionClick();
    }
    setState(() => _elapsed = d);
  }

  Future<void> _play(Uint8List bytes) async {
    try {
      await _player.stop();
      await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {}
  }

  void _finish() {
    _ticker.stop();
    setState(() {
      _done = true;
      _elapsed = Duration(seconds: _total.round());
    });
    _play(_chime);
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _player.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _clock(double seconds) {
    final s = seconds.ceil().clamp(0, 3600);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = _elapsed.inMicroseconds / 1e6;
    final s = breathAt(t, widget.rhythm);
    final showBubble = widget.signal.showsBubble;
    const bg = Color(0xFF0E1A24);
    const fg = Color(0xFFBFD8E8);
    final phaseLeft = s.inhaling
        ? widget.rhythm.inhale - (t % widget.rhythm.cycle)
        : widget.rhythm.cycle - (t % widget.rhythm.cycle);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(children: [
          if (showBubble && !_done)
            LayoutBuilder(builder: (context, c) {
              final size = c.maxWidth * 0.32 + s.level * c.maxWidth * 0.08;
              final top = (c.maxHeight - size - 120) * (1 - s.level) + 60;
              return Stack(children: [
                // Rail : le chemin de la bulle.
                Positioned(
                  left: c.maxWidth / 2 - 1,
                  top: 60 + c.maxWidth * 0.18,
                  bottom: 60 + c.maxWidth * 0.18,
                  child: Container(width: 2, color: fg.withValues(alpha: 0.12)),
                ),
                Positioned(
                  left: (c.maxWidth - size) / 2,
                  top: top,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        colors: [const Color(0xFFE3F2FD), Color.lerp(const Color(0xFF4FA3C7), const Color(0xFF7FC8A9), s.level)!],
                      ),
                      boxShadow: [BoxShadow(color: const Color(0xFF4FA3C7).withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 4)],
                    ),
                  ),
                ),
              ]);
            }),
          Positioned(
            left: 0,
            right: 0,
            top: 16,
            child: Text(
              _done ? '' : _clock(_total - t),
              textAlign: TextAlign.center,
              style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 18, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_done) ...[
                const Icon(Icons.spa_outlined, color: fg, size: 56),
                const SizedBox(height: 12),
                const Text('Séance terminée', style: TextStyle(color: fg, fontSize: 28, fontWeight: FontWeight.w300)),
                const SizedBox(height: 8),
                Text('${widget.minutes} minutes de calme', style: TextStyle(color: fg.withValues(alpha: 0.7))),
              ] else if (!showBubble) ...[
                Text(
                  s.inhaling ? 'Inspire' : 'Expire',
                  style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 30, fontWeight: FontWeight.w300),
                ),
              ],
            ]),
          ),
          if (showBubble && !_done)
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: Text(
                '${s.inhaling ? 'Inspire' : 'Expire'}  ${phaseLeft.ceil()}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: fg, fontSize: 26, fontWeight: FontWeight.w300, letterSpacing: 1),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: fg),
                child: Text(_done ? 'Fermer' : 'Arrêter'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
