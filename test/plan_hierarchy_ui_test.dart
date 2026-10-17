import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_pet_demo/main.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/journal.dart';
import 'package:focus_pet_demo/core/plan_management.dart';
import 'package:focus_pet_demo/data/demo_adapters.dart';
import 'plan_agent_tools_test.dart' show hierarchy;
import 'planning_test.dart' show TestClock;
import 'core_planner_test.dart' show initial;

void main() {
  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'five separate plan levels fit width $width and survive large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final clock = TestClock(DateTime(2026, 10, 17));
        final state = applyPlanActions(
          initial(clock.now(), workspace: Workspace()),
          hierarchy(),
          'ui',
        ).state;
        final repo = MemoryRepository(clock)..save(state);
        final c = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(clock),
            repositoryProvider.overrideWithValue(repo),
          ],
        );
        router.go('/plans');
        await tester.pumpWidget(
          UncontrolledProviderScope(container: c, child: const FocusNestApp()),
        );
        await tester.pumpAndSettle();
        for (final level in ['day', 'week', 'month', 'quarter', 'goal']) {
          final tab = find.byKey(Key('view-$level'));
          await tester.ensureVisible(tab);
          await tester.tap(tab);
          await tester.pumpAndSettle();
          expect(tester.widget<ChoiceChip>(tab).selected, true);
          if (level == 'day') {
            expect(find.text('解析公开页面标题'), findsOneWidget);
            expect(find.text('week 成果'), findsNothing);
          } else if (level == 'goal') {
            expect(find.text('Python采集'), findsOneWidget);
            expect(find.text('week 成果'), findsNothing);
          } else {
            expect(find.text('$level 成果'), findsOneWidget);
            expect(
              find.text('解析公开页面标题'),
              findsNothing,
              reason: 'daily detail stays collapsed',
            );
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
}
