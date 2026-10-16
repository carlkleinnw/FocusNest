import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:focus_pet_demo/main.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/models.dart';
import 'package:focus_pet_demo/core/journal.dart';
import 'package:focus_pet_demo/core/planner_agent.dart';
import 'package:focus_pet_demo/data/android_adapters.dart';
import 'package:focus_pet_demo/data/planner_gateway.dart';
import 'package:focus_pet_demo/data/snapshot_codec.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android end-to-end core workflow and encrypted settings', (
    tester,
  ) async {
    // Synthetic text entry must own TextInput; the emulator IME otherwise
    // sends delayed empty updates over tester.enterText's simulated input.
    tester.testTextInput.register();
    final clock = RealClock();
    // The host test runner enables the accessibility service on this emulator
    // after Flutter installs the test APK. Production code never grants it.
    final protectionReady = await tester.runAsync(() async {
      for (var i = 0; i < 60; i++) {
        if (await AndroidDevice().ready()) return true;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      return false;
    });
    expect(
      protectionReady,
      true,
      reason:
          'Enable accessibility on the emulator before running native focus tests.',
    );
    final gateway = AndroidPlannerGateway();
    final settings = await gateway.settings();
    expect(settings.containsKey('key'), false);
    // Only test an empty emulator account; never replace existing credentials.
    if (settings['configured'] != true) {
      const fake = 'focusnest-integration-placeholder-no-real-key';
      await gateway.configure(
        key: fake,
        model: 'deepseek-flash',
        remove: false,
      );
      expect((await gateway.settings())['configured'], true);
      final prefs = File(
        '/data/user/0/cn.focusnest.focus_pet_demo/shared_prefs/planner_secret_v1.xml',
      );
      final encrypted = await prefs.readAsString();
      expect(encrypted.contains(fake), false);
      expect(encrypted.contains('ciphertext'), true);
      await gateway.configure(key: '', model: 'deepseek-flash', remove: true);
      expect((await gateway.settings())['configured'], false);
      await expectLater(
        gateway.request([
          {'role': 'user', 'content': 'test'},
        ]),
        throwsA(isA<AgentFailure>()),
      );
    }
    final before = await nativeChannel.invokeMethod<String>('load');
    final today = dateKey(clock.now());
    final pristine = AppState(
      now: clock.now(),
      pet: const PetState(),
      plans: [],
      records: [],
      permissionPromptSeen: true,
    );
    if (before != null) {
      expect(
        decodeSnapshot(jsonDecode(before) as Map<String, dynamic>).focusing,
        false,
        reason: 'do not replace an active emulator session',
      );
    }
    final repo = AndroidRepository(pristine);
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        repositoryProvider.overrideWithValue(repo),
        deviceProvider.overrideWithValue(AndroidDevice()),
      ],
    );
    Future<void> settle() async {
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }

    Future<void> tap(String text) async {
      final f = find.text(text).last;
      await tester.ensureVisible(f);
      await settle();
      await tester.tap(f);
      await settle();
      await tester.pump(const Duration(milliseconds: 600));
      await settle();
    }

    bool surfaceConverted = false;
    Future<void> shot(String name) async {
      if (!surfaceConverted) {
        await binding.convertFlutterSurfaceToImage();
        surfaceConverted = true;
      }
      await tester.pump();
      await binding.takeScreenshot(name);
    }

    ProviderContainer? historical;
    AndroidRepository? historicalRepo;
    try {
      router.go('/settings');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FocusNestApp(),
        ),
      );
      await settle();
      expect(find.byKey(const Key('api-key')), findsOneWidget);
      await shot('01-settings');
      final app = container.read(appProvider.notifier);
      expect(app.setWorkspaceOptions(demoAgent: true).ok, true);
      router.go('/agent');
      await settle();
      await tester.enterText(
        find.byKey(const Key('goal-input')),
        '学习Python数据采集',
      );
      await tap('发送给规划助手');
      expect(container.read(appProvider).workspace.rounds, 1);
      await tester.enterText(
        find.byKey(const Key('goal-input')),
        '已有基础，每天30分钟，一周完成项目',
      );
      await tap('发送给规划助手');
      if (container.read(appProvider).workspace.draft == null) {
        await shot('02-draft-failure');
      }
      expect(
        container.read(appProvider).workspace.draft,
        isNotNull,
        reason: container.read(appProvider).workspace.chat.toString(),
      );
      await shot('02-agent-draft');
      await tap('确认并保存到计划表');
      expect(container.read(appProvider).plans.length, 7);
      expect(container.read(appProvider).workspace.draft, isNull);
      await shot('03-plans');
      // Real native SQLite persistence, including the imported hierarchy.
      await repo.flush();
      final loaded = await AndroidRepository.open(pristine);
      expect(loaded.load().plans.length, 7);
      expect(loaded.load().workspace.roadmaps.length, 1);
      expect(
        app
            .upsertPlan(
              Plan(
                id: 'emulator_task',
                title: '模拟器任务编辑',
                minutes: 30,
                time: '12:00',
                date: today,
              ),
            )
            .ok,
        true,
      );
      router.go('/plans');
      await settle();
      await tap('编辑');
      final dialogFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogFields.first, '编辑完成的任务');
      await tap('保存计划');
      expect(container.read(appProvider).plans.last.title, '编辑完成的任务');
      await tester.ensureVisible(
        find.byKey(const ValueKey('done-emulator_task')),
      );
      await tester.tap(find.byKey(const ValueKey('done-emulator_task')));
      await settle();
      expect(container.read(appProvider).plans.last.completedAt, isNotNull);
      await tester.tap(find.byKey(const ValueKey('done-emulator_task')));
      await settle();
      // Task entry and free focus share the same native session engine.
      await tap('进入沉浸');
      expect(find.text('模拟器任务编辑'), findsNothing);
      await tap('自定义');
      await tester.enterText(find.byKey(const Key('custom-minutes')), '37');
      await tap('使用此时长');
      await shot('04-focus-custom');
      await tap('确认并开始专注');
      expect(container.read(appProvider).focusing, true);
      expect(container.read(appProvider).session!.minutes, 37);
      expect(container.read(appProvider).session!.planId, 'emulator_task');
      await shot('05-focus-running');
      await tap('提前结束');
      await tap('仍要退出');
      await tap('确认结束');
      expect(container.read(appProvider).focusing, false);
      expect(container.read(appProvider).records.first.completed, false);
      app.dismissSession();
      router.go('/focus');
      await settle();
      await tester.enterText(find.byKey(const Key('focus-title')), '独立专注');
      await tap('确认并开始专注');
      expect(container.read(appProvider).session!.planId, isNull);
      await tap('提前结束');
      await tap('仍要退出');
      await tap('确认结束');
      app.dismissSession();
      router.go('/plans');
      await settle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('done-emulator_task')),
      );
      await tester.tap(find.byKey(const ValueKey('done-emulator_task')));
      await settle();
      router.go('/records');
      await settle();
      // A task completion and its focus attempt are intentionally separate rows.
      expect(find.text('编辑完成的任务'), findsNWidgets(2));
      await shot('06-review');
      router.go('/plans');
      await settle();
      await tester.tap(find.byTooltip('删除计划').last);
      await settle();
      await tap('删除');
      expect(
        container.read(appProvider).plans.any((p) => p.id == 'emulator_task'),
        false,
      );
      final historicalState = AppState(
        now: clock.now(),
        pet: const PetState(),
        plans: [
          const Plan(
            id: 'history_task',
            title: '完成数据采集练习（测试样例）',
            minutes: 30,
            time: '09:00',
            date: '2025-12-31',
            doneUnits: 1,
            completedAt: '2025-12-31T12:00:00',
          ),
        ],
        records: [
          FocusRecord(
            id: 'history_focus',
            title: '数据采集练习（测试样例）',
            minutes: 30,
            at: DateTime(2025, 12, 31, 12),
            completed: true,
          ),
        ],
        workspace: Workspace(demoAgent: true),
        permissionPromptSeen: true,
      );
      historicalRepo = AndroidRepository(historicalState);
      historical = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          repositoryProvider.overrideWithValue(historicalRepo),
          deviceProvider.overrideWithValue(AndroidDevice()),
        ],
      );
      final reviewResult = await historical
          .read(appProvider.notifier)
          .summarizeDue();
      expect(reviewResult.ok, true);
      expect(
        historical.read(appProvider).workspace.reviews.single.level,
        'year',
      );
      expect(historical.read(appProvider).workspace.reviews.single.tasks, 1);
      expect(historical.read(appProvider).workspace.reviews.single.minutes, 30);
      expect(historical.read(appProvider).plans, isEmpty);
      await historicalRepo.flush();
      expect(
        (await AndroidRepository.open(
          pristine,
        )).load().workspace.reviews.single.level,
        'year',
      );
      router.go('/records');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          key: UniqueKey(),
          container: historical,
          child: const FocusNestApp(),
        ),
      );
      await settle();
      await shot('07-year-review');
      expect(tester.takeException(), isNull);
    } finally {
      if (container.read(appProvider).focusing) {
        await container.read(appProvider.notifier).cancelFocus();
      }
      await repo.flush();
      await tester.pumpWidget(const SizedBox());
      if (historicalRepo != null) await historicalRepo.flush();
      historical?.dispose();
      container.dispose();
      await nativeChannel.invokeMethod<void>('save', {
        'snapshot': before ?? jsonEncode(encodeSnapshot(pristine)),
      });
    }
  });
}
