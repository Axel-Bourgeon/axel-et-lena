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

/// Date prévue de naissance du bébé.
final DateTime kBabyDueDate = DateTime.utc(2027, 5, 1);

/// Décompte jusqu'à la naissance. [today] : date UTC à minuit.
class BabyCountdown {
  BabyCountdown(this.dueDate, this.today);

  final DateTime dueDate;
  final DateTime today;

  int get daysLeft => dueDate.difference(today).inDays;

  /// Semaines d'aménorrhée : le terme est à 41 SA (287 jours après le début
  /// des dernières règles, convention française).
  int get _daysSinceStart => 287 - daysLeft;
  int get weeks => _daysSinceStart ~/ 7;
  int get extraDays => _daysSinceStart % 7;

  String get label {
    if (daysLeft > 1) return 'Bébé arrive dans ${formatThousands(daysLeft)} jours';
    if (daysLeft == 1) return 'Bébé arrive demain !';
    if (daysLeft == 0) return "C'est le grand jour !";
    return 'Bébé est là depuis ${formatThousands(-daysLeft)} jour${-daysLeft > 1 ? 's' : ''}';
  }

  /// Ex. « 15 SA + 3 j » (vide après la naissance).
  String get pregnancyLabel => daysLeft < 0 ? '' : '$weeks SA${extraDays > 0 ? ' + $extraDays j' : ''}';

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
