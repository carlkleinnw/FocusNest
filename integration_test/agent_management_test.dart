import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:focus_pet_demo/main.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/models.dart';
import 'package:focus_pet_demo/core/plan_management.dart';
import 'package:focus_pet_demo/data/android_adapters.dart';
import 'package:focus_pet_demo/data/planner_gateway.dart';
import 'package:focus_pet_demo/data/snapshot_codec.dart';
import 'package:focus_pet_demo/ui/period_form.dart';
import 'host_planner_gateway.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'hierarchy editors and contextual native DeepSeek agent end to end',
    (tester) async {
      tester.testTextInput.register();
      const live = bool.fromEnvironment('LIVE_AGENT');
      final clock = RealClock();
      final pristine = AppState(
        now: clock.now(),
        pet: const PetState(),
        plans: [],
        records: [],
        permissionPromptSeen: true,
      );
      final before = await nativeChannel.invokeMethod<String>('load');
      if (before != null) {
        expect(
          decodeSnapshot(jsonDecode(before) as Map<String, dynamic>).focusing,
          false,
        );
      }
      final native = AndroidPlannerGateway();
      final host = HostPlannerGateway();
      if (live && (await native.settings())['configured'] != true) {
        final key = await tester.runAsync(() => host.readSavedKey());
        expect(key?.isNotEmpty, true);
        await native.configure(
          key: key!,
          model: 'deepseek-flash',
          remove: false,
        );
      }
      final tracked = TrackedPlannerGateway(native);
      final repo = AndroidRepository(pristine);
      final c = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          repositoryProvider.overrideWithValue(repo),
          deviceProvider.overrideWithValue(AndroidDevice()),
          plannerGatewayProvider.overrideWithValue(tracked),
        ],
      );
      final app = c.read(appProvider.notifier);
      final today = dateKey(clock.now());
      Future<void> settle() async {
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }

      Future<void> tapFinder(Finder f) async {
        await tester.ensureVisible(f);
        await settle();
        await tester.tap(f);
        await settle();
      }

      Future<void> tap(String label) => tapFinder(find.text(label).last);
      Future<void> field(int i, String value) async {
        await tester.enterText(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextField),
              )
              .at(i),
          value,
        );
        await settle();
      }

      bool surfaceConverted = false;
      Future<void> shot(String name) async {
        if (!surfaceConverted) {
          await binding.convertFlutterSurfaceToImage();
          surfaceConverted = true;
        }
        await tester.pump();
        await binding.takeScreenshot('0.4.0-$name');
      }

      Future<void> send(String text) async {
        await tester.enterText(find.byKey(const Key('goal-input')), text);
        await settle();
        final button = find.text('发送给规划助手');
        await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
        await settle();
        expect(button.hitTestable(), findsOneWidget);
        await tester.tap(button);
        await tester.runAsync(() async {
          for (var i = 0; i < 600; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            if (!app.agentWorking) return;
          }
          fail('Agent did not finish within 300 seconds.');
        });
        await settle();
        expect(find.text('正在思考…'), findsNothing);
        // On failure the input remains; assert success without printing secrets.
        expect(
          (tester
                  .widget<TextField>(find.byKey(const Key('goal-input')))
                  .controller!)
              .text,
          isEmpty,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .whereType<String>()
              .where(
                (t) =>
                    t.contains('失败') || t.contains('无效') || t.contains('未保存'),
              )
              .join(' | '),
        );
      }

      try {
        router.go('/plans');
        await tester.pumpWidget(
          UncontrolledProviderScope(container: c, child: const FocusNestApp()),
        );
        await settle();
        await tapFinder(find.byKey(const Key('view-goal')));
        await tap('新增总目标');
        await field(0, '模拟器总目标');
        await field(1, '20');
        await field(2, '项');
        await field(3, dateKey(clock.now().add(const Duration(days: 60))));
        await tap('保存目标');
        expect(c.read(appProvider).goals.single.title, '模拟器总目标');
        await tap('编辑目标');
        await field(0, '总目标已编辑');
        await tap('保存目标');
        expect(c.read(appProvider).goals.single.title, '总目标已编辑');
        await shot('goals');
        for (final level in ['week', 'month', 'quarter']) {
          await tapFinder(find.byKey(Key('view-$level')));
          await tap('新增${planLevelNames[level]}');
          await tester.enterText(
            find.byKey(const Key('period-title')),
            '模拟器${planLevelNames[level]}',
          );
          await tap('保存周期计划');
          expect(
            periodPlans(
              c.read(appProvider),
            ).where((p) => p.level == level).single.title,
            '模拟器${planLevelNames[level]}',
          );
          await tap('编辑周期');
          await tester.enterText(
            find.byKey(const Key('period-title')),
            '${planLevelNames[level]}已编辑',
          );
          await tap('保存周期计划');
          expect(
            periodPlans(
              c.read(appProvider),
            ).where((p) => p.level == level).single.title,
            '${planLevelNames[level]}已编辑',
          );
          await tester.enterText(find.byKey(const Key('task-search')), '不存在的词');
          await settle();
          expect(find.text('${planLevelNames[level]}已编辑'), findsNothing);
          await tester.enterText(find.byKey(const Key('task-search')), '已编辑');
          await settle();
          expect(find.text('${planLevelNames[level]}已编辑'), findsOneWidget);
          await shot(level);
          await tap('删除周期');
          await tap('删除');
          expect(
            periodPlans(c.read(appProvider)).where((p) => p.level == level),
            isEmpty,
          );
        }
        await tapFinder(find.byKey(const Key('view-day')));
        await tap('新增日计划');
        await field(0, '手动每日任务');
        await tap('保存计划');
        expect(c.read(appProvider).plans.single.title, '手动每日任务');
        await tap('编辑');
        await field(0, '每日任务已编辑');
        await tap('保存计划');
        final manual = c.read(appProvider).plans.single;
        await tapFinder(find.byKey(ValueKey('done-${manual.id}')));
        expect(c.read(appProvider).plans.single.done, true);
        await tapFinder(find.byKey(ValueKey('done-${manual.id}')));
        expect(c.read(appProvider).plans.single.done, false);
        await tapFinder(find.byTooltip('删除计划'));
        await tap('删除');
        expect(c.read(appProvider).plans, isEmpty);
        await tapFinder(find.byKey(const Key('view-goal')));
        await tap('删除目标');
        await tap('删除目标，保留任务');
        expect(c.read(appProvider).goals, isEmpty);
        if (live) {
          router.go('/agent');
          await settle();
          await send(
            '我想学习Python采集公开网页，已有Python基础，最终成果还没有想好，先帮我明确成果，暂时不要生成或保存计划。',
          );
          expect(c.read(appProvider).workspace.chat.length, 2);
          expect(
            c.read(appProvider).workspace.rounds,
            inInclusiveRange(0, 1),
            reason:
                'AI may suggest a concrete outcome or ask; the program must not require a question.',
          );
          expect(c.read(appProvider).plans, isEmpty);
          await send(
            '最终成果是采集公开示例页面的标题并导出CSV。我补充：从今天起三天，每天30分钟，19:00，明确只做公开授权页面，不做登录或反爬。现在直接创建并保存总目标、所在季度、月、周计划和3个不同的每日任务，不要草稿，也不用再问。',
          );
          expect(c.read(appProvider).workspace.rounds, 0);
          expect(c.read(appProvider).workspace.draft, isNull);
          expect(c.read(appProvider).plans.length, 3);
          expect(c.read(appProvider).goals.length, 1);
          expect(
            periodPlans(c.read(appProvider)).map((p) => p.level).toSet(),
            containsAll(['quarter', 'month', 'week']),
          );
          expect(
            c
                .read(appProvider)
                .plans
                .every((p) => p.minutes == 30 && p.time == '19:00'),
            true,
          );
          await shot('agent-created');
          final first = c.read(appProvider).plans.toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          final firstId = first.first.id;
          await send(
            '继续修改刚才的安排：把今天的每日任务改到明天20:30，时长45分钟，其他任务不变；并把周计划的成果改成“独立导出可复查的CSV”。请直接保存。',
          );
          final changed = c
              .read(appProvider)
              .plans
              .singleWhere((p) => p.id == firstId);
          expect(
            changed.date,
            dateKey(clock.now().add(const Duration(days: 1))),
          );
          expect(changed.time, '20:30');
          expect(changed.minutes, 45);
          expect(
            periodPlans(
              c.read(appProvider),
            ).singleWhere((p) => p.level == 'week').title,
            contains('CSV'),
          );
          await send('查询并告诉我现在这三个每日任务的日期、时间和时长，先不要修改。');
          expect(c.read(appProvider).plans.length, 3);
          final beforeDelete = planRevision(c.read(appProvider));
          await send('删掉那个任务。');
          expect(
            planRevision(c.read(appProvider)),
            beforeDelete,
            reason: 'ambiguous deletion must ask instead of guessing',
          );
          expect(c.read(appProvider).workspace.rounds, 1);
          await send('我指的是刚才调整为45分钟、20:30的那一个，只删除这个每日任务，保留目标、周期计划和其他任务。');
          expect(c.read(appProvider).plans.any((p) => p.id == firstId), false);
          expect(c.read(appProvider).plans.length, 2);
          final goalId = c.read(appProvider).goals.single.id;
          await send(
            '把这个总目标名称改成“公开网页CSV练习”，月计划成果改成“完成可重复运行的公开页面CSV项目”，季度成果改成“建立可复用的Python数据采集基础”。不要修改每日任务。',
          );
          expect(c.read(appProvider).goals.single.title, '公开网页CSV练习');
          expect(c.read(appProvider).goals.single.id, goalId);
          await repo.flush();
          final restored = await AndroidRepository.open(pristine);
          expect(restored.load().plans.length, 2);
          expect(periodPlans(restored.load()).length, 3);
          await shot('agent-managed');
          await send('现在删除“公开网页CSV练习”这个总目标，但保留全部每日任务作为独立任务。');
          expect(c.read(appProvider).goals, isEmpty);
          expect(periodPlans(c.read(appProvider)), isEmpty);
          expect(c.read(appProvider).plans.length, 2);
          expect(
            c.read(appProvider).plans.every((p) => p.goalId == null),
            true,
          );
          await send('删除剩余的两个未完成每日任务。');
          expect(c.read(appProvider).plans, isEmpty);
        }
        await repo.flush();
        expect(tester.takeException(), isNull);
        // No credentials, generated personal text, or device database in receipts.
        // The driver retains only synthetic emulator screenshots.
        // ignore: avoid_print
        print(
          'AGENT_MANAGEMENT_CHECKS: ${jsonEncode({'date': today, 'manualLevels': 5, 'liveNative': live, 'nativeRequests': tracked.completedRequests, 'status': 'passed'})}',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await repo.flush();
        await nativeChannel.invokeMethod<void>('save', {
          'snapshot': before ?? jsonEncode(encodeSnapshot(pristine)),
        });
        host.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
