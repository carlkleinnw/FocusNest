import '../core/models.dart';
import '../core/planning.dart';

Map<String, Object?> encodeSnapshot(AppState s) {
  Map<String, Object> pet(PetState p) => {
    'name': p.name,
    'species': p.species,
    'hungryDays': p.hungryDays,
    'companionDays': p.companionDays,
    'meals': p.meals,
    'generation': p.generation,
    'colorIndex': p.colorIndex,
  };
  final session = s.session;
  return {
    'version': 2,
    'now': s.now.toIso8601String(),
    'pet': pet(s.pet),
    'plans': s.plans.map((p) => p.toJson()).toList(),
    'records': s.records.map((r) => r.toJson()).toList(),
    'memorials': s.memorials.map(pet).toList(),
    'goals': s.goals.map((g) => g.toJson()).toList(),
    'milestones': s.milestones.map((m) => m.toJson()).toList(),
    'restDates': s.restDates.toList(),
    'allowedApps': s.allowedApps.toList(),
    'blockedApps': s.blockedApps.toList(),
    'appsInitialized': s.appsInitialized,
    'todayFed': s.todayFed,
    'adoptionReady': s.adoptionReady,
    'floating': s.floating,
    'message': s.message,
    'achievement': s.achievement,
    'dailyCapacity': s.dailyCapacity,
    'session': session == null
        ? null
        : {
            'id': session.id,
            'title': session.title,
            'minutes': session.minutes,
            'startedAt': session.startedAt.toIso8601String(),
            'status': session.status.name,
            'restart': session.restart,
            'planId': session.planId,
          },
  };
}

AppState decodeSnapshot(Map<String, dynamic> j) {
  if (j['version'] != 2) throw const FormatException('不支持的本地数据版本');
  Map<String, dynamic> obj(Object? x) => Map<String, dynamic>.from(x as Map);
  List<Map<String, dynamic>> list(String k) =>
      (j[k] as List? ?? []).map(obj).toList();
  Set<String> set(String k) => Set<String>.from(j[k] as List? ?? []);
  PetState pet(Map<String, dynamic> p) => PetState(
    name: p['name'] as String,
    species: p['species'] as String,
    hungryDays: p['hungryDays'] as int,
    companionDays: p['companionDays'] as int,
    meals: p['meals'] as int,
    generation: p['generation'] as int,
    colorIndex: p['colorIndex'] as int,
  );
  final p = j['session'] == null ? null : obj(j['session']);
  return AppState(
    now: DateTime.parse(j['now'] as String),
    pet: pet(obj(j['pet'])),
    plans: list('plans')
        .map(
          (p) => Plan(
            id: p['id'] as String,
            title: p['title'] as String,
            minutes: p['minutes'] as int,
            time: p['time'] as String,
            category: p['category'] as String,
            date: p['date'] as String? ?? '',
            goalId: (p['goalId'] as String? ?? '').isEmpty
                ? null
                : p['goalId'] as String,
            milestoneId: (p['milestoneId'] as String? ?? '').isEmpty
                ? null
                : p['milestoneId'] as String,
            units: p['units'] as int? ?? 1,
            doneUnits: p['doneUnits'] as int? ?? 0,
          ),
        )
        .toList(),
    records: list('records')
        .map(
          (r) => FocusRecord(
            id: r['id'] as String,
            title: r['title'] as String,
            minutes: r['minutes'] as int,
            at: DateTime.parse(r['at'] as String),
            completed: r['completed'] as bool,
            virtual: r['virtual'] as bool,
            planId: r['planId'] as String?,
          ),
        )
        .toList(),
    goals: list('goals').map(Goal.fromJson).toList(),
    milestones: list('milestones').map(Milestone.fromJson).toList(),
    memorials: list('memorials').map(pet).toList(),
    restDates: set('restDates'),
    allowedApps: set('allowedApps'),
    blockedApps: set('blockedApps'),
    appsInitialized: j['appsInitialized'] as bool? ?? false,
    todayFed: j['todayFed'] as bool,
    adoptionReady: j['adoptionReady'] as bool,
    floating: j['floating'] as bool,
    message: j['message'] as String,
    achievement: j['achievement'] as int,
    dailyCapacity: j['dailyCapacity'] as int? ?? 180,
    session: p == null
        ? null
        : FocusSession(
            id: p['id'] as String,
            title: p['title'] as String,
            minutes: p['minutes'] as int,
            startedAt: DateTime.parse(p['startedAt'] as String),
            status: FocusStatus.values.byName(p['status'] as String),
            restart: p['restart'] as bool,
            planId: p['planId'] as String?,
          ),
  );
}
