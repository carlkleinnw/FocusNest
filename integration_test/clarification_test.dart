import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:focus_pet_demo/main.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/models.dart';
import 'package:focus_pet_demo/data/android_adapters.dart';
import 'package:focus_pet_demo/data/planner_gateway.dart';
import 'package:focus_pet_demo/data/snapshot_codec.dart';
import 'host_planner_gateway.dart';

/// Deterministic responses isolate the controller regression from model choices.
class ClarificationFixture extends DemoPlannerGateway {
  ClarificationFixture(super.today);
  @override
  Future<Map<String, dynamic>> request(
    List<Map<String, String>> messages,
  ) async {
    final chat =
        (jsonDecode(messages.last['content']!) as Map)['conversation'] as List;
    if (!(chat.last['content'] as String).contains('需求明确了')) {
      return {
        'kind': 'question',
        'question': '还需要明确的关键条件 ${(chat.length + 1) ~/ 2}？',
      };
    }
    return super.request(messages);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final live in [false, true]) {
    testWidgets(
      'six clarification rounds, SQLite reload and plan preview (live=$live)',
      (tester) async {
        tester.testTextInput.register();
        final clock = RealClock();
        final initial = AppState(
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
            reason: 'Never replace an active focus session.',
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
        final tracked = TrackedPlannerGateway(
          live ? native : ClarificationFixture(dateKey(clock.now())),
        );
        var repo = AndroidRepository(initial);
        ProviderContainer container() => ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(clock),
            repositoryProvider.overrideWithValue(repo),
            deviceProvider.overrideWithValue(AndroidDevice()),
            plannerGatewayProvider.overrideWithValue(tracked),
          ],
        );
        var c = container();
        Future<void> mount() async {
          router.go('/agent');
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: c,
              child: const FocusNestApp(),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> tap(String label) async {
          final f = find.text(label).last;
          await tester.ensureVisible(f);
          await tester.pumpAndSettle();
          await tester.tap(f);
          await tester.pumpAndSettle();
        }

        Future<void> send(String input) async {
          await tester.enterText(find.byKey(const Key('goal-input')), input);
          await tap('发送给规划助手');
          await tester.runAsync(() async {
            for (var i = 0; i < 600; i++) {
              if (!c.read(appProvider.notifier).agentWorking) return;
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
            fail('Planner request timed out.');
          });
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('goal-input')))
                .controller!
                .text,
            isEmpty,
            reason: 'Input remains on failure.',
          );
          await tester.runAsync(() => repo.flush());
          expect(repo.error, isNull);
        }

        try {
          await mount();
          const turns = [
            '我想学Python做一个公开网页数据采集项目，目标叫Clarify CSV。成果和限制都还没有完全明确，现在只讨论需求，不要生成或保存计划。我会逐步补充，未明确前每次请追问一个关键问题。',
            '我只有一点Python基础，希望先做小项目，具体产物还没决定，继续问一个最关键的问题，先不要计划。',
            '最后希望导出CSV，但采哪些内容、练习范围和时间都还没有定好，继续追问一个关键问题。',
            '只采集公开授权示例页面，不处理登录和反爬。字段和具体安排还没有明确，继续追问一个关键问题。',
            'CSV只需要页面标题和链接，具体时间和验收方式还没有想好，请继续追问一个关键问题，不要生成计划。',
            '验收时能运行脚本并得到含标题和链接的CSV就行，但日程尚未确定，请继续追问日程中的一个关键问题。',
          ];
          for (var i = 0; i < turns.length; i++) {
            await send(turns[i]);
            final w = c.read(appProvider).workspace;
            expect(w.rounds, i + 1);
            expect(w.chat.length, (i + 1) * 2);
            expect(w.chat.first['content'], turns.first);
            expect(w.draft, isNull);
            expect(c.read(appProvider).plans, isEmpty);
            if (i == 3) {
              await tester.pumpWidget(const SizedBox());
              c.dispose();
              repo = await AndroidRepository.open(initial);
              c = container();
              await mount();
              expect(c.read(appProvider).workspace.rounds, 4);
              expect(c.read(appProvider).workspace.chat.length, 8);
            }
          }
          await send(
            '需求明确了：Clarify CSV，已有Python基础，只采集公开授权示例页面的标题和链接并导出CSV，不涉及登录反爬。从明天起连续两天，每天30分钟，19:00，每天一项不同任务。能运行并输出CSV作为验收。请先预览完整月、周、日计划，其他非关键细节可自行决定，不再提问，也不要直接保存。',
          );
          expect(c.read(appProvider).workspace.rounds, 0);
          expect(c.read(appProvider).workspace.draft, isNotNull);
          expect(c.read(appProvider).plans, isEmpty);
          if (live) {
            expect(
              c.read(appProvider).workspace.draft!['title'],
              contains('Clarify CSV'),
            );
            expect(c.read(appProvider).workspace.draft!['tasks'], hasLength(2));
          }
          await tap('确认并保存到计划表');
          expect(c.read(appProvider).plans, isNotEmpty);
          await tester.runAsync(() => repo.flush());
          final restored = await AndroidRepository.open(initial);
          expect(
            restored.load().plans.length,
            c.read(appProvider).plans.length,
          );
          expect(restored.load().workspace.chat.first['content'], turns.first);
          await binding.convertFlutterSurfaceToImage();
          await tester.pump();
          await binding.takeScreenshot('0.4.1-clarification-live-$live');
          expect(tester.takeException(), isNull);
          // Only synthetic scenario counts, never credentials or request bodies.
          // ignore: avoid_print
          print(
            'CLARIFICATION_CHECKS: ${jsonEncode({'liveNative': live, 'questions': 6, 'requests': tracked.completedRequests, 'reloadAfterRound': 4, 'previewAndImport': true, 'status': 'passed'})}',
          );
        } finally {
          await tester.pumpWidget(const SizedBox());
          c.dispose();
          await repo.flush();
          host.close();
          await nativeChannel.invokeMethod<void>('save', {
            'snapshot': before ?? jsonEncode(encodeSnapshot(initial)),
          });
        }
      },
      skip: live && !const bool.fromEnvironment('LIVE_AGENT'),
      timeout: const Timeout(Duration(minutes: 20)),
    );
  }
}
