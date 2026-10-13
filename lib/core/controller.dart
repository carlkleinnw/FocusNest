import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/demo_adapters.dart';
import '../data/android_adapters.dart';
import 'models.dart';
import 'planning.dart';
import 'ports.dart';

final clockProvider = Provider<ClockPort>((ref) => DemoClock());
final repositoryProvider = Provider<DataRepository>(
  (ref) => MemoryRepository(ref.read(clockProvider)),
);
final deviceProvider = Provider<DevicePort>((ref) => SimulatedDevice());
final intelligenceProvider = Provider<IntelligencePort>(
  (ref) => DisabledIntelligence(),
);
final eventsProvider = Provider<EventPort>((ref) {
  final events = DemoEvents();
  ref.onDispose(events.dispose);
  return events;
});
final appProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);
final contextProvider = Provider<ContextPort>(
  (ref) => ref.read(appProvider.notifier),
);
final actionsProvider = Provider<ActionPort>(
  (ref) => ref.read(appProvider.notifier),
);
final appsProvider = FutureProvider<List<InstalledApp>>((ref) async {
  final apps = await ref.read(deviceProvider).apps();
  ref.read(appProvider.notifier).initializeApps(apps);
  return apps;
});

class AppController extends Notifier<AppState>
    implements ContextPort, ActionPort {
  bool _busy = false, _ticking = false, _virtual = false;
  Future<void>? _tickPending;
  DateTime? _lastPermissionPoll;
  ClockPort get clock => ref.read(clockProvider);
  bool get simulated => ref.read(deviceProvider).simulated;
  @override
  AppState build() {
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(tick()),
    );
    ref.onDispose(timer.cancel);
    Future<void>.microtask(() async {
      await tick();
    });
    final loaded = ref.read(repositoryProvider).load();
    return loaded.copyWith(
      plans: loaded.plans
          .map((p) => p.date.isEmpty ? p.copyWith(date: loaded.dayKey) : p)
          .toList(),
    );
  }

  void _commit(AppState next, [String? event, bool persist = true]) {
    state = next;
    if (persist) ref.read(repositoryProvider).save(next);
    if (event != null) {
      ref
          .read(eventsProvider)
          .publish(
            AppEvent(event, next.now, {
              'sessionId': next.session?.id,
              'petGeneration': next.pet.generation,
            }),
          );
    }
  }

  OperationResult _result(bool ok, String code, String message) =>
      OperationResult(ok, code, message);
  OperationResult get _locked => _result(false, 'FOCUS_ACTIVE', '专注结束后再调整');
  Future<void> tick() async {
    final previous = _tickPending;
    if (previous != null) await previous;
    if (_busy) return;
    final pending = _tickBody();
    _tickPending = pending;
    try {
      await pending;
    } finally {
      if (identical(_tickPending, pending)) _tickPending = null;
    }
  }

  Future<void> _tickBody() async {
    if (_ticking || _busy) return;
    _ticking = true;
    try {
      final now = clock.now();
      while (dateKey(now).compareTo(state.dayKey) > 0) {
        final midnight = DateTime(
          state.now.year,
          state.now.month,
          state.now.day + 1,
        );
        if (state.focusing && !state.session!.deadline.isAfter(midnight)) {
          _commit(state.copyWith(now: state.session!.deadline), null, false);
          await _complete();
          if (state.focusing) return;
        }
        _settleDay(midnight);
      }
      _commit(state.copyWith(now: now), null, false);
      if (state.focusing && !now.isBefore(state.session!.deadline)) {
        await _complete();
      }
      if (_lastPermissionPoll == null ||
          now.difference(_lastPermissionPoll!).inSeconds >= 3) {
        _lastPermissionPoll = now;
        final ready = await ref.read(deviceProvider).ready();
        _commit(state.copyWith(protectionReady: ready), null, false);
      }
      final repo = ref.read(repositoryProvider);
      if (repo is AndroidRepository &&
          (repo.error ?? '') != state.storageError) {
        _commit(state.copyWith(storageError: repo.error ?? ''), null, false);
      }
    } finally {
      _ticking = false;
    }
  }

  void _settleDay(DateTime nextDay) {
    final hungry = state.pet.dead || state.resting || state.todayFed
        ? state.pet.hungryDays
        : state.pet.hungryDays + 1;
    final pet = state.pet.copyWith(
      hungryDays: hungry,
      companionDays: state.pet.companionDays + (state.pet.dead ? 0 : 1),
    );
    _commit(
      state.copyWith(
        now: nextDay,
        pet: pet,
        todayFed: false,
        message: pet.dead ? '${pet.name}已经离开，过去的努力会留下记录。' : '新的一天开始了。',
      ),
      pet.dead && !state.pet.dead ? 'pet.died' : 'day.advanced',
    );
  }

  @override
  OperationResult upsertPlan(Plan plan) {
    if (_busy || state.focusing) return _locked;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(plan.id) ||
        plan.title.trim().isEmpty ||
        plan.title.length > 60 ||
        plan.minutes < 30 ||
        plan.minutes > 180 ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(plan.time) ||
        plan.units < 1 ||
        plan.doneUnits < 0 ||
        plan.doneUnits > plan.units) {
      return _result(false, 'INVALID_PLAN', '请输入具体任务、30—180分钟时长和有效进度');
    }
    final day = plan.date.isEmpty ? state.dayKey : plan.date;
    final parsed = DateTime.tryParse(day);
    if (parsed == null ||
        dateKey(parsed) != day ||
        day.compareTo(state.dayKey) < 0) {
      return _result(false, 'INVALID_DATE', '请选择今天或未来日期');
    }
    final goal = state.goals.where((g) => g.id == plan.goalId).firstOrNull;
    final milestone = state.milestones
        .where((m) => m.id == plan.milestoneId)
        .firstOrNull;
    if (plan.goalId != null && goal == null ||
        plan.milestoneId != null &&
            (milestone == null || milestone.goalId != plan.goalId)) {
      return _result(false, 'INVALID_LINK', '目标或阶段不存在');
    }
    final others = state.plans.where((p) => p.id != plan.id);
    final minutes =
        others
            .where((p) => (p.date.isEmpty ? state.dayKey : p.date) == day)
            .fold(0, (sum, p) => sum + p.minutes) +
        plan.minutes;
    if (minutes > state.dailyCapacity) {
      return _result(
        false,
        'CAPACITY_EXCEEDED',
        '这一天已超出${state.dailyCapacity}分钟可用时间，请拆分或调整',
      );
    }
    if (goal != null) {
      final assigned =
          others
              .where((p) => p.goalId == goal.id)
              .fold(0, (sum, p) => sum + p.units) +
          plan.units;
      if (assigned > goal.totalUnits || day.compareTo(goal.deadline) > 0) {
        return _result(false, 'GOAL_EXCEEDED', '任务数量或日期超出长期目标');
      }
    }
    if (milestone != null) {
      final assigned =
          others
              .where((p) => p.milestoneId == milestone.id)
              .fold(0, (sum, p) => sum + p.units) +
          plan.units;
      if (assigned > milestone.units || day.compareTo(milestone.deadline) > 0) {
        return _result(false, 'STAGE_EXCEEDED', '任务数量或日期超出阶段目标');
      }
    }
    final saved = plan.copyWith(date: day);
    final plans = [...state.plans];
    final index = plans.indexWhere((p) => p.id == plan.id);
    if (index < 0) {
      plans.add(saved);
    } else {
      plans[index] = saved;
    }
    _commit(state.copyWith(plans: plans), 'plan.changed');
    return _result(true, 'OK', '计划已保存');
  }

  void removePlan(String id) {
    if (!_busy && !state.focusing) {
      _commit(
        state.copyWith(plans: state.plans.where((p) => p.id != id).toList()),
        'plan.deleted',
      );
    }
  }

  OperationResult setTaskProgress(String id, int units) {
    if (_busy || state.focusing) return _locked;
    final task = state.plans.where((p) => p.id == id).firstOrNull;
    if (task == null || units < 0 || units > task.units) {
      return _result(false, 'INVALID_PROGRESS', '进度超出任务范围');
    }
    _commit(
      state.copyWith(
        plans: state.plans
            .map((p) => p.id == id ? p.copyWith(doneUnits: units) : p)
            .toList(),
      ),
      'task.progress',
    );
    return _result(true, 'OK', '任务进度已更新；喂食仍以完整专注为准');
  }

  @override
  OperationResult upsertGoal(Goal goal) {
    if (_busy || state.focusing) return _locked;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(goal.id) ||
        goal.title.trim().isEmpty ||
        goal.title.length > 60 ||
        goal.totalUnits < 1 ||
        goal.totalUnits > 100000 ||
        goal.unit.trim().isEmpty ||
        goal.unit.length > 8 ||
        DateTime.tryParse(goal.deadline) == null ||
        dateKey(DateTime.parse(goal.deadline)) != goal.deadline ||
        goal.deadline.compareTo(state.dayKey) < 0) {
      return _result(false, 'INVALID_GOAL', '请输入目标、未来截止日期和有效任务数量');
    }
    final allocated = state.plans
        .where((p) => p.goalId == goal.id)
        .fold(0, (sum, p) => sum + p.units);
    final stages = state.milestones.where((m) => m.goalId == goal.id);
    if (allocated > goal.totalUnits ||
        stages.fold(0, (sum, m) => sum + m.units) > goal.totalUnits ||
        stages.any((m) => m.deadline.compareTo(goal.deadline) > 0) ||
        state.plans.any(
          (p) => p.goalId == goal.id && p.date.compareTo(goal.deadline) > 0,
        )) {
      return _result(false, 'GOAL_HAS_WORK', '已有任务或阶段超出新的目标范围');
    }
    _commit(
      state.copyWith(
        goals: [...state.goals.where((g) => g.id != goal.id), goal],
      ),
      'goal.changed',
    );
    return _result(true, 'OK', '长期目标已保存');
  }

  @override
  OperationResult upsertMilestone(Milestone milestone) {
    if (_busy || state.focusing) return _locked;
    final goal = state.goals.where((g) => g.id == milestone.goalId).firstOrNull;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(milestone.id) ||
        goal == null ||
        milestone.title.trim().isEmpty ||
        milestone.title.length > 60 ||
        milestone.units < 1 ||
        DateTime.tryParse(milestone.deadline) == null ||
        dateKey(DateTime.parse(milestone.deadline)) != milestone.deadline ||
        milestone.deadline.compareTo(state.dayKey) < 0 ||
        milestone.deadline.compareTo(goal.deadline) > 0) {
      return _result(false, 'INVALID_STAGE', '请填写有效阶段，截止日期应在目标期限内');
    }
    final other = state.milestones
        .where((m) => m.goalId == goal.id && m.id != milestone.id)
        .fold(0, (sum, m) => sum + m.units);
    final assigned = state.plans
        .where((p) => p.milestoneId == milestone.id)
        .fold(0, (sum, p) => sum + p.units);
    if (other + milestone.units > goal.totalUnits ||
        assigned > milestone.units ||
        state.plans.any(
          (p) =>
              p.milestoneId == milestone.id &&
              (p.goalId != milestone.goalId ||
                  p.date.compareTo(milestone.deadline) > 0),
        )) {
      return _result(false, 'STAGE_EXCEEDED', '阶段总量超出目标或小于已安排任务');
    }
    _commit(
      state.copyWith(
        milestones: [
          ...state.milestones.where((m) => m.id != milestone.id),
          milestone,
        ],
      ),
      'stage.changed',
    );
    return _result(true, 'OK', '阶段目标已保存');
  }

  OperationResult setCapacity(int minutes) {
    if (state.focusing || _busy) return _locked;
    if (minutes < 30 || minutes > 720) {
      return _result(false, 'INVALID_CAPACITY', '每天可用时间应为30—720分钟');
    }
    final scheduled = <String, int>{};
    for (final p in state.plans.where(
      (p) => p.date.compareTo(state.dayKey) >= 0,
    )) {
      scheduled[p.date] = (scheduled[p.date] ?? 0) + p.minutes;
    }
    if (scheduled.values.any((total) => total > minutes)) {
      return _result(false, 'CAPACITY_EXCEEDED', '已有日期超出这个时间，请先调整计划');
    }
    _commit(state.copyWith(dailyCapacity: minutes), 'capacity.changed');
    return _result(true, 'OK', '每日可用时间已更新');
  }

  Future<OperationResult> start(Plan plan, {bool restart = false}) async {
    if (_busy || state.focusing) return _locked;
    await tick();
    if (_busy || state.focusing) return _locked;
    if (plan.title.trim().isEmpty ||
        plan.title.length > 60 ||
        plan.minutes < 30 ||
        plan.minutes > 180) {
      return _result(false, 'INVALID_DURATION', '每次至少30分钟');
    }
    if (state.pet.dead && !restart ||
        restart && (!state.pet.dead || state.adoptionReady)) {
      return _result(false, 'RESTART_UNAVAILABLE', '请从重新领养页开始');
    }
    if (!state.appsInitialized) {
      try {
        initializeApps(await ref.read(deviceProvider).apps());
      } catch (_) {
        return _result(false, 'APPS_UNAVAILABLE', '请先读取并确认应用名单');
      }
      if (_busy || state.focusing) return _locked;
    }
    final savedPlan = state.plans.where((p) => p.id == plan.id).firstOrNull;
    if (!restart &&
        savedPlan != null &&
        (savedPlan.done ||
            (savedPlan.date.isNotEmpty &&
                savedPlan.date != dateKey(clock.now())))) {
      return _result(false, 'TASK_UNAVAILABLE', '请选择今天尚未完成的任务');
    }
    _busy = true;
    try {
      final now = clock.now();
      final session = FocusSession(
        id: 's${now.microsecondsSinceEpoch}',
        title: plan.title,
        minutes: plan.minutes,
        startedAt: now,
        restart: restart,
        planId: plan.id,
      );
      final next = state.copyWith(
        now: now,
        session: session,
        message: '你安心专注，${state.pet.name}会安静陪着你。',
      );
      final repo = ref.read(repositoryProvider);
      if (repo is AndroidRepository) {
        await repo.flush();
        if (repo.error != null) {
          return _result(false, 'STORAGE_ERROR', repo.error!);
        }
      }
      final result = await ref
          .read(deviceProvider)
          .applyRestrictions(state.blockedApps, session, next);
      if (!result.ok) return result;
      _virtual = false;
      _commit(next, 'focus.started');
      return _result(true, 'OK', simulated ? '专注计时已开始（应用限制为模拟）' : '专注保护已开始');
    } finally {
      _busy = false;
    }
  }

  Future<void> _complete() async {
    final current = state.session!;
    final newPet = current.restart || state.pet.dead;
    final record = FocusRecord(
      id: current.id,
      title: current.title,
      minutes: current.minutes,
      at: current.deadline,
      completed: true,
      virtual: _virtual,
      planId: current.planId,
    );
    final next = state.copyWith(
      session: current.finish(FocusStatus.completed),
      pet: newPet
          ? state.pet
          : state.pet.copyWith(hungryDays: 0, meals: state.pet.meals + 1),
      records: [record, ...state.records],
      todayFed: newPet ? state.todayFed : true,
      adoptionReady: newPet,
      achievement: state.achievement + 1,
      message: newPet ? '专注完成，可以迎接新伙伴了。' : '${state.pet.name}吃饱啦，谢谢你的坚持！',
    );
    _busy = true;
    try {
      final repo = ref.read(repositoryProvider);
      if (repo is AndroidRepository) await repo.flush();
      final result = await ref.read(deviceProvider).releaseRestrictions(next);
      if (!result.ok) {
        _commit(state.copyWith(message: result.message), null, false);
        return;
      }
      _commit(next, 'focus.completed');
    } finally {
      _busy = false;
    }
  }

  Future<OperationResult> cancelFocus() async {
    if (_busy || !state.focusing) {
      return _result(false, 'NO_SESSION', '没有可结束的专注');
    }
    if (!clock.now().isBefore(state.session!.deadline)) {
      await tick();
      return _result(
        !state.focusing,
        'DEADLINE_REACHED',
        state.focusing ? '正在结算，请稍候' : '专注已到时，按完整完成结算',
      );
    }
    _busy = true;
    try {
      final current = state.session!;
      final next = state.copyWith(
        session: current.finish(FocusStatus.cancelled),
        records: [
          FocusRecord(
            id: current.id,
            title: current.title,
            minutes: clock
                .now()
                .difference(current.startedAt)
                .inMinutes
                .clamp(0, current.minutes),
            at: clock.now(),
            completed: false,
            virtual: _virtual,
            planId: current.planId,
          ),
          ...state.records,
        ],
        message: '这次提前结束了。准备好后再开始。',
      );
      final repo = ref.read(repositoryProvider);
      if (repo is AndroidRepository) await repo.flush();
      final result = await ref.read(deviceProvider).releaseRestrictions(next);
      if (!result.ok) return result;
      _commit(next, 'focus.cancelled');
      return _result(true, 'OK', '已结束，本次不喂食');
    } finally {
      _busy = false;
    }
  }

  void dismissSession() {
    if (!state.focusing && !_busy) _commit(state.copyWith(clearSession: true));
  }

  @override
  OperationResult setRest(DateTime day, bool enabled) {
    if (state.focusing || _busy) return _locked;
    if (dateKey(day).compareTo(state.dayKey) <= 0) {
      return _result(false, 'PAST_DATE', '休息日只能提前安排');
    }
    final dates = {...state.restDates};
    if (enabled) {
      dates.add(dateKey(day));
    } else {
      dates.remove(dateKey(day));
    }
    _commit(state.copyWith(restDates: dates), 'rest.changed');
    return _result(true, 'OK', '休息安排已更新');
  }

  OperationResult toggleRest(DateTime day) =>
      setRest(day, !state.restDates.contains(dateKey(day)));
  void initializeApps(List<InstalledApp> apps) {
    if (state.appsInitialized) return;
    _commit(
      state.copyWith(
        blockedApps: apps
            .where((a) => a.recommendedBlocked && !a.protected)
            .map((a) => a.package)
            .toSet(),
        appsInitialized: true,
      ),
      'apps.initialized',
    );
  }

  void toggleInstalledApp(InstalledApp app) {
    if (state.focusing || _busy || app.protected) return;
    final blocked = {...state.blockedApps};
    if (!blocked.add(app.package)) blocked.remove(app.package);
    _commit(state.copyWith(blockedApps: blocked), 'allowlist.changed');
  }

  void interact(String action) {
    if (state.focusing || state.pet.dead) return;
    _commit(
      state.copyWith(
        message: switch (action) {
          'ball' => '${state.pet.name}追着小球跑了起来！',
          'rest' => '${state.pet.name}伸了个懒腰。',
          'move' => '${state.pet.name}向你走过来了。',
          _ => '${state.pet.name}开心地蹭了蹭你的手。',
        },
      ),
      'pet.interacted',
    );
  }

  void toggleFloating() => _commit(state.copyWith(floating: !state.floating));
  OperationResult adopt(String name, int colorIndex) {
    if (!state.pet.dead || !state.adoptionReady || state.focusing || _busy) {
      return _result(false, 'ADOPTION_LOCKED', '先完成30分钟重启专注');
    }
    if (name.trim().isEmpty || name.length > 12) {
      return _result(false, 'INVALID_NAME', '名字需要1—12个字');
    }
    final pet = PetState(
      name: name.trim(),
      meals: 1,
      companionDays: 1,
      generation: state.pet.generation + 1,
      colorIndex: colorIndex,
      species: colorIndex == 1 ? '奶牛猫' : '橘猫',
    );
    _commit(
      state.copyWith(
        pet: pet,
        adoptionReady: false,
        todayFed: true,
        memorials: [...state.memorials, state.pet],
        clearSession: true,
        message: '${pet.name}来到小屋啦，第一餐已经准备好了！',
      ),
      'pet.adopted',
    );
    return _result(true, 'OK', '欢迎新伙伴');
  }

  Future<OperationResult> advanceMinutes(int minutes) async {
    if (clock is! DemoClock || !state.focusing || minutes <= 0) {
      return _result(false, 'DEMO_UNAVAILABLE', '快进只用于网页模拟专注');
    }
    _virtual = true;
    (clock as DemoClock).advance(Duration(minutes: minutes));
    await tick();
    return _result(true, 'OK', '已快进模拟时间');
  }

  Future<OperationResult> advanceDay() async {
    if (clock is! DemoClock || state.focusing) {
      return _result(false, 'DEMO_UNAVAILABLE', '只有网页演示可以推进日期');
    }
    (clock as DemoClock).advance(const Duration(days: 1));
    await tick();
    return _result(true, 'OK', '已推进到${shortDate(state.now)}');
  }

  void resetDemo() {
    final repo = ref.read(repositoryProvider);
    if (clock is! DemoClock || repo is! MemoryRepository || state.focusing) {
      return;
    }
    (clock as DemoClock).reset();
    repo.reset();
    _virtual = false;
    _lastPermissionPoll = null;
    _commit(repo.load(), 'demo.reset');
    ref.invalidate(appsProvider);
  }

  @override
  Map<String, Object?> readContext() => {
    'version': 2,
    'simulated': simulated,
    'date': state.dayKey,
    'plans': state.plans.map((p) => p.toJson()).toList(),
    'goals': state.goals.map((g) => g.toJson()).toList(),
    'milestones': state.milestones.map((m) => m.toJson()).toList(),
    'records': state.records.take(100).map((r) => r.toJson()).toList(),
    'focus': {'running': state.focusing, 'title': state.session?.title},
    'pet': {
      'name': state.pet.name,
      'hungryDays': state.pet.hungryDays,
      'dead': state.pet.dead,
    },
    'restDates': state.restDates.toList(),
    'blockedApps': state.blockedApps.toList(),
    'rules': {'minimumMinutes': 30, 'deathAfterDays': 7},
  };
}
