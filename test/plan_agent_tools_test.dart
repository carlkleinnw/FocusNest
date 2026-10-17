import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/journal.dart';
import 'package:focus_pet_demo/core/models.dart';
import 'package:focus_pet_demo/core/plan_management.dart';
import 'package:focus_pet_demo/core/planner_agent.dart';
import 'package:focus_pet_demo/data/demo_adapters.dart';
import 'package:focus_pet_demo/data/snapshot_codec.dart';
import 'core_planner_test.dart' show TestGateway, initial;
import 'planning_test.dart' show TestClock;

Map<String, dynamic> action(
  String op,
  String entity,
  String id, [
  Map<String, dynamic>? values,
]) => {'op': op, 'entity': entity, 'id': id, 'values': ?values};
List<Map<String, dynamic>> hierarchy() => [
  action('create', 'goal', 'g', {
    'title': 'Python采集',
    'deadline': '2026-12-31',
    'totalUnits': 10,
  }),
  for (final level in ['quarter', 'month', 'week'])
    action('create', 'period', level, {
      'title': '$level 成果',
      'level': level,
      'goalId': 'g',
      'start': level == 'quarter' ? '2026-10-01' : '2026-10-17',
      'end': level == 'quarter'
          ? '2026-12-31'
          : level == 'month'
          ? '2026-10-31'
          : '2026-10-23',
    }),
  action('create', 'task', 't', {
    'title': '解析公开页面标题',
    'date': '2026-10-17',
    'minutes': 30,
    'goalId': 'g',
  }),
];
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer c;
  late TestGateway gateway;
  late MemoryRepository repo;
  void setup(
    Future<Map<String, dynamic>> Function(List<Map<String, String>>) respond, {
    AppState? state,
  }) {
    final clock = TestClock(DateTime(2026, 10, 17));
    repo = MemoryRepository(clock)..save(state ?? initial(clock.now()));
    gateway = TestGateway(respond);
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

  test('all hierarchy levels share CRUD, query filters and durable codec', () {
    var s = applyPlanActions(
      initial(DateTime(2026, 10, 17)),
      hierarchy(),
      '1',
    ).state;
    expect(s.goals.single.title, 'Python采集');
    expect(periodPlans(s).length, 3);
    s = decodeSnapshot(
      jsonDecode(jsonEncode(encodeSnapshot(s))) as Map<String, dynamic>,
    );
    for (final level in ['quarter', 'month', 'week']) {
      s = applyPlanActions(s, [
        action('update', 'period', level, {'title': '更新 $level'}),
      ], '2').state;
    }
    final query = applyPlanActions(s, [
      {
        'op': 'query',
        'entity': 'task',
        'filter': {
          'goalId': 'g',
          'done': false,
          'from': '2026-10-17',
          'to': '2026-10-18',
        },
      },
    ], '3');
    expect(query.changed, false);
    expect(query.receipts.single['count'], 1);
    s = applyPlanActions(s, [
      action('update', 'task', 't', {'date': '2026-10-18', 'minutes': 45}),
    ], '4').state;
    expect(s.plans.single.originalDate, '2026-10-17');
    expect(s.plans.single.minutes, 45);
    s = applyPlanActions(s, [
      for (final level in ['quarter', 'month', 'week'])
        action('delete', 'period', level),
    ], '5').state;
    expect(
      periodPlans(
        decodeSnapshot(
          jsonDecode(jsonEncode(encodeSnapshot(s))) as Map<String, dynamic>,
        ),
      ),
      isEmpty,
    );
    expect(s.plans.length, 1);
    s = applyPlanActions(s, [
      action('delete', 'task', 't'),
      action('delete', 'goal', 'g'),
    ], '6').state;
    expect(s.goals, isEmpty);
    expect(s.plans, isEmpty);
  });
  test(
    'legacy month week migration has stable IDs and deleted quarters never return',
    () {
      final s = initial(
        DateTime(2026, 10, 17),
        workspace: Workspace(
          roadmaps: {
            'g': {
              'title': '旧目标',
              'months': [
                {'month': '2026-10', 'objective': '旧月成果'},
              ],
              'weeks': [
                {
                  'start': '2026-10-17',
                  'end': '2026-10-23',
                  'objective': '旧周成果',
                },
              ],
            },
          },
        ),
      );
      final periods = periodPlans(s);
      expect(periods.length, 3);
      final kept = withPeriodPlans(
        s,
        periods.where((p) => p.level != 'quarter').toList(),
      );
      expect(
        periodPlans(kept).map((p) => p.id),
        periods.where((p) => p.level != 'quarter').map((p) => p.id),
      );
    },
  );
  test(
    'batch capacity is validated after moves; invalid batch never mutates input',
    () {
      final s = applyPlanActions(initial(DateTime(2026, 10, 17)), [
        action('create', 'task', 'a', {
          'title': '任务A',
          'date': '2026-10-17',
          'minutes': 180,
        }),
      ], '1').state;
      final moved = applyPlanActions(s, [
        action('create', 'task', 'b', {
          'title': '任务B',
          'date': '2026-10-17',
          'minutes': 180,
        }),
        action('update', 'task', 'a', {'date': '2026-10-18'}),
      ], '2').state;
      expect(moved.plans.length, 2);
      expect(
        () => applyPlanActions(s, [
          action('delete', 'task', 'a'),
          action('update', 'task', 'missing', {'title': '错误'}),
        ], '3'),
        throwsA(isA<AgentFailure>()),
      );
      expect(s.plans.single.id, 'a');
      expect(
        () => applyPlanActions(s, [
          action('create', 'task', 'b', {
            'title': '超时长',
            'date': '2026-10-17',
            'minutes': 30,
          }),
        ], '3'),
        throwsA(isA<AgentFailure>()),
      );
    },
  );
  test(
    'tools cannot fabricate completion or operate non-plan capabilities',
    () {
      final s = applyPlanActions(
        initial(DateTime(2026, 10, 17)),
        hierarchy(),
        '1',
      ).state;
      for (final a in [
        action('update', 'task', 't', {'doneUnits': 1}),
        action('create', 'secret', 'key', {'key': 'fixture'}),
        action('update', 'task', 'invented', {'title': 'x'}),
      ]) {
        expect(
          () => applyPlanActions(s, [a], '2'),
          throwsA(isA<AgentFailure>()),
        );
      }
      expect(s.plans.single.done, false);
    },
  );
  test(
    'goal deletion detaches tasks, explicit cascade keeps completed evidence',
    () {
      var s = applyPlanActions(
        initial(DateTime(2026, 10, 17)),
        hierarchy(),
        '1',
      ).state;
      final detached = applyPlanActions(s, [
        action('delete', 'goal', 'g'),
      ], '2').state;
      expect(detached.plans.single.goalId, isNull);
      expect(periodPlans(detached), isEmpty);
      s = s.copyWith(
        plans: [
          s.plans.single.copyWith(
            doneUnits: 1,
            completedAt: '2026-10-17T10:00:00',
          ),
        ],
      );
      final deleted = applyPlanActions(s, [
        {...action('delete', 'goal', 'g'), 'cascade': true},
      ], '3').state;
      expect(deleted.plans.single.done, true);
      expect(deleted.plans.single.completedAt, '2026-10-17T10:00:00');
    },
  );
  test(
    'agent observes queries, executes batch, then saves true receipts once',
    () async {
      setup((m) async {
        final input = jsonDecode(m.last['content']!) as Map;
        final observations = input['toolObservations'] as List;
        if (observations.isEmpty) {
          return {
            'kind': 'actions',
            'actions': [
              {'op': 'query', 'entity': 'task'},
            ],
          };
        }
        if (observations.length == 1) {
          expect(observations.single['results'].single['count'], 0);
          return {'kind': 'actions', 'actions': hierarchy()};
        }
        expect(
          c.read(appProvider).plans,
          isEmpty,
          reason: 'staged operations are not committed early',
        );
        return {'kind': 'message', 'message': '已按要求安排。'};
      });
      expect(
        (await c.read(appProvider.notifier).askPlanner('安排并保存Python计划')).ok,
        true,
      );
      expect(gateway.calls, 3);
      expect(repo.load().plans.single.id, 't');
      expect(c.read(appProvider).workspace.rounds, 0);
      expect(
        c.read(appProvider).workspace.chat.last['content'],
        contains('已保存：'),
      );
    },
  );
  test(
    'context includes original and appended semantics; clear request can act without question',
    () async {
      setup((m) async {
        final conversation =
            (jsonDecode(m.last['content']!) as Map)['conversation'] as List;
        if (conversation.length == 1) {
          return {'kind': 'question', 'question': '最终希望做出什么成果？'};
        }
        expect(conversation.first['content'], '学Python采集，已有Python基础');
        expect(conversation.last['content'], '导出CSV，每天30分钟，两周完成');
        expect(m.first['content'], contains('已知信息不能重复问'));
        return {'kind': 'message', 'message': '理解为两周内完成公开页面采集并导出CSV。'};
      });
      final app = c.read(appProvider.notifier);
      expect((await app.askPlanner('学Python采集，已有Python基础')).ok, true);
      expect((await app.askPlanner('导出CSV，每天30分钟，两周完成')).ok, true);
      expect(c.read(appProvider).workspace.rounds, 0);
      for (var i = 0; i < 8; i++) {
        expect((await app.askPlanner('导出CSV，每天30分钟，两周完成')).ok, true);
      }
      expect(
        c.read(appProvider).workspace.chat.length,
        20,
        reason: 'no old five-turn cutoff',
      );
    },
  );
  test(
    'tool failure rolls back whole turn and allows model correction',
    () async {
      setup((m) async {
        final obs =
            (jsonDecode(m.last['content']!) as Map)['toolObservations'] as List;
        if (obs.isEmpty) return {'kind': 'actions', 'actions': hierarchy()};
        if (obs.length == 1) {
          return {
            'kind': 'actions',
            'actions': [action('delete', 'task', 'not-real')],
          };
        }
        if (obs.length == 2) {
          expect(obs.last['error'], isNotNull);
          return {
            'kind': 'actions',
            'actions': [
              action('create', 'task', 'fixed', {
                'title': '修正后的任务',
                'date': '2026-10-17',
              }),
            ],
          };
        }
        return {'kind': 'message', 'message': '只创建修正后的任务。'};
      });
      expect((await c.read(appProvider.notifier).askPlanner('创建任务')).ok, true);
      expect(c.read(appProvider).plans.single.id, 'fixed');
      expect(c.read(appProvider).goals, isEmpty);
    },
  );
  test(
    'network failure after staged changes and endless tool loops never save partial plans',
    () async {
      setup((_) async {
        if (gateway.calls == 1) {
          return {'kind': 'actions', 'actions': hierarchy()};
        }
        throw const AgentFailure('网络中断');
      });
      expect((await c.read(appProvider.notifier).askPlanner('安排')).ok, false);
      expect(repo.load().plans, isEmpty);
    },
  );
  test(
    'manual edit during model request is retained and stale mutation rejected',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      setup((_) => pending.future);
      final app = c.read(appProvider.notifier);
      final answer = app.askPlanner('新增任务');
      app.upsertPlan(
        const Plan(
          id: 'manual',
          title: '手动任务',
          minutes: 30,
          time: '19:00',
          date: '2026-10-17',
        ),
      );
      pending.complete({'kind': 'actions', 'actions': hierarchy()});
      expect((await answer).ok, false);
      expect(c.read(appProvider).plans.single.id, 'manual');
    },
  );
  test(
    'endless model tool calls stop at the budget and never persist',
    () async {
      setup(
        (_) async => {
          'kind': 'actions',
          'actions': [
            {'op': 'query', 'entity': 'task'},
          ],
        },
      );
      expect((await c.read(appProvider.notifier).askPlanner('查看任务')).ok, false);
      expect(gateway.calls, 6);
      expect(repo.load().workspace.chat, isEmpty);
    },
  );
  test('duplicate retries and invalid natural periods are rejected', () {
    final s = applyPlanActions(
      initial(DateTime(2026, 10, 17)),
      hierarchy(),
      '1',
    ).state;
    expect(
      () => applyPlanActions(s, [
        action('create', 'task', 'duplicate', {
          'title': '解析公开页面标题',
          'date': '2026-10-17',
          'time': '19:00',
        }),
      ], '2'),
      throwsA(isA<AgentFailure>()),
    );
    for (final pair in [
      ('week', '2026-10-31'),
      ('month', '2026-11-01'),
      ('quarter', '2027-01-01'),
    ]) {
      expect(
        () => applyPlanActions(s, [
          action('update', 'period', pair.$1, {'end': pair.$2}),
        ], '3'),
        throwsA(isA<AgentFailure>()),
      );
    }
  });
  test(
    'query pagination exposes exact total and next offset without losing revision coverage',
    () {
      final base = initial(
        DateTime(2026, 10, 17),
        plans: [
          for (var i = 0; i < 90; i++)
            Plan(
              id: 'p$i',
              title: '任务$i',
              minutes: 30,
              time: '19:00',
              date: '2026-10-17',
            ),
        ],
      );
      final catalog = agentPlanContext(base)['tasks'] as Map;
      expect(catalog['truncated'], true);
      expect((catalog['preview'] as List).length, 80);
      final page = applyPlanActions(base, [
        {'op': 'query', 'entity': 'task', 'offset': 80, 'limit': 5},
      ], '1').receipts.single;
      expect(page['count'], 90);
      final categoryChanged = base.copyWith(
        plans: [
          const Plan(
            id: 'p0',
            title: '任务0',
            minutes: 30,
            time: '19:00',
            date: '2026-10-17',
            category: '另一分类',
          ),
          ...base.plans.skip(1),
        ],
      );
      expect(
        planRevision(base),
        isNot(planRevision(categoryChanged)),
        reason:
            'revision covers full task fields, including fields omitted from the AI catalog',
      );
      expect(page['nextOffset'], 85);
      expect((page['rows'] as List).first['id'], 'p80');
      expect(
        planRevision(base),
        isNot(planRevision(base.copyWith(plans: base.plans.take(89).toList()))),
      );
    },
  );
}
