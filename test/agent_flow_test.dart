import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_pet_demo/main.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/journal.dart';
import 'package:focus_pet_demo/core/models.dart';
import 'package:focus_pet_demo/data/demo_adapters.dart';

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets('AI conversation, preview and save at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final clock = DemoClock();
      final repo = MemoryRepository(clock)
        ..save(
          AppState(
            now: clock.now(),
            pet: const PetState(),
            plans: [],
            records: [],
            workspace: Workspace(demoAgent: true),
          ),
        );
      final c = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          repositoryProvider.overrideWithValue(repo),
        ],
      );
      router.go('/agent');
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const FocusNestApp()),
      );
      Future<void> tap(String text) async {
        final f = find.text(text).last;
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('goal-input')), '学Python');
      await tap('发送给规划助手');
      expect(c.read(appProvider).workspace.rounds, 1);
      await tester.enterText(find.byKey(const Key('goal-input')), '每天30分钟，有基础');
      await tap('发送给规划助手');
      expect(c.read(appProvider).workspace.draft, isNotNull);
      await tap('确认并保存到计划表');
      expect(c.read(appProvider).plans.length, 7);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
