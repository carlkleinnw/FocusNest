import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/models.dart';
import 'package:focus_pet_demo/core/ports.dart';

void main() {
  late ProviderContainer container;
  late AppController app;
  const plan = Plan(id: 'test', title: '阅读教材', minutes: 30, time: '09:00');
  setUp(() {
    container = ProviderContainer();
    app = container.read(appProvider.notifier);
  });
  tearDown(() => container.dispose());
  test('setting a rest date twice is safe for future Agent retries', () async {
    final day = container.read(appProvider).now.add(const Duration(days: 1));
    final actions = container.read(actionsProvider);
    expect(actions.setRest(day, true).ok, true);
    expect(actions.setRest(day, true).ok, true);
    expect(container.read(appProvider).restDates.contains(dateKey(day)), true);
  });
  test('reject sessions under 30 minutes', () async {
    expect(
      (await app.start(
        const Plan(id: 'short', title: '过短任务', minutes: 29, time: '09:00'),
      )).ok,
      false,
    );
    expect(container.read(appProvider).focusing, false);
  });
  test('deadline feeds once even when repeatedly ticked', () async {
    await app.start(plan);
    await app.advanceMinutes(29);
    expect(container.read(appProvider).pet.meals, 8);
    await app.advanceMinutes(1);
    expect(container.read(appProvider).session!.status, FocusStatus.completed);
    expect(container.read(appProvider).pet.meals, 9);
    await app.tick();
    await app.tick();
    expect(container.read(appProvider).pet.meals, 9);
    expect(container.read(appProvider).records.first.virtual, true);
  });
  test(
    '30 minutes of a 60 minute session gives no reward if cancelled',
    () async {
      await app.start(
        const Plan(id: 'long', title: '长任务', minutes: 60, time: '10:00'),
      );
      await app.advanceMinutes(30);
      await app.cancelFocus();
      expect(container.read(appProvider).pet.meals, 8);
      expect(container.read(appProvider).todayFed, false);
      expect(container.read(appProvider).records.first.completed, false);
    },
  );
  test('future rest freezes hunger, today and past cannot be edited', () async {
    final today = container.read(appProvider).now;
    expect(app.toggleRest(today).ok, false);
    expect(app.toggleRest(today.subtract(const Duration(days: 1))).ok, false);
    app.toggleRest(today.add(const Duration(days: 1)));
    await app.advanceDay();
    expect(container.read(appProvider).pet.hungryDays, 1);
    await app.advanceDay();
    expect(container.read(appProvider).pet.hungryDays, 1);
  });
  test(
    'legacy pet state never blocks learning; adoption keeps its old gate',
    () async {
      for (var i = 0; i < 7; i++) {
        await app.advanceDay();
      }
      expect(container.read(appProvider).pet.dead, true);
      expect(app.adopt('小满', 0).ok, false);
      expect((await app.start(plan)).ok, true);
      await app.cancelFocus();
      app.dismissSession();
      final count = container.read(appProvider).records.length;
      await app.start(plan, restart: true);
      await app.advanceMinutes(30);
      expect(container.read(appProvider).adoptionReady, true);
      expect(app.adopt('小满', 1).ok, true);
      final state = container.read(appProvider);
      expect(state.pet.dead, false);
      expect(state.pet.meals, 1);
      expect(state.pet.generation, 2);
      expect(state.memorials.length, 1);
      expect(state.records.length, count + 1);
      expect(app.adopt('第三只', 0).ok, false);
    },
  );
  test('interaction never feeds, active focus prevents changes', () async {
    app.interact('pet');
    expect(container.read(appProvider).pet.meals, 8);
    await app.start(plan);
    expect((await app.advanceDay()).ok, false);
    expect(
      app
          .toggleRest(
            container.read(appProvider).now.add(const Duration(days: 1)),
          )
          .ok,
      false,
    );
    final ActionPort actions = container.read(actionsProvider);
    expect(
      actions
          .upsertPlan(
            const Plan(id: 'bad', title: '', minutes: 30, time: '09:00'),
          )
          .ok,
      false,
    );
  });
}
