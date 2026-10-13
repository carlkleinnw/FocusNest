import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/main.dart';

void main() {
  testWidgets(
    'goal, stage and daily task editors link actual progress and expose errors',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = ProviderContainer();
      router.go('/goals');
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const FocusNestApp()),
      );
      Future<void> tap(String text) async {
        final target = find.text(text).last;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<void> fill(List<String> values) async {
        for (var i = 0; i < values.length; i++) {
          await tester.enterText(find.byType(TextField).at(i), values[i]);
          await tester.pump();
        }
      }

      await tester.pump(const Duration(milliseconds: 500));
      await tap('新增长期目标');
      await tap('保存目标');
      expect(find.text('请输入目标、未来截止日期和有效任务数量'), findsOneWidget);
      await fill(['导数专题', '20', '题', '2026-11-13']);
      await tap('保存目标');
      expect(c.read(appProvider).goals.single.title, '导数专题');
      await tap('查看阶段与任务');
      await tap('新增阶段');
      await fill(['第一阶段', '5', '2026-10-20']);
      await tap('保存阶段');
      await tap('安排阶段任务');
      await fill(['练习三道题', '3', '30', '2026-10-13', '19:45']);
      await tap('保存计划');
      final task = c.read(appProvider).plans.last;
      expect(task.goalId, c.read(appProvider).goals.single.id);
      expect(task.milestoneId, c.read(appProvider).milestones.single.id);
      router.go('/plans');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tap('记录完成量');
      await fill(['2']);
      await tap('保存进度');
      expect(c.read(appProvider).plans.last.doneUnits, 2);
      expect(c.read(appProvider).pet.meals, 8);
      router.go('/goals');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('2 / 20'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
