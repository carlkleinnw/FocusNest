import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/models.dart';
import 'package:focus_pet_demo/main.dart';

void main() {
  testWidgets(
    'system back shares two-step emergency exit and cancellation is safe',
    (tester) async {
      final container = ProviderContainer();
      await container
          .read(appProvider.notifier)
          .start(
            const Plan(id: 'back', title: '阅读教材', minutes: 30, time: '09:00'),
          );
      router.go('/focus');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FocusNestApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('确认 1 / 2'), findsOneWidget);
      await tester.tap(find.text('仍要退出'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('确认 2 / 2'), findsOneWidget);
      await tester.tap(find.text('返回专注'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(appProvider).focusing, true);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('仍要退出'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('确认结束'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(appProvider).focusing, false);
      expect(
        container.read(appProvider).session!.status,
        FocusStatus.cancelled,
      );
      expect(container.read(appProvider).pet.meals, 8);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
