import 'dart:math' as math;

class Vec {
  const Vec(this.x, this.y);
  final double x, y;
  Vec operator +(Vec o) => Vec(x + o.x, y + o.y);
  Vec operator -(Vec o) => Vec(x - o.x, y - o.y);
  Vec operator *(double k) => Vec(x * k, y * k);
  double dot(Vec o) => x * o.x + y * o.y;
  double get length => math.sqrt(x * x + y * y);
  static const zero = Vec(0, 0);
}

/// Air hockey vu de dessus, en unités de table : largeur 1, hauteur [height].
/// Le joueur 0 défend le but du bas (y = height), le joueur 1 celui du haut.
class AirHockey {
  AirHockey({this.height = 1.75, this.winScore = 7}) {
    _resetPositions(servingPlayer: 0);
  }

  final double height;
  final int winScore;

  static const double puckR = 0.045;
  static const double malletR = 0.075;
  static const double goalWidth = 0.34;
  static const double maxPuckSpeed = 3.2;
  static const double restitution = 0.88;

  Vec puck = Vec.zero;
  Vec puckVel = Vec.zero;
  final List<Vec> mallets = [Vec.zero, Vec.zero];
  final List<Vec> _malletVel = [Vec.zero, Vec.zero];
  final List<Vec> _targets = [Vec.zero, Vec.zero];
  final List<int> scores = [0, 0];

  /// Temps restant avant la remise en jeu après un but.
  double pause = 0;

  /// Joueur qui vient de marquer (-1 si aucun) : pour l'affichage.
  int lastScorer = -1;

  /// Nombre de chocs depuis le dernier appel (pour les vibrations).
  int hits = 0;

  int get winner => scores[0] >= winScore ? 0 : (scores[1] >= winScore ? 1 : -1);

  double get _goalLeft => (1 - goalWidth) / 2;
  double get _goalRight => (1 + goalWidth) / 2;

  void _resetPositions({required int servingPlayer}) {
    mallets[0] = Vec(0.5, height - 0.18);
    mallets[1] = const Vec(0.5, 0.18);
    _targets[0] = mallets[0];
    _targets[1] = mallets[1];
    _malletVel[0] = Vec.zero;
    _malletVel[1] = Vec.zero;
    // Le palet part dans le camp de celui qui a encaissé.
    puck = Vec(0.5, servingPlayer == 0 ? height * 0.68 : height * 0.32);
    puckVel = Vec.zero;
  }

  void restart() {
    scores[0] = 0;
    scores[1] = 0;
    lastScorer = -1;
    pause = 0;
    _resetPositions(servingPlayer: 0);
  }

  /// Le doigt du joueur [player] vise [p] ; le maillet reste dans son camp.
  void setTarget(int player, Vec p) {
    final minY = player == 0 ? height / 2 + malletR : malletR;
    final maxY = player == 0 ? height - malletR : height / 2 - malletR;
    _targets[player] = Vec(
      p.x.clamp(malletR, 1 - malletR).toDouble(),
      p.y.clamp(minY, maxY).toDouble(),
    );
  }

  /// Adversaire simple pour le joueur 1 (haut).
  void phoneControl(double dt, {double skill = 0.8}) {
    final home = Vec(0.5, 0.16);
    Vec want;
    if (puck.y < height / 2 + 0.05) {
      // Le palet est chez nous : on vient le frapper par-dessus (côté but).
      want = Vec(puck.x, puck.y - puckR - malletR * 0.6);
    } else {
      // Défense : on s'aligne entre le palet et notre but.
      want = Vec(0.5 + (puck.x - 0.5) * 0.6, home.y);
    }
    final cur = _targets[1];
    final speed = 1.2 + 1.6 * skill;
    final d = want - cur;
    final len = d.length;
    final step = math.min(len, speed * dt);
    setTarget(1, len < 1e-6 ? cur : cur + d * (step / len));
  }

  void update(double dt) {
    if (dt <= 0 || winner >= 0) return;
    dt = math.min(dt, 1 / 30);
    if (pause > 0) {
      pause -= dt;
      return;
    }
    // Sous-pas pour éviter que le palet traverse un maillet.
    const sub = 6;
    final h = dt / sub;
    for (int s = 0; s < sub; s++) {
      for (int p = 0; p < 2; p++) {
        final next = mallets[p] + (_targets[p] - mallets[p]) * (s + 1 == sub ? 1.0 : 1.0 / (sub - s));
        _malletVel[p] = (next - mallets[p]) * (1 / h);
        mallets[p] = next;
      }
      _step(h);
      if (pause > 0) return;
    }
  }

  void _step(double dt) {
    puck = puck + puckVel * dt;
    // Frottement léger.
    puckVel = puckVel * math.pow(0.75, dt).toDouble();

    // Bords gauche / droit.
    if (puck.x < puckR) {
      puck = Vec(puckR, puck.y);
      puckVel = Vec(-puckVel.x * restitution, puckVel.y);
      hits++;
    } else if (puck.x > 1 - puckR) {
      puck = Vec(1 - puckR, puck.y);
      puckVel = Vec(-puckVel.x * restitution, puckVel.y);
      hits++;
    }
    // Bords haut / bas, sauf dans l'embouchure des buts.
    final inMouth = puck.x > _goalLeft + puckR * 0.5 && puck.x < _goalRight - puckR * 0.5;
    if (inMouth) {
      if (puck.y < -puckR) return _goal(0);
      if (puck.y > height + puckR) return _goal(1);
    } else {
      if (puck.y < puckR) {
        puck = Vec(puck.x, puckR);
        puckVel = Vec(puckVel.x, -puckVel.y * restitution);
        hits++;
      } else if (puck.y > height - puckR) {
        puck = Vec(puck.x, height - puckR);
        puckVel = Vec(puckVel.x, -puckVel.y * restitution);
        hits++;
      }
    }

    // Chocs avec les maillets (maillet de masse infinie).
    for (int p = 0; p < 2; p++) {
      final d = puck - mallets[p];
      final dist = d.length;
      const minDist = puckR + malletR;
      if (dist >= minDist) continue;
      final n = dist < 1e-6 ? Vec(0, p == 0 ? -1 : 1) : d * (1 / dist);
      puck = mallets[p] + n * minDist;
      final rel = puckVel - _malletVel[p];
      final vn = rel.dot(n);
      if (vn < 0) {
        puckVel = puckVel - n * ((1 + restitution) * vn);
        hits++;
      }
    }
    final speed = puckVel.length;
    if (speed > maxPuckSpeed) puckVel = puckVel * (maxPuckSpeed / speed);
  }

  /// [scorer] marque.
  void _goal(int scorer) {
    scores[scorer]++;
    lastScorer = scorer;
    pause = 1.0;
    _resetPositions(servingPlayer: 1 - scorer);
  }
}
