enum FocusStatus { idle, running, completed, cancelled }

class Plan {
  const Plan({
    required this.id,
    required this.title,
    required this.minutes,
    required this.time,
    this.category = '学习',
  });
  final String id, title, time, category;
  final int minutes;
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'time': time,
    'category': category,
  };
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.title,
    required this.minutes,
    required this.startedAt,
    this.status = FocusStatus.running,
    this.restart = false,
  });
  final String id, title;
  final int minutes;
  final DateTime startedAt;
  final FocusStatus status;
  final bool restart;
  DateTime get deadline => startedAt.add(Duration(minutes: minutes));
  int remainingSeconds(DateTime now) =>
      deadline.difference(now).inSeconds.clamp(0, minutes * 60);
  FocusSession finish(FocusStatus result) => FocusSession(
    id: id,
    title: title,
    minutes: minutes,
    startedAt: startedAt,
    status: result,
    restart: restart,
  );
}

class FocusRecord {
  const FocusRecord({
    required this.id,
    required this.title,
    required this.minutes,
    required this.at,
    required this.completed,
    this.virtual = false,
  });
  final String id, title;
  final int minutes;
  final DateTime at;
  final bool completed, virtual;
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'at': at.toIso8601String(),
    'completed': completed,
    'virtual': virtual,
  };
}

class PetState {
  const PetState({
    this.name = '团子',
    this.species = '橘猫',
    this.hungryDays = 0,
    this.companionDays = 12,
    this.meals = 8,
    this.generation = 1,
    this.colorIndex = 0,
  });
  final String name, species;
  final int hungryDays, companionDays, meals, generation, colorIndex;
  bool get dead => hungryDays >= 7;
  double get energy => ((7 - hungryDays) / 7).clamp(0.0, 1.0);
  String get condition => dead
      ? '已离开'
      : hungryDays >= 5
      ? '非常虚弱'
      : hungryDays >= 3
      ? '有些消瘦'
      : hungryDays > 0
      ? '有点饿了'
      : '健康 · 活泼';
  PetState copyWith({int? hungryDays, int? companionDays, int? meals}) =>
      PetState(
        name: name,
        species: species,
        hungryDays: hungryDays ?? this.hungryDays,
        companionDays: companionDays ?? this.companionDays,
        meals: meals ?? this.meals,
        generation: generation,
        colorIndex: colorIndex,
      );
}

class AppState {
  AppState({
    required this.now,
    required this.pet,
    required List<Plan> plans,
    required List<FocusRecord> records,
    Set<String> restDates = const {},
    Set<String> allowedApps = const {'课程平台', '词典', '电话'},
    this.session,
    this.todayFed = false,
    this.adoptionReady = false,
    this.floating = false,
    this.message = '团子在等你一起开始新的一天。',
    this.achievement = 0,
    List<PetState> memorials = const [],
  }) : plans = List.unmodifiable(plans),
       records = List.unmodifiable(records),
       restDates = Set.unmodifiable(restDates),
       allowedApps = Set.unmodifiable(allowedApps),
       memorials = List.unmodifiable(memorials);
  final DateTime now;
  final PetState pet;
  final List<Plan> plans;
  final List<FocusRecord> records;
  final List<PetState> memorials;
  final Set<String> restDates, allowedApps;
  final FocusSession? session;
  final bool todayFed, adoptionReady, floating;
  final String message;
  final int achievement;
  bool get focusing => session?.status == FocusStatus.running;
  String get dayKey => dateKey(now);
  bool get resting => restDates.contains(dayKey);
  AppState copyWith({
    DateTime? now,
    PetState? pet,
    List<Plan>? plans,
    List<FocusRecord>? records,
    Set<String>? restDates,
    Set<String>? allowedApps,
    FocusSession? session,
    bool clearSession = false,
    bool? todayFed,
    bool? adoptionReady,
    bool? floating,
    String? message,
    int? achievement,
    List<PetState>? memorials,
  }) => AppState(
    now: now ?? this.now,
    pet: pet ?? this.pet,
    plans: plans ?? this.plans,
    records: records ?? this.records,
    restDates: restDates ?? this.restDates,
    allowedApps: allowedApps ?? this.allowedApps,
    session: clearSession ? null : session ?? this.session,
    todayFed: todayFed ?? this.todayFed,
    adoptionReady: adoptionReady ?? this.adoptionReady,
    floating: floating ?? this.floating,
    message: message ?? this.message,
    achievement: achievement ?? this.achievement,
    memorials: memorials ?? this.memorials,
  );
}

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String shortDate(DateTime date) => '${date.month}月${date.day}日';
String timerLabel(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
