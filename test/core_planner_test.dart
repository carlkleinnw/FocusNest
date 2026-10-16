import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:focus_pet_demo/data/android_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/journal.dart';
import 'package:focus_pet_demo/core/models.dart';
import 'package:focus_pet_demo/core/planner_agent.dart';
import 'package:focus_pet_demo/core/review_engine.dart';
import 'package:focus_pet_demo/data/demo_adapters.dart';
import 'package:focus_pet_demo/data/planner_gateway.dart';
import 'package:focus_pet_demo/data/snapshot_codec.dart';
import 'planning_test.dart' show TestClock;

class TestGateway implements PlannerGateway {
  Future<Map<String, dynamic>> Function(List<Map<String, String>>) respond;
  TestGateway(this.respond);
  int calls = 0;
  @override
  Future<Map<String, dynamic>> request(List<Map<String, String>> messages) {
    calls++;
    return respond(messages);
  }

  @override
  Future<Map<String, dynamic>> settings() async => {
    'configured': true,
    'model': 'deepseek-flash',
  };
  @override
  Future<void> configure({
    required String key,
    required String model,
    required bool remove,
  }) async {}
}

Map<String, dynamic> selection(List<Map<String, String>> messages) {
  final input = jsonDecode(messages.last['content']!) as Map;
  return {
    'highlights': (input['facts'] as List)
        .take(6)
        .map((f) => (f as Map)['id'])
        .toList(),
    'advice': '下阶段安排复习。',
  };
}

