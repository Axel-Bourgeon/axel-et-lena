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
/// (expiration), pour suivre le rythme les yeux fermés.
///
/// Timbre chaud plutôt qu'un sinus pur : deux voix très légèrement
/// désaccordées (effet de chœur), quelques harmoniques qui s'éteignent vite,
/// un vibrato lent et un léger souffle (bruit filtré). La note monte et
/// descend en douceur, et s'éteint complètement avant la phase suivante :
/// aucun arrêt brusque.
Uint8List glideTone({required double seconds, required bool rising, int sampleRate = 44100}) {
  const low = 220.0, high = 277.2; // la → do#, une tierce : glissé discret
  const harmonics = [1.0, 0.32, 0.12, 0.05];
  final n = (seconds * sampleRate).round();
  final out = Float64List(n);
  final rnd = math.Random(7);
  final attack = math.min(1.4, seconds * 0.3);
  final end = seconds * 0.94; // silence juste avant la phase suivante
  final release = math.min(1.8, seconds * 0.4);
  final phases = List<double>.filled(harmonics.length * 2, 0);
  double noise = 0, peak = 1e-9;
  for (int i = 0; i < n; i++) {
    final t = i / sampleRate;
    final x = (t / seconds).clamp(0.0, 1.0);
    final glide = (1 - math.cos(math.pi * x)) / 2;
    final f0 = (rising ? low + (high - low) * glide : high - (high - low) * glide) *
        (1 + 0.003 * math.sin(2 * math.pi * 4.2 * t));
    double v = 0;
    for (int h = 0; h < harmonics.length; h++) {
      for (int voice = 0; voice < 2; voice++) {
        final f = f0 * (h + 1) + (voice == 0 ? -0.7 : 0.7);
        final k = h * 2 + voice;
        phases[k] += 2 * math.pi * f / sampleRate;
        v += math.sin(phases[k]) * harmonics[h];
      }
    }
    // Souffle : bruit blanc adouci par un filtre passe-bas simple.
    noise += 0.06 * ((rnd.nextDouble() * 2 - 1) - noise);
    v = v * 0.5 + noise * 1.6;
    double env;
    if (t < attack) {
      env = (1 - math.cos(math.pi * t / attack)) / 2;
    } else if (t > end) {
      env = 0;
    } else if (t > end - release) {
      env = (1 + math.cos(math.pi * (t - (end - release)) / release)) / 2;
    } else {
      env = 1;
    }
    out[i] = v * env;
    if (out[i].abs() > peak) peak = out[i].abs();
  }
  final samples = Int16List(n);
  final gain = 0.32 / peak;
  for (int i = 0; i < n; i++) {
    samples[i] = (out[i] * gain * 32767).round().clamp(-32768, 32767);
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
