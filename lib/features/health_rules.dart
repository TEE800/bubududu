// Allgemeine Vorsorge- und Impfempfehlungen für Erwachsene in Deutschland
// (gesetzliche Krankenversicherung und STIKO, vereinfacht, Stand 2026).
// Ersetzt keine ärztliche Beratung.

enum Sex {
  female('weiblich'),
  male('männlich'),
  unknown('keine Angabe');

  const Sex(this.label);
  final String label;

  static Sex parse(String? name) =>
      Sex.values.where((s) => s.name == name).firstOrNull ?? Sex.unknown;
}

enum RecommendationKind { checkup, vaccination }

class Recommendation {
  const Recommendation({
    required this.key,
    required this.title,
    required this.kind,
    required this.detail,
    required this.minAge,
    this.maxAge,
    this.intervalMonths,
    this.sex,
  });

  /// Stabiler Schlüssel, mit dem Einträge der Empfehlung zugeordnet werden.
  final String key;
  final String title;
  final RecommendationKind kind;
  final String detail;
  final int minAge;
  final int? maxAge;

  /// null = einmalig.
  final int? intervalMonths;

  /// null = für alle.
  final Sex? sex;

  bool appliesTo(int age, Sex personSex) {
    if (age < minAge) return false;
    if (maxAge != null && age > maxAge!) return false;
    // Ohne Angabe zum Geschlecht zeigen wir geschlechtsbezogene Vorsorge vorsichtshalber an.
    if (sex != null && personSex != Sex.unknown && sex != personSex) {
      return false;
    }
    return true;
  }
}

const recommendations = <Recommendation>[
  Recommendation(
    key: 'zahn',
    title: 'Zahnvorsorge',
    kind: RecommendationKind.checkup,
    detail: 'Kontrolle beim Zahnarzt, wichtig fürs Bonusheft.',
    minAge: 18,
    intervalMonths: 12,
  ),
  Recommendation(
    key: 'checkup_jung',
    title: 'Check-up (Gesundheitsuntersuchung)',
    kind: RecommendationKind.checkup,
    detail: 'Einmal zwischen 18 und 34 beim Hausarzt.',
    minAge: 18,
    maxAge: 34,
  ),
  Recommendation(
    key: 'checkup',
    title: 'Check-up 35',
    kind: RecommendationKind.checkup,
    detail: 'Gesundheitsuntersuchung beim Hausarzt, alle 3 Jahre.',
    minAge: 35,
    intervalMonths: 36,
  ),
  Recommendation(
    key: 'haut',
    title: 'Hautkrebs-Screening',
    kind: RecommendationKind.checkup,
    detail: 'Alle 2 Jahre beim Haus- oder Hautarzt.',
    minAge: 35,
    intervalMonths: 24,
  ),
  Recommendation(
    key: 'chlamydien',
    title: 'Chlamydien-Test',
    kind: RecommendationKind.checkup,
    detail: 'Jährlich bis zum 25. Geburtstag.',
    minAge: 18,
    maxAge: 24,
    intervalMonths: 12,
    sex: Sex.female,
  ),
  Recommendation(
    key: 'gyn_jung',
    title: 'Gebärmutterhalskrebs-Vorsorge',
    kind: RecommendationKind.checkup,
    detail: 'Jährlicher Abstrich beim Frauenarzt (20 bis 34).',
    minAge: 20,
    maxAge: 34,
    intervalMonths: 12,
    sex: Sex.female,
  ),
  Recommendation(
    key: 'gyn',
    title: 'Gebärmutterhalskrebs-Vorsorge (Ko-Test)',
    kind: RecommendationKind.checkup,
    detail: 'Abstrich und HPV-Test alle 3 Jahre beim Frauenarzt.',
    minAge: 35,
    intervalMonths: 36,
    sex: Sex.female,
  ),
  Recommendation(
    key: 'brust',
    title: 'Brustuntersuchung',
    kind: RecommendationKind.checkup,
    detail: 'Jährliche Tastuntersuchung beim Frauenarzt.',
    minAge: 30,
    intervalMonths: 12,
    sex: Sex.female,
  ),
  Recommendation(
    key: 'mammographie',
    title: 'Mammographie-Screening',
    kind: RecommendationKind.checkup,
    detail: 'Alle 2 Jahre, die Einladung kommt per Post (50 bis 75).',
    minAge: 50,
    maxAge: 75,
    intervalMonths: 24,
    sex: Sex.female,
  ),
  Recommendation(
    key: 'prostata',
    title: 'Krebsvorsorge für Männer',
    kind: RecommendationKind.checkup,
    detail: 'Jährliche Untersuchung von Prostata und Genitalien.',
    minAge: 45,
    intervalMonths: 12,
    sex: Sex.male,
  ),
  Recommendation(
    key: 'darm',
    title: 'Darmkrebs-Vorsorge',
    kind: RecommendationKind.checkup,
    detail: 'Ab 50: Darmspiegelung alle 10 Jahre oder regelmäßiger Stuhltest.',
    minAge: 50,
    intervalMonths: 120,
  ),
  Recommendation(
    key: 'aorta',
    title: 'Ultraschall Bauchschlagader',
    kind: RecommendationKind.checkup,
    detail: 'Einmalig ab 65.',
    minAge: 65,
    sex: Sex.male,
  ),
  Recommendation(
    key: 'tetanus',
    title: 'Tetanus und Diphtherie',
    kind: RecommendationKind.vaccination,
    detail: 'Auffrischung alle 10 Jahre, einmal davon mit Keuchhusten.',
    minAge: 18,
    intervalMonths: 120,
  ),
  Recommendation(
    key: 'masern',
    title: 'Masern (MMR)',
    kind: RecommendationKind.vaccination,
    detail:
        'Einmalig, wenn nach 1970 geboren und nicht oder nur einmal geimpft.',
    minAge: 18,
  ),
  Recommendation(
    key: 'grippe',
    title: 'Grippe',
    kind: RecommendationKind.vaccination,
    detail: 'Jährlich im Herbst ab 60.',
    minAge: 60,
    intervalMonths: 12,
  ),
  Recommendation(
    key: 'corona',
    title: 'COVID-19',
    kind: RecommendationKind.vaccination,
    detail: 'Jährliche Auffrischung im Herbst ab 60.',
    minAge: 60,
    intervalMonths: 12,
  ),
  Recommendation(
    key: 'pneumokokken',
    title: 'Pneumokokken',
    kind: RecommendationKind.vaccination,
    detail: 'Einmalig ab 60.',
    minAge: 60,
  ),
  Recommendation(
    key: 'guertelrose',
    title: 'Gürtelrose',
    kind: RecommendationKind.vaccination,
    detail: 'Zwei Impfungen im Abstand von 2 bis 6 Monaten ab 60.',
    minAge: 60,
  ),
  Recommendation(
    key: 'rsv',
    title: 'RSV',
    kind: RecommendationKind.vaccination,
    detail: 'Einmalig ab 75.',
    minAge: 75,
  ),
];