AppState initial(
  DateTime now, {
  List<Plan> plans = const [],
  List<FocusRecord> records = const [],
  Workspace? workspace,
}) => AppState(
  now: now,
  pet: const PetState(),
  plans: plans,
  records: records,
  workspace: workspace,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestClock clock;
  late MemoryRepository repo;
  late ProviderContainer c;
  late TestGateway gateway;
  void setup(
    AppState state, {
    Future<Map<String, dynamic>> Function(List<Map<String, String>>)? respond,
  }) {
    clock = TestClock(state.now);
    repo = MemoryRepository(clock)..save(state);
    gateway = TestGateway(respond ?? (m) async => selection(m));
    c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        repositoryProvider.overrideWithValue(repo),
        plannerGatewayProvider.overrideWithValue(gateway),
      ],
    );
    c.read(appProvider);
    addTearDown(c.dispose);
  }

  Plan task(
    String id,
    String date, {
    bool done = false,
    String? completedAt,
    String? goalId,
  }) => Plan(
    id: id,
    title: '练习 $id',
    minutes: 30,
    time: '09:00',
    date: date,
    goalId: goalId,
    doneUnits: done ? 1 : 0,
    completedAt: completedAt,
  );

  test(
    'overdue tasks retain stable identity, original day and exact rollover count across restart',
    () async {
      setup(
        initial(
          DateTime(2026, 10, 13, 23, 55),
          plans: [
            task('pending', '2026-10-13'),
            task(
              'done',
              '2026-10-13',
              done: true,
              completedAt: '2026-10-13T12:00:00',
            ),
          ],
        ),
      );
      clock.at = DateTime(2026, 10, 17, 8);
      await c.read(appProvider.notifier).tick();
      final s = c.read(appProvider);
      expect(s.plans.first.id, 'pending');
      expect(s.plans.first.date, '2026-10-17');
      expect(s.plans.first.originalDate, '2026-10-13');
      expect(s.plans.first.rollovers, 4);
      expect(s.plans.last.date, '2026-10-13');
      await c.read(appProvider.notifier).tick();
      expect(c.read(appProvider).plans.first.rollovers, 4);
      expect(decodeSnapshot(encodeSnapshot(s)).plans.first.rollovers, 4);
    },
  );
  test(
    'completion timestamp is actual date, stable on repeat, cleared when undone',
    () {
      setup(
        initial(DateTime(2026, 10, 16, 14), plans: [task('p', '2026-10-16')]),
      );
      final app = c.read(appProvider.notifier);
      expect(app.setTaskProgress('p', 1).ok, true);
      final stamp = c.read(appProvider).plans.single.completedAt;
      clock.at = clock.at.add(const Duration(hours: 1));
      app.setTaskProgress('p', 1);
      expect(c.read(appProvider).plans.single.completedAt, stamp);
      app.setTaskProgress('p', 0);
      expect(c.read(appProvider).plans.single.completedAt, isNull);
    },
  );
  test('deleted tasks never roll over again', () async {
    setup(initial(DateTime(2026, 10, 16), plans: [task('p', '2026-10-16')]));
    c.read(appProvider.notifier).removePlan('p');
    clock.at = DateTime(2026, 10, 20);
    await c.read(appProvider.notifier).tick();
    expect(c.read(appProvider).plans, isEmpty);
  });
  test('v2 migration retains data but never invents completion dates', () {
    final old = encodeSnapshot(
      initial(
        DateTime(2026, 10, 16),
        plans: [task('p', '2026-10-01', done: true)],
      ),
    );
    old['version'] = 2;
    old.remove('workspace');
    final restored = decodeSnapshot(old);
    expect(restored.plans.single.completedAt, isNull);
    expect(restored.workspace.reviews, isEmpty);
    expect(nextReview(restored), isNull);
  });
  test(
    'three clarification rounds max; invalid fourth does not change conversation',
    () async {
      setup(
        initial(DateTime(2026, 10, 16)),
        respond: (_) async => {'kind': 'question', 'question': '你每天有多久？'},
      );
      final app = c.read(appProvider.notifier);
      for (var i = 0; i < 3; i++) {
        expect((await app.askPlanner('学习计划 $i')).ok, true);
      }
      final before = c.read(appProvider).workspace.chat;
      expect((await app.askPlanner('请继续')).ok, false);
      expect(c.read(appProvider).workspace.rounds, 3);
      expect(c.read(appProvider).workspace.chat, before);
    },
  );
  test(
    'demo draft is previewed, atomically imported, and cannot be duplicated',
    () async {
      final demo = DemoPlannerGateway('2026-10-16');
      final draft = await demo.request([
        {'role': 'system', 'content': 'plan'},
        {'role': 'user', 'content': 'Python'},
        {'role': 'user', 'content': '每天30分钟'},
      ]);
      setup(initial(DateTime(2026, 10, 16)), respond: (_) async => draft);
      final app = c.read(appProvider.notifier);
      expect((await app.askPlanner('学Python')).ok, true);
      expect(c.read(appProvider).plans, isEmpty);
      expect((await app.importDraft()).ok, true);
      expect(c.read(appProvider).plans.length, 7);
      expect(c.read(appProvider).goals.length, 1);
      expect((await app.importDraft()).ok, false);
      expect(c.read(appProvider).plans.length, 7);
      final stored =
          c.read(appProvider).workspace.roadmaps.values.single as Map;
      expect(
        stored['tasks'],
        isEmpty,
        reason:
            'completed task details must not survive in duplicate roadmap copies',
      );
    },
  );
  test(
    'draft validation rejects impossible dates, missing hierarchy, duplicate tasks and overload',
    () async {
      final demo = DemoPlannerGateway('2026-10-16');
      final raw = await demo.request([
        {'role': 'system', 'content': 'plan'},
        {'role': 'user', 'content': 'a'},
        {'role': 'user', 'content': 'b'},
      ]);
      final state = initial(DateTime(2026, 10, 16));
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (j) => (j['tasks'] as List).first['date'] = '2026-02-30',
        (j) => j['months'] = [],
        (j) => (j['tasks'] as List).add((j['tasks'] as List).first),
        (j) => (j['tasks'] as List).first['minutes'] = 181,
        (j) => (j['tasks'] as List).first['title'] = '',
      ]) {
        final j = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
        mutate(j);
        expect(() => validateDraft(j, state), throwsA(isA<AgentFailure>()));
      }
      expect(
        () => validateDraft(
          raw,
          state.copyWith(
            dailyCapacity: 30,
            plans: [task('existing', '2026-10-17')],
          ),
        ),
        throwsA(isA<AgentFailure>()),
      );
    },
  );
  test('network failure never saves user turn or an incomplete plan', () async {
    setup(
      initial(DateTime(2026, 10, 16)),
      respond: (_) async => throw const AgentFailure('连接失败'),
    );
    expect((await c.read(appProvider.notifier).askPlanner('Python')).ok, false);
    expect(c.read(appProvider).workspace.chat, isEmpty);
    expect(c.read(appProvider).plans, isEmpty);
  });
  test(
    'weekly review deletes only completed sourced tasks and genuine focus records',
    () async {
      setup(
        initial(
          DateTime(2026, 10, 19),
          plans: [
            task(
              'p',
              '2026-10-12',
              done: true,
              completedAt: '2026-10-13T12:00:00',
            ),
            task('pending', '2026-10-19'),
          ],
          records: [
            FocusRecord(
              id: 'real',
              title: '计时',
              minutes: 45,
              at: DateTime(2026, 10, 13),
              completed: true,
            ),
            FocusRecord(
              id: 'cancel',
              title: '提前退出',
              minutes: 7,
              at: DateTime(2026, 10, 14),
              completed: false,
            ),
            FocusRecord(
              id: 'virtual',
              title: '模拟',
              minutes: 90,
              at: DateTime(2026, 10, 13),
              completed: true,
              virtual: true,
            ),
          ],
        ),
      );
      final result = await c.read(appProvider.notifier).summarizeDue();
      expect(result.ok, true);
      final s = c.read(appProvider),
          r = c.read(appProvider).workspace.reviews.single;
      expect(s.plans.map((p) => p.id), ['pending']);
      expect(s.records.single.id, 'virtual');
      expect(r.tasks, 1);
      expect(r.minutes, 45);
      expect(r.cancelledMinutes, 7);
      expect(r.sessions, 1);
      expect(r.sources, 3);
      expect(r.highlights.single, contains('练习 p'));
      expect(r.digest.length, 64);
      final calls = gateway.calls;
      await c.read(appProvider.notifier).summarizeDue();
      expect(gateway.calls, calls);
    },
  );
  for (final failure in ['network', 'unknown-reference', 'empty-highlights']) {
    test('review $failure retains every source', () async {
      setup(
        initial(
          DateTime(2026, 10, 19),
          plans: [
            task(
              'p',
              '2026-10-12',
              done: true,
              completedAt: '2026-10-13T12:00:00',
            ),
          ],
        ),
        respond: (m) async {
          if (failure == 'network') throw const AgentFailure('断网');
          return {
            'highlights': failure == 'empty-highlights'
                ? []
                : ['imaginary-task'],
            'advice': '继续',
          };
        },
      );
      expect((await c.read(appProvider.notifier).summarizeDue()).ok, false);
      expect(c.read(appProvider).plans.length, 1);
      expect(c.read(appProvider).workspace.reviews, isEmpty);
    });
  }
  test('open calendar period can never be compacted', () async {
    setup(
      initial(
        DateTime(2026, 10, 16),
        plans: [
          task(
            'p',
            '2026-10-16',
            done: true,
            completedAt: '2026-10-16T12:00:00',
          ),
        ],
      ),
    );
    expect(nextReview(c.read(appProvider)), isNull);
    await c.read(appProvider.notifier).summarizeDue();
    expect(gateway.calls, 0);
  });
  test(
    'cross-month weekly segments roll through month/quarter/year without duplicate totals',
    () async {
      final dates = [
        '2025-01-31',
        '2025-02-01',
        '2025-03-31',
        '2025-04-01',
        '2025-12-31',
      ];
      setup(
        initial(
          DateTime(2026, 1, 2),
          plans: [
            for (var i = 0; i < dates.length; i++)
              task(
                'p$i',
                dates[i],
                done: true,
                completedAt: '${dates[i]}T12:00:00',
                goalId: 'g',
              ),
          ],
          records: [
            for (var i = 0; i < dates.length; i++)
              FocusRecord(
                id: 'r$i',
                title: '计时',
                minutes: 30,
                at: DateTime.parse(dates[i]),
                completed: true,
              ),
          ],
        ),
      );
      expect((await c.read(appProvider.notifier).summarizeDue()).ok, true);
      final s = c.read(appProvider),
          r = c.read(appProvider).workspace.reviews.single;
      expect(r.level, 'year');
      expect(r.start, '2025-01-01');
      expect(r.end, '2026-01-01');
      expect(r.tasks, 5);
      expect(r.minutes, 150);
      expect(r.byGoal['g'], 5);
      expect(r.sources, 10);
      expect(s.plans, isEmpty);
      expect(s.records, isEmpty);
      expect(
        decodeSnapshot(encodeSnapshot(s)).workspace.reviews.single.toJson(),
        r.toJson(),
      );
    },
  );
  test('evidence changed while AI works aborts deletion', () async {
    final response = Completer<Map<String, dynamic>>();
    setup(
      initial(
        DateTime(2026, 10, 19),
        plans: [
          task(
            'p',
            '2026-10-12',
            done: true,
            completedAt: '2026-10-13T12:00:00',
          ),
        ],
      ),
      respond: (_) => response.future,
    );
    final app = c.read(appProvider.notifier);
    final pending = app.summarizeDue();
    app.setTaskProgress('p', 0);
    response.complete({
      'highlights': ['task:p'],
      'advice': '继续',
    });
    expect((await pending).code, 'SOURCE_CHANGED');
    expect(c.read(appProvider).plans.length, 1);
  });
  test(
    'concurrent planner response cannot overwrite freshly saved review',
    () async {
      final response = Completer<Map<String, dynamic>>();
      setup(
        initial(
          DateTime(2026, 10, 19),
          plans: [
            task(
              'p',
              '2026-10-12',
              done: true,
              completedAt: '2026-10-13T12:00:00',
            ),
          ],
        ),
        respond: (messages) =>
            messages.first['content']!.contains('SUMMARY_SELECTION')
            ? Future.value(selection(messages))
            : response.future,
      );
      final app = c.read(appProvider.notifier);
      final pending = app.askPlanner('新目标');
      await app.summarizeDue();
      response.complete({'kind': 'question', 'question': '期限？'});
      await pending;
      expect(c.read(appProvider).workspace.reviews.length, 1);
      expect(c.read(appProvider).workspace.chat.length, 2);
    },
  );
  test(
    'editing an auto-rolled task beyond goal deadline remains possible',
    () async {
      setup(
        initial(
          DateTime(2026, 10, 16),
          plans: [
            task('p', '2026-10-15').copyWith(
              date: '2026-10-16',
              originalDate: '2026-10-15',
              rollovers: 1,
            ),
          ],
        ),
      );
      expect(
        c
            .read(appProvider.notifier)
            .upsertPlan(
              Plan(
                id: 'p',
                title: '调整后的练习',
                minutes: 45,
                time: '10:00',
                date: '2026-10-16',
              ),
            )
            .ok,
        true,
      );
      expect(c.read(appProvider).plans.single.originalDate, '2026-10-15');
      expect(c.read(appProvider).plans.single.rollovers, 1);
    },
  );
  test(
    'failed native compaction save preserves memory and durable sources',
    () async {
      final now = DateTime(2026, 10, 19);
      final original = initial(
        now,
        plans: [
          task(
            'p',
            '2026-10-12',
            done: true,
            completedAt: '2026-10-13T12:00:00',
          ),
        ],
      );
      var stored = jsonEncode(encodeSnapshot(original));
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(nativeChannel, (call) async {
        if (call.method == 'save') {
          final snapshot = (call.arguments as Map)['snapshot'] as String;
          if (((jsonDecode(snapshot) as Map)['workspace']['reviews'] as List)
              .isNotEmpty) {
            throw PlatformException(code: 'DISK_FULL');
          }
          stored = snapshot;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(nativeChannel, null),
      );
      final androidRepo = AndroidRepository(original);
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(TestClock(now)),
          repositoryProvider.overrideWithValue(androidRepo),
          plannerGatewayProvider.overrideWithValue(
            TestGateway((m) async => selection(m)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final app = container.read(appProvider.notifier);
      await app.tick();
      await androidRepo.flush();
      expect((await app.summarizeDue()).code, 'STORAGE_ERROR');
      await androidRepo.flush();
      expect(container.read(appProvider).plans.single.id, 'p');
      expect(container.read(appProvider).workspace.reviews, isEmpty);
      final disk = decodeSnapshot(jsonDecode(stored) as Map<String, dynamic>);
      expect(disk.plans.single.id, 'p');
      expect(disk.workspace.reviews, isEmpty);
    },
  );
}
