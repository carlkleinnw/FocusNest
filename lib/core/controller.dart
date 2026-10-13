import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/demo_adapters.dart';
import 'models.dart';
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
// Riverpod dependency injection: https://riverpod.dev/docs/how_to/testing
final appProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);
final contextProvider = Provider<ContextPort>(
  (ref) => ref.read(appProvider.notifier),
);
final actionsProvider = Provider<ActionPort>(
  (ref) => ref.read(appProvider.notifier),
);

class AppController extends Notifier<AppState>
    implements ContextPort, ActionPort {
  Timer? _timer;
  int _sequence = 0;
  bool _sessionFastForwarded = false;
  ClockPort get clock => ref.read(clockProvider);
  @override
  AppState build() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    ref.onDispose(() => _timer?.cancel());
    return ref.read(repositoryProvider).load();
  }

  void _commit(AppState next, [String? event]) {
    state = next;
    ref.read(repositoryProvider).save(next);
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
  void tick() {
    final now = clock.now();
    _commit(state.copyWith(now: now));
    if (state.focusing && !now.isBefore(state.session!.deadline)) _complete();
  }

  @override
  OperationResult upsertPlan(Plan plan) {
    if (plan.title.trim().isEmpty ||
        plan.title.trim().length > 60 ||
        plan.minutes < 30 ||
        plan.minutes > 180 ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(plan.time)) {
      return _result(false, 'INVALID_PLAN', '请输入1—60字任务、30—180分钟时长及有效时间');
    }
    if (state.focusing) return _result(false, 'FOCUS_ACTIVE', '专注结束后再调整计划');
    final plans = [...state.plans];
    final index = plans.indexWhere((p) => p.id == plan.id);
    if (index < 0) {
      plans.add(plan);
    } else {
      plans[index] = plan;
    }
    _commit(state.copyWith(plans: plans), 'plan.changed');
    return _result(true, 'OK', '计划已保存');
  }

  void removePlan(String id) {
    if (!state.focusing) {
      _commit(
        state.copyWith(plans: state.plans.where((p) => p.id != id).toList()),
        'plan.deleted',
      );
    }
  }

  OperationResult start(Plan plan, {bool restart = false}) {
    if (state.focusing) return _result(false, 'FOCUS_ACTIVE', '当前已有专注会话');
    if (plan.minutes < 30 || plan.minutes > 180) {
      return _result(false, 'INVALID_DURATION', '每次专注至少30分钟');
    }
    if (state.pet.dead && !restart) {
      return _result(false, 'PET_DEAD', '请先从领养页开始重启专注');
    }
    if (restart && (!state.pet.dead || state.adoptionReady)) {
      return _result(false, 'RESTART_UNAVAILABLE', '当前不需要重启专注');
    }
    final device = ref
        .read(deviceProvider)
        .applyRestrictions(state.allowedApps);
    if (!device.ok) return device;
    _sessionFastForwarded = false;
    _commit(
      state.copyWith(
        now: clock.now(),
        session: FocusSession(
          id: 's${++_sequence}',
          title: plan.title,
          minutes: plan.minutes,
          startedAt: clock.now(),
          restart: restart,
        ),
        message: '你安心专注，${state.pet.name}会安静陪着你。',
      ),
      'focus.started',
    );
    return _result(true, 'OK', '专注已开始');
  }

  void _complete() {
    final current = state.session!;
    final result = ref.read(deviceProvider).releaseRestrictions();
    if (!result.ok) return;
    final record = FocusRecord(
      id: current.id,
      title: current.title,
      minutes: current.minutes,
      at: state.now,
      completed: true,
      virtual: _sessionFastForwarded,
    );
    _commit(
      state.copyWith(
        session: current.finish(FocusStatus.completed),
        pet: current.restart
            ? state.pet
            : state.pet.copyWith(hungryDays: 0, meals: state.pet.meals + 1),
        records: [record, ...state.records],
        todayFed: current.restart ? state.todayFed : true,
        adoptionReady: current.restart,
        achievement: state.achievement + 1,
        message: current.restart
            ? '重启专注完成，你可以迎接新伙伴了。'
            : '${state.pet.name}吃饱啦，谢谢你的坚持！',
      ),
      'focus.completed',
    );
  }

  OperationResult cancelFocus() {
    if (!state.focusing) return _result(false, 'NO_SESSION', '没有进行中的专注');
    final session = state.session!;
    ref.read(deviceProvider).releaseRestrictions();
    final elapsed = state.now
        .difference(session.startedAt)
        .inMinutes
        .clamp(0, session.minutes);
    _commit(
      state.copyWith(
        session: session.finish(FocusStatus.cancelled),
        records: [
          FocusRecord(
            id: session.id,
            title: session.title,
            minutes: elapsed,
            at: state.now,
            completed: false,
            virtual: _sessionFastForwarded,
          ),
          ...state.records,
        ],
        message: '这次提前结束了。准备好后，再从一个小任务开始。',
      ),
      'focus.cancelled',
    );
    return _result(true, 'OK', '已结束专注，本次不喂食');
  }

  void dismissSession() {
    if (!state.focusing) _commit(state.copyWith(clearSession: true));
  }

  @override
  OperationResult setRest(DateTime day, bool enabled) {
    if (state.focusing) return _result(false, 'FOCUS_ACTIVE', '专注结束后再安排休息');
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

  void toggleApp(String app) {
    if (state.focusing || app == '电话') return;
    final apps = {...state.allowedApps};
    if (!apps.add(app)) apps.remove(app);
    _commit(state.copyWith(allowedApps: apps), 'allowlist.changed');
  }

  void interact(String action) {
    if (state.focusing || state.pet.dead) return;
    _commit(
      state.copyWith(
        message: switch (action) {
          'ball' => '${state.pet.name}追着小球跑了起来！',
          'rest' => '${state.pet.name}伸了个懒腰，准备打个盹。',
          'move' => '${state.pet.name}向你走过来了。',
          _ => '${state.pet.name}蹭了蹭你的手，开心地眯起眼睛。',
        },
      ),
      'pet.interacted',
    );
  }

  void toggleFloating() => _commit(state.copyWith(floating: !state.floating));
  OperationResult adopt(String name, int colorIndex) {
    if (!state.pet.dead || !state.adoptionReady || state.focusing) {
      return _result(false, 'ADOPTION_LOCKED', '先完成一次至少30分钟的重启专注');
    }
    if (name.trim().isEmpty || name.trim().length > 12) {
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

  // Demo controls are deliberately outside ActionPort.
  OperationResult advanceMinutes(int minutes) {
    if (!state.focusing) return _result(false, 'NO_SESSION', '先开始一次专注，再体验时间快进');
    if (minutes <= 0) return _result(false, 'INVALID_TIME', '快进时间需要大于零');
    _sessionFastForwarded = true;
    if (clock is! DemoClock) {
      return _result(false, 'DEMO_UNAVAILABLE', '当前未启用虚拟时钟');
    }
    (clock as DemoClock).advance(Duration(minutes: minutes));
    tick();
    return _result(true, 'OK', '已快进虚拟时间，结果标记为演示');
  }

  OperationResult advanceDay() {
    if (state.focusing) return _result(false, 'FOCUS_ACTIVE', '先完成或结束当前专注');
    final hungry = state.pet.dead || state.resting || state.todayFed
        ? state.pet.hungryDays
        : state.pet.hungryDays + 1;
    if (clock is! DemoClock) {
      return _result(false, 'DEMO_UNAVAILABLE', '当前未启用虚拟时钟');
    }
    (clock as DemoClock).advance(const Duration(days: 1));
    final pet = state.pet.copyWith(
      hungryDays: hungry,
      companionDays: state.pet.dead
          ? state.pet.companionDays
          : state.pet.companionDays + 1,
    );
    _commit(
      state.copyWith(
        now: clock.now(),
        pet: pet,
        todayFed: false,
        clearSession: true,
        message: pet.dead
            ? '${pet.name}已经离开。过去的努力会留下记录。'
            : hungry > state.pet.hungryDays
            ? '${pet.name}又饿了一天，需要你的照顾。'
            : '新的一天开始了，今天也慢慢来。',
      ),
      pet.dead && !state.pet.dead ? 'pet.died' : 'day.advanced',
    );
    return _result(true, 'OK', '已推进到${shortDate(state.now)}');
  }

  void resetDemo() {
    final repository = ref.read(repositoryProvider);
    if (clock is! DemoClock || repository is! MemoryRepository) return;
    (clock as DemoClock).reset();
    ref.read(deviceProvider).releaseRestrictions();
    repository.reset();
    _sessionFastForwarded = false;
    _commit(ref.read(repositoryProvider).load(), 'demo.reset');
  }

  @override
  Map<String, Object?> readContext() => {
    'version': 1,
    'simulated': true,
    'date': state.dayKey,
    'plans': state.plans.map((p) => p.toJson()).toList(),
    'records': state.records.take(100).map((r) => r.toJson()).toList(),
    'focus': {
      'running': state.focusing,
      'title': state.session?.title,
      'sessionId': state.session?.id,
      'remainingSeconds': state.session?.remainingSeconds(state.now),
    },
    'pet': {
      'name': state.pet.name,
      'hungryDays': state.pet.hungryDays,
      'dead': state.pet.dead,
    },
    'restDates': state.restDates.toList(),
    'allowedApps': state.allowedApps.toList(),
    'rules': {'minimumMinutes': 30, 'deathAfterDays': 7},
  };
}