int ageOn(DateTime birthday, DateTime day) {
  var age = day.year - birthday.year;
  if (day.month < birthday.month ||
      (day.month == birthday.month && day.day < birthday.day)) {
    age--;
  }
  return age;
}

enum RecStatus { due, ok, done }

typedef RecState = ({
  Recommendation rec,
  RecStatus status,
  DateTime? last,
  DateTime? next,
});

/// Wertet die Empfehlungen für eine Person aus. [lastDone] ordnet jedem
/// Schlüssel das letzte eingetragene Datum zu.
List<RecState> evaluate({
  required DateTime birthday,
  required Sex sex,
  required Map<String, DateTime> lastDone,
  required DateTime now,
}) {
  final age = ageOn(birthday, now);
  final result = <RecState>[];
  for (final r in recommendations) {
    if (!r.appliesTo(age, sex)) continue;
    final last = lastDone[r.key];
    if (last == null) {
      result.add((rec: r, status: RecStatus.due, last: null, next: null));
      continue;
    }
    if (r.intervalMonths == null) {
      result.add((rec: r, status: RecStatus.done, last: last, next: null));
      continue;
    }
    final next = DateTime(last.year, last.month + r.intervalMonths!, last.day);
    result.add((
      rec: r,
      status: next.isAfter(now) ? RecStatus.ok : RecStatus.due,
      last: last,
      next: next,
    ));
  }
  // Fällige zuerst, dann nach nächstem Termin.
  result.sort((a, b) {
    final c = a.status.index.compareTo(b.status.index);
    if (c != 0) return c;
    return (a.next ?? DateTime(9999)).compareTo(b.next ?? DateTime(9999));
  });
  return result;
}
