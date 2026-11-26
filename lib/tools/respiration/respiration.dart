import 'dart:math' as math;
import 'dart:typed_data';

/// Rythme de respiration : durée de l'inspiration et de l'expiration.
class BreathRhythm {
  const BreathRhythm(this.inhale, this.exhale, this.label);
  final int inhale;
  final int exhale;
  final String label;

  int get cycle => inhale + exhale;
}

const List<BreathRhythm> kRhythms = [
  BreathRhythm(5, 5, '5 s / 5 s · cohérence cardiaque'),
  BreathRhythm(4, 6, '4 s / 6 s · plus apaisant'),
  BreathRhythm(4, 4, '4 s / 4 s · plus court'),
];

/// Où en est la respiration à l'instant [t] (en secondes).
class BreathState {
  const BreathState({required this.inhaling, required this.level, required this.cycleIndex});

  final bool inhaling;

  /// Hauteur de la bulle : 0 = en bas (poumons vides), 1 = en haut.
  final double level;

  /// Numéro du cycle en cours (0, 1, 2…).
  final int cycleIndex;
}

BreathState breathAt(double t, BreathRhythm r) {
  final cycle = r.cycle.toDouble();
  final idx = (t / cycle).floor();
  final inCycle = t - idx * cycle;
  // Courbe douce (sinus) : la bulle ralentit en haut et en bas.
  double ease(double x) => (1 - math.cos(math.pi * x.clamp(0.0, 1.0))) / 2;
  if (inCycle < r.inhale) {
    return BreathState(inhaling: true, level: ease(inCycle / r.inhale), cycleIndex: idx);
  }
  return BreathState(inhaling: false, level: 1 - ease((inCycle - r.inhale) / r.exhale), cycleIndex: idx);
}

/// Son doux pour une phase : une note qui monte (inspiration) ou descend
/// (expiration) pendant [seconds], pour suivre le rythme les yeux fermés.
Uint8List glideTone({required double seconds, required bool rising, int sampleRate = 22050}) {
  const low = 196.0, high = 294.0; // sol → ré
  final n = (seconds * sampleRate).round();
  final samples = Int16List(n);
  double phase = 0;
  for (int i = 0; i < n; i++) {
    final x = i / n;
    final glide = (1 - math.cos(math.pi * x)) / 2;
    final f = rising ? low + (high - low) * glide : high - (high - low) * glide;
    phase += 2 * math.pi * f / sampleRate;
    final tSec = i / sampleRate, left = (n - i) / sampleRate;
    final env = math.min(1.0, math.min(tSec / 0.5, left / 0.8));
    final v = (math.sin(phase) * 0.8 + math.sin(2 * phase) * 0.15) * env * 0.35;
    samples[i] = (v * 32767).round().clamp(-32768, 32767);
  }
  return _wav(samples, sampleRate);
}

/// Petit carillon de fin de séance.
Uint8List chimeTone({int sampleRate = 22050}) {
  const seconds = 2.5;
  final n = (seconds * sampleRate).round();
  final samples = Int16List(n);
  for (int i = 0; i < n; i++) {
    final t = i / sampleRate;
    final env = math.exp(-t * 1.8) * math.min(1.0, t / 0.01);
    final v = (math.sin(2 * math.pi * 523.25 * t) * 0.6 + math.sin(2 * math.pi * 784 * t) * 0.3 + math.sin(2 * math.pi * 1046.5 * t) * 0.1) * env * 0.4;
    samples[i] = (v * 32767).round().clamp(-32768, 32767);
  }
  return _wav(samples, sampleRate);
}

Uint8List _wav(Int16List samples, int sampleRate) {
  final dataLen = samples.length * 2;
  final b = ByteData(44 + dataLen);
  void str(int o, String s) {
    for (int i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, dataLen, Endian.little);
  for (int i = 0; i < samples.length; i++) {
    b.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return b.buffer.asUint8List();
}
