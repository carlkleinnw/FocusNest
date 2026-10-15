import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/models.dart';
import 'package:focus_pet_demo/core/protection_status.dart';
import 'package:focus_pet_demo/data/demo_adapters.dart';
import 'package:focus_pet_demo/main.dart';

class PermissionDevice extends SimulatedDevice {
  int settingsOpened = 0;
  bool readyNow = false;

  @override
  bool get simulated => false;

  @override
  Future<ProtectionStatus> status() async => ProtectionStatus(ready: readyNow);

  @override
  bool ready() => readyNow;

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}

void main() {
  testWidgets('first launch offers permission and respects refusal', (
    tester,
  ) async {
    final device = PermissionDevice();
    final container = ProviderContainer(
      overrides: [deviceProvider.overrideWithValue(device)],
    );
    router.go('/home');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FocusNestApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('开启专注保护？'), findsOneWidget);
    await tester.tap(find.text('暂不启用'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(appProvider).permissionPromptSeen, true);
    expect(device.settingsOpened, 0);
    expect(find.text('开启专注保护？'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('acceptance opens system settings once', (tester) async {
    final device = PermissionDevice();
    final container = ProviderContainer(
      overrides: [deviceProvider.overrideWithValue(device)],
    );
    router.go('/home');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FocusNestApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('去系统设置开启'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(device.settingsOpened, 1);
    expect(container.read(appProvider).permissionPromptSeen, true);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('late service connection is remembered without a new resume', (
    tester,
  ) async {
    final device = PermissionDevice();
    final clock = DemoClock();
    final container = ProviderContainer(
      overrides: [
        deviceProvider.overrideWithValue(device),
        clockProvider.overrideWithValue(clock),
      ],
    );
    router.go('/home');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FocusNestApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('暂不启用'));
    await tester.pump(const Duration(milliseconds: 400));
    device.readyNow = true;
    clock.advance(const Duration(seconds: 4));
    await container.read(appProvider.notifier).tick();
    expect(container.read(appProvider).permissionEverReady, true);
    expect(container.read(appProvider).permissionRecoveryPromptSeen, false);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('lost permission during focus is requested again', (
    tester,
  ) async {
    final device = PermissionDevice()..readyNow = true;
    final container = ProviderContainer(
      overrides: [deviceProvider.overrideWithValue(device)],
    );
    router.go('/home');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FocusNestApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(container.read(appProvider).permissionEverReady, true);
    expect(find.text('开启专注保护？'), findsNothing);
    final started = await container
        .read(appProvider.notifier)
        .start(
          const Plan(
            id: 'permission-test',
            title: '测试专注',
            minutes: 30,
            time: '12:00',
          ),
        );
    expect(started.ok, true);

    device.readyNow = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('专注保护已关闭'), findsOneWidget);
    await tester.tap(find.text('暂不启用'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(appProvider).permissionRecoveryPromptSeen, true);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('专注保护已关闭'), findsNothing);

    device.readyNow = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));
    expect(container.read(appProvider).permissionRecoveryPromptSeen, false);

    device.readyNow = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('专注保护已关闭'), findsOneWidget);
    await tester.tap(find.text('去系统设置开启'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(device.settingsOpened, 1);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets(
    'lost permission while idle uses the page status instead of a dialog',
    (tester) async {
      final device = PermissionDevice()..readyNow = true;
      final container = ProviderContainer(
        overrides: [deviceProvider.overrideWithValue(device)],
      );
      router.go('/home');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FocusNestApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(container.read(appProvider).permissionEverReady, true);
      device.readyNow = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('专注保护已关闭'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
