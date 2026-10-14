import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/protection_status.dart';
import 'package:focus_pet_demo/data/demo_adapters.dart';
import 'package:focus_pet_demo/main.dart';

class PermissionDevice extends SimulatedDevice {
  int settingsOpened = 0;

  @override
  bool get simulated => false;

  @override
  Future<ProtectionStatus> status() async =>
      const ProtectionStatus(ready: false);

  @override
  bool ready() => false;

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
}
