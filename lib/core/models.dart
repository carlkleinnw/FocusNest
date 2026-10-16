import 'planning.dart';
import 'journal.dart';

enum FocusStatus { idle, running, completed, cancelled }

class Plan {
  const Plan({
    required this.id,
    required this.title,
    required this.minutes,
    required this.time,
    this.category = '学习',
    this.date = '',
    this.goalId,
    this.milestoneId,
    this.units = 1,
    this.doneUnits = 0,
    this.completedAt,
    this.originalDate = '',
    this.rollovers = 0,
  });
  final String id, title, time, category;
  final int minutes;
  final String date;
  final String? goalId, milestoneId;
  final int units, doneUnits;
  final String? completedAt;
  final String originalDate;
  final int rollovers;
  bool get done => doneUnits >= units;
  Plan copyWith({
    String? date,
    int? doneUnits,
    String? completedAt,
    bool clearCompletion = false,
    String? originalDate,
    int? rollovers,
  }) => Plan(
    id: id,
    title: title,
    minutes: minutes,
    time: time,
    category: category,
    date: date ?? this.date,
    goalId: goalId,
    milestoneId: milestoneId,
    units: units,
    doneUnits: doneUnits ?? this.doneUnits,
    completedAt: clearCompletion ? null : completedAt ?? this.completedAt,
    originalDate: originalDate ?? this.originalDate,
    rollovers: rollovers ?? this.rollovers,
  );
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'time': time,
    'category': category,
    'date': date,
    'goalId': goalId ?? '',
    'milestoneId': milestoneId ?? '',
    'units': units,
    'doneUnits': doneUnits,
    'completedAt': completedAt ?? '',
    'originalDate': originalDate,
    'rollovers': rollovers,
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
    this.planId,
  });
  final String id, title;
  final int minutes;
  final DateTime startedAt;
  final FocusStatus status;
  final bool restart;
  final String? planId;
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
    planId: planId,
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
    this.planId,
  });
  final String id, title;
  final int minutes;
  final DateTime at;
  final bool completed, virtual;
  final String? planId;
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'at': at.toIso8601String(),
    'completed': completed,
    'virtual': virtual,
    'planId': planId ?? '',
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
    Set<String> allowedApps = const {},
    this.session,
    this.todayFed = false,
    this.adoptionReady = false,
    this.floating = false,
    this.message = '团子在等你一起开始新的一天。',
    this.achievement = 0,
    List<PetState> memorials = const [],
    List<Goal> goals = const [],
    List<Milestone> milestones = const [],
    Set<String> blockedApps = const {},
    this.appsInitialized = false,
    this.permissionPromptSeen = false,
    this.permissionEverReady = false,
    this.permissionRecoveryPromptSeen = false,
    this.protectionReady = false,
    this.storageError = '',
    this.dailyCapacity = 180,
    Workspace? workspace,
  }) : workspace = workspace ?? Workspace(),
       plans = List.unmodifiable(plans),
       records = List.unmodifiable(records),
       restDates = Set.unmodifiable(restDates),
       allowedApps = Set.unmodifiable(allowedApps),
       memorials = List.unmodifiable(memorials),
       goals = List.unmodifiable(goals),
       milestones = List.unmodifiable(milestones),
       blockedApps = Set.unmodifiable(blockedApps);
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
  final List<Goal> goals;
  final List<Milestone> milestones;
  final Set<String> blockedApps;
  final bool appsInitialized, protectionReady, permissionPromptSeen;
  final bool permissionEverReady, permissionRecoveryPromptSeen;
  final String storageError;
  final int dailyCapacity;
  final Workspace workspace;
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
    List<Goal>? goals,
    List<Milestone>? milestones,
    Set<String>? blockedApps,
    bool? appsInitialized,
    bool? permissionPromptSeen,
    bool? permissionEverReady,
    bool? permissionRecoveryPromptSeen,
    bool? protectionReady,
    String? storageError,
    int? dailyCapacity,
    Workspace? workspace,
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
    goals: goals ?? this.goals,
    milestones: milestones ?? this.milestones,
    blockedApps: blockedApps ?? this.blockedApps,
    appsInitialized: appsInitialized ?? this.appsInitialized,
    permissionPromptSeen: permissionPromptSeen ?? this.permissionPromptSeen,
    permissionEverReady: permissionEverReady ?? this.permissionEverReady,
    permissionRecoveryPromptSeen:
        permissionRecoveryPromptSeen ?? this.permissionRecoveryPromptSeen,
    protectionReady: protectionReady ?? this.protectionReady,
    storageError: storageError ?? this.storageError,
    dailyCapacity: dailyCapacity ?? this.dailyCapacity,
    workspace: workspace ?? this.workspace,
  );
}

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String shortDate(DateTime date) => '${date.month}月${date.day}日';
String timerLabel(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
