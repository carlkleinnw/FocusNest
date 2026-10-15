import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/models.dart';
import 'package:focus_pet_demo/core/planning.dart';
import 'package:focus_pet_demo/core/ports.dart';
import 'package:focus_pet_demo/data/demo_adapters.dart';
import 'package:focus_pet_demo/data/snapshot_codec.dart';

class TestClock implements ClockPort {
  TestClock(this.at);
  DateTime at;
  @override
  DateTime now() => at;
}

class RefusingDevice extends SimulatedDevice {
  @override
  OperationResult applyRestrictions(
    Set<String> allowedPackages,
    FocusSession session,
    AppState snapshot,
  ) => const OperationResult(false, 'PERMISSION_REQUIRED', '权限未开启');
}

void main() {
  test('starting immediately after midnight settles yesterday first', () async {
    final clock = TestClock(DateTime(2026, 10, 13, 23, 50));
    final repo = MemoryRepository(clock);
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        repositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    final controller = c.read(appProvider.notifier);
    await controller.tick();
    clock.at = DateTime(2026, 10, 14, 0, 5);
    expect(
      (await controller.start(
        const Plan(id: 'free', title: '阅读', minutes: 30, time: '00:05'),
      )).ok,
      true,
    );
    expect(c.read(appProvider).dayKey, '2026-10-14');
    expect(c.read(appProvider).pet.hungryDays, 1);
  });
  late ProviderContainer container;
  late AppController app;
  setUp(() {
    container = ProviderContainer();
    app = container.read(appProvider.notifier);
  });
  tearDown(() => container.dispose());
  const goal = Goal(
    id: 'g',
    title: '专题练习',
    deadline: '2026-11-13',
    totalUnits: 20,
    unit: '题',
  );
  const stage = Milestone(
    id: 'm',
    goalId: 'g',
    title: '第一阶段',
    units: 5,
    deadline: '2026-10-20',
  );
  const task = Plan(
    id: 't',
    title: '导数练习',
    minutes: 30,
    time: '09:00',
    date: '2026-10-14',
    goalId: 'g',
    milestoneId: 'm',
    units: 3,
  );
  test('goal-stage-task linkage validates allocation, dates, and capacity', () {
    expect(app.upsertGoal(goal).ok, true);
    expect(app.upsertMilestone(stage).ok, true);
    expect(app.upsertPlan(task).ok, true);
    expect(
      app
          .upsertPlan(
            const Plan(
              id: 'overflow',
              title: '多安排',
              minutes: 30,
              time: '09:00',
              date: '2026-10-14',
              goalId: 'g',
              milestoneId: 'm',
              units: 3,
            ),
          )
          .code,
      'STAGE_EXCEEDED',
    );
    expect(
      app
          .upsertPlan(
            const Plan(
              id: 'wrong',
              title: '无效关联',
              minutes: 30,
              time: '09:00',
              goalId: 'unknown',
            ),
          )
          .code,
      'INVALID_LINK',
    );
    expect(
      app
          .upsertPlan(
            const Plan(
              id: 'late',
              title: '超期',
              minutes: 30,
              time: '09:00',
              date: '2026-10-21',
              goalId: 'g',
              milestoneId: 'm',
            ),
          )
          .code,
      'STAGE_EXCEEDED',
    );
    expect(
      app
          .upsertPlan(
            const Plan(
              id: 'capacity',
              title: '超负荷',
              minutes: 60,
              time: '09:00',
            ),
          )
          .code,
      'CAPACITY_EXCEEDED',
    );
    expect(
      app
          .upsertMilestone(
            const Milestone(
              id: 'm',
              goalId: 'g',
              title: '改阶段',
              units: 5,
              deadline: '2026-10-13',
            ),
          )
          .ok,
      false,
    );
    expect(
      app
          .upsertGoal(
            const Goal(
              id: 'g',
              title: '改目标',
              deadline: '2026-10-13',
              totalUnits: 20,
            ),
          )
          .ok,
      false,
    );
  });
  test('progress is idempotent and never feeds a pet', () {
    app.upsertGoal(goal);
    app.upsertMilestone(stage);
    app.upsertPlan(task);
    expect(app.setTaskProgress('t', 2).ok, true);
    expect(app.setTaskProgress('t', 2).ok, true);
    expect(
      container
          .read(appProvider)
          .plans
          .firstWhere((p) => p.id == 't')
          .doneUnits,
      2,
    );
    expect(app.setTaskProgress('t', 4).ok, false);
    expect(container.read(appProvider).pet.meals, 8);
  });
  test('future and finished tasks cannot start a focus session', () async {
    app.upsertGoal(goal);
    app.upsertMilestone(stage);
    app.upsertPlan(task);
    expect((await app.start(task)).code, 'TASK_UNAVAILABLE');
    final today = task.copyWith(date: '2026-10-13');
    app.upsertPlan(today);
    app.setTaskProgress('t', 3);
    expect((await app.start(today)).code, 'TASK_UNAVAILABLE');
  });
  test(
    'snapshot round trip preserves active session, goal links and permissions choice',
    () async {
      app.upsertGoal(goal);
      app.upsertMilestone(stage);
      app.upsertPlan(task);
      await app.start(
        const Plan(id: 'free', title: '阅读', minutes: 30, time: '09:00'),
      );
      final state = container.read(appProvider);
      final restored = decodeSnapshot(encodeSnapshot(state));
      expect(restored.session!.id, state.session!.id);
      expect(restored.blockedApps, {
        'demo.course',
        'demo.dictionary',
        'demo.video',
        'demo.game',
      });
      expect(restored.allowedApps, isEmpty);
      expect(restored.appsInitialized, true);
      expect(restored.plans.firstWhere((p) => p.id == 't').milestoneId, 'm');
      expect(restored.goals.single.totalUnits, 20);
      expect(restored.protectionReady, false);
      expect(() => decodeSnapshot({'version': 99}), throwsFormatException);
    },
  );
  test('device refusal never starts timer or rewards', () async {
    final c = ProviderContainer(
      overrides: [deviceProvider.overrideWithValue(RefusingDevice())],
    );
    addTearDown(c.dispose);
    final controller = c.read(appProvider.notifier);
    expect(
      (await controller.start(
        const Plan(id: 'x', title: '阅读', minutes: 30, time: '09:00'),
      )).ok,
      false,
    );
    expect(c.read(appProvider).focusing, false);
    expect(c.read(appProvider).pet.meals, 8);
  });
  test(
    'recover expired offline focus before settling following days, reward once',
    () async {
      final clock = TestClock(DateTime(2026, 10, 15, 8));
      final repository = MemoryRepository(clock);
      repository.save(
        AppState(
          plans: const [],
          records: const [],
          now: DateTime(2026, 10, 13, 23, 20),
          pet: const PetState(hungryDays: 2),
          session: FocusSession(
            id: 'offline',
            title: '阅读',
            minutes: 30,
            startedAt: DateTime(2026, 10, 13, 23, 20),
          ),
        ),
      );
      final c = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          repositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(c.dispose);
      final controller = c.read(appProvider.notifier);
      await controller.tick();
      expect(c.read(appProvider).pet.meals, 9);
      expect(c.read(appProvider).pet.hungryDays, 1);
      expect(c.read(appProvider).records.single.id, 'offline');
      await controller.tick();
      expect(c.read(appProvider).records.length, 1);
    },
  );
  test('focus ending exactly at midnight feeds the preceding day', () async {
    final clock = TestClock(DateTime(2026, 10, 14, 0));
    final repo = MemoryRepository(clock);
    repo.save(
      AppState(
        plans: const [],
        records: const [],
        now: DateTime(2026, 10, 13, 23, 30),
        pet: const PetState(),
        session: FocusSession(
          id: 'midnight',
          title: '阅读',
          minutes: 30,
          startedAt: DateTime(2026, 10, 13, 23, 30),
        ),
      ),
    );
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        repositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    await c.read(appProvider.notifier).tick();
    expect(c.read(appProvider).pet.hungryDays, 0);
    expect(c.read(appProvider).todayFed, false);
  });
  test(
    'all optional apps start blocked and only explicit choices enter allowlist',
    () async {
      final apps = await container.read(deviceProvider).apps();
      app.initializeApps(apps);
      expect(container.read(appProvider).blockedApps, {
        'demo.course',
        'demo.dictionary',
        'demo.video',
        'demo.game',
      });
      app.toggleInstalledApp(
        apps.firstWhere((a) => a.package == 'demo.course'),
      );
      app.initializeApps(apps);
      expect(container.read(appProvider).allowedApps, {'demo.course'});
      expect(
        decodeSnapshot(encodeSnapshot(container.read(appProvider))).allowedApps,
        {'demo.course'},
      );
      expect(container.read(appProvider).blockedApps, {
        'demo.dictionary',
        'demo.video',
        'demo.game',
      });
      app.addAllowedApps([
        apps.firstWhere((a) => a.package == 'demo.dictionary'),
        apps.firstWhere((a) => a.package == 'demo.video'),
        apps.firstWhere((a) => a.protected),
      ]);
      expect(container.read(appProvider).allowedApps, {
        'demo.course',
        'demo.dictionary',
        'demo.video',
      });
      expect(container.read(appProvider).blockedApps, {'demo.game'});
      app.toggleInstalledApp(apps.firstWhere((a) => a.protected));
      expect(
        container.read(appProvider).allowedApps.contains('demo.phone'),
        false,
      );
      app.initializeApps([
        ...apps,
        const InstalledApp(package: 'demo.new', name: '新应用', category: '其他'),
      ]);
      expect(
        container.read(appProvider).blockedApps.contains('demo.new'),
        true,
      );
      expect(
        container.read(appProvider).allowedApps.contains('demo.new'),
        false,
      );
    },
  );
  test(
    'old snapshot migrates to empty explicit allowlist without losing focus',
    () {
      final previous = encodeSnapshot(
        container
            .read(appProvider)
            .copyWith(
              session: FocusSession(
                id: 'existing',
                title: '正在学习',
                minutes: 30,
                startedAt: DateTime(2026, 10, 13, 9),
              ),
            ),
      );
      previous.remove('allowlistSchema');
      previous['allowedApps'] = ['课程平台', '词典', '电话'];
      previous['appsInitialized'] = true;
      final restored = decodeSnapshot(previous);
      expect(restored.allowedApps, isEmpty);
      expect(restored.appsInitialized, true);
      expect(restored.session?.id, 'existing');
      expect(restored.permissionPromptSeen, false);
    },
  );
  test('old permission choice gets one recovery prompt after upgrade', () {
    final previous = encodeSnapshot(container.read(appProvider));
    previous['permissionPromptSeen'] = true;
    previous.remove('permissionEverReady');
    previous.remove('permissionRecoveryPromptSeen');
    final restored = decodeSnapshot(previous);
    expect(restored.permissionEverReady, true);
    expect(restored.permissionRecoveryPromptSeen, false);
    final roundTrip = decodeSnapshot(encodeSnapshot(restored));
    expect(roundTrip.permissionEverReady, true);
    expect(roundTrip.permissionRecoveryPromptSeen, false);
  });
}
