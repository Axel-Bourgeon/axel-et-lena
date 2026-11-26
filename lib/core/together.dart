/// Durée écoulée depuis une date, pour le compteur de l'accueil.
class TogetherSpan {
  const TogetherSpan({
    required this.days,
    required this.years,
    required this.months,
    required this.restDays,
  });

  /// Nombre total de jours.
  final int days;

  /// Décomposition en années, mois et jours.
  final int years;
  final int months;
  final int restDays;

  bool get isAnniversary => years > 0 && months == 0 && restDays == 0;

  /// Ex. « 9 ans, 4 mois et 8 jours ».
  String get detail {
    final List<String> parts = <String>[
      if (years > 0) '$years ${years > 1 ? 'ans' : 'an'}',
      if (months > 0) '$months mois',
      if (restDays > 0) '$restDays ${restDays > 1 ? 'jours' : 'jour'}',
    ];
    if (parts.isEmpty) return "Aujourd'hui";
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} et ${parts.last}';
  }
}

/// [since] et [today] sont des dates UTC à minuit (pas d'effet d'heure d'été).
TogetherSpan togetherSpan(DateTime since, DateTime today) {
  final int days = today.difference(since).inDays;
  // Plus grand nombre de mois entiers écoulés (31 janv. + 1 mois = 28 févr.).
  int total = (today.year - since.year) * 12 + today.month - since.month;
  while (total > 0 && _addMonths(since, total).isAfter(today)) {
    total--;
  }
  if (total < 0) total = 0;
  return TogetherSpan(
    days: days,
    years: total ~/ 12,
    months: total % 12,
    restDays: today.difference(_addMonths(since, total)).inDays,
  );
}

DateTime _addMonths(DateTime d, int months) {
  final int m = d.month - 1 + months;
  final int year = d.year + m ~/ 12, month = m % 12 + 1;
  final int lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, d.day > lastDay ? lastDay : d.day);
}

/// Premier jour des dernières règles : la grossesse se compte à partir de là.
final DateTime kLastPeriod = DateTime.utc(2026, 7, 21);

/// Décompte jusqu'à la naissance. [today] : date UTC à minuit.
class BabyCountdown {
  BabyCountdown(this.lastPeriod, this.today);

  final DateTime lastPeriod;
  final DateTime today;

  /// Terme à 41 SA (287 jours après le début des dernières règles,
  /// convention française).
  DateTime get dueDate => lastPeriod.add(const Duration(days: 287));

  int get daysLeft => dueDate.difference(today).inDays;

  int get _daysSinceStart => today.difference(lastPeriod).inDays;
  int get weeks => _daysSinceStart ~/ 7;
  int get extraDays => _daysSinceStart % 7;

  /// Mois de grossesse en cours (1 à 9), comptés depuis la conception
  /// (2 semaines après le début des règles), mois moyen de 30,4 jours.
  int get month => (((_daysSinceStart - 14) / 30.4375).floor() + 1).clamp(1, 9);

  String get label {
    if (daysLeft > 1) return 'Bébé arrive dans ${formatThousands(daysLeft)} jours';
    if (daysLeft == 1) return 'Bébé arrive demain !';
    if (daysLeft == 0) return "C'est le grand jour !";
    return 'Bébé est là depuis ${formatThousands(-daysLeft)} jour${-daysLeft > 1 ? 's' : ''}';
  }

  /// Ex. « 18 SA + 2 j » (vide après la naissance).
  String get pregnancyLabel => daysLeft < 0 ? '' : '$weeks SA${extraDays > 0 ? ' + $extraDays j' : ''}';

  /// Ex. « 4e mois de grossesse ».
  String get monthLabel => daysLeft < 0 ? '' : '${month == 1 ? '1er' : '${month}e'} mois de grossesse';

  /// Ex. « 4 mai 2027 ».
  String get dueLabel {
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    final d = dueDate;
    return '${d.day == 1 ? '1er' : d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Avancement de la grossesse, de 0 à 1.
  double get progress => (_daysSinceStart / 287).clamp(0.0, 1.0);
}

/// 3417 → « 3 417 » (espace fine insécable).
String formatThousands(int n) {
  final String s = n.toString();
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}
