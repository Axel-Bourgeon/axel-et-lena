/// Mot du jour : même mot pour tout le monde le même jour, sans connexion.
///
/// Le numéro du jour (compté depuis [epoch]) choisit un mot dans la liste
/// [answers], mélangée une fois pour toutes avec un générateur fixe : les deux
/// téléphones, avec la même version de l'appli, tombent sur le même mot.
library;

enum LetterState { absent, present, correct }

class WordOfTheDay {
  WordOfTheDay({required List<String> answers, required Set<String> valid})
      : _order = _shuffled(answers),
        _valid = valid;

  static const int length = 5;
  static const int maxTries = 6;

  /// Premier jour du jeu (mot n° 1).
  static final DateTime epoch = DateTime.utc(2026, 10, 9);

  final List<String> _order;
  final Set<String> _valid;

  /// Numéro du jour (0 = [epoch]) pour une date locale.
  static int dayIndex(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day).difference(epoch).inDays;

  String wordFor(int day) => _order[day % _order.length];

  bool isValid(String guess) => _valid.contains(guess) || _order.contains(guess);

  /// Mélange déterministe (xorshift32), indépendant de la version de Dart.
  static List<String> _shuffled(List<String> words) {
    final list = List<String>.of(words)..sort();
    int s = 0x2F6E2B1;
    int next() {
      s ^= (s << 13) & 0xFFFFFFFF;
      s ^= s >> 17;
      s ^= (s << 5) & 0xFFFFFFFF;
      return s & 0xFFFFFFFF;
    }

    for (int i = list.length - 1; i > 0; i--) {
      final j = next() % (i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
    return list;
  }

  /// Couleurs d'un essai, avec gestion correcte des lettres en double.
  static List<LetterState> score(String guess, String answer) {
    final out = List<LetterState>.filled(length, LetterState.absent);
    final left = <String, int>{};
    for (int i = 0; i < length; i++) {
      if (guess[i] == answer[i]) {
        out[i] = LetterState.correct;
      } else {
        left[answer[i]] = (left[answer[i]] ?? 0) + 1;
      }
    }
    for (int i = 0; i < length; i++) {
      if (out[i] == LetterState.correct) continue;
      final n = left[guess[i]] ?? 0;
      if (n > 0) {
        out[i] = LetterState.present;
        left[guess[i]] = n - 1;
      }
    }
    return out;
  }
}

/// Retire accents et ligatures : « Été » → « ete ».
String normalizeWord(String w) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final b = StringBuffer();
  for (final ch in w.toLowerCase().split('')) {
    final k = from.indexOf(ch);
    if (ch == 'œ') {
      b.write('oe');
    } else if (ch == 'æ') {
      b.write('ae');
    } else {
      b.write(k >= 0 ? to[k] : ch);
    }
  }
  return b.toString();
}

/// Résultat à partager (grille d'émojis, sans les lettres).
String shareText(int day, List<String> guesses, String answer) {
  final won = guesses.isNotEmpty && guesses.last == answer;
  final lines = [
    for (final g in guesses)
      WordOfTheDay.score(g, answer).map((s) => switch (s) {
            LetterState.correct => '🟩',
            LetterState.present => '🟨',
            LetterState.absent => '⬜',
          }).join(),
  ];
  return 'Mot du jour n° ${day + 1} — ${won ? guesses.length : 'X'}/${WordOfTheDay.maxTries}\n${lines.join('\n')}';
}
