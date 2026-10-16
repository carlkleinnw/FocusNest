import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_pet_demo/core/controller.dart';
import 'package:focus_pet_demo/core/planner_agent.dart';
import 'package:focus_pet_demo/pages/settings_page.dart';

class ConfigurationFixture implements PlannerGateway, SavedKeyReader {
  bool configured = false;
  int requests = 0;
  bool rejectConfiguration = false;
  String savedKey = '';
  int reads = 0;
  @override
  Future<String> readSavedKey() async {
    reads++;
    return savedKey;
  }

  @override
  Future<Map<String, dynamic>> settings() async => {
    'configured': configured,
    'model': 'deepseek-flash',
  };
  @override
  Future<void> configure({
    required String key,
    required String model,
    required bool remove,
  }) async {
    if (rejectConfiguration) {
      throw const AgentFailure('当前页面没有本地 AI 配置接口，请使用新版启动器打开设置页。');
    }
    if (remove) {
      configured = false;
      savedKey = '';
    } else if (key.isNotEmpty) {
      configured = true;
      savedKey = key;
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    List<Map<String, String>> messages,
  ) async {
    requests++;
    throw StateError('Saving configuration must never call AI.');
  }
}

void main() {
  testWidgets('save failure explains the configuration service error', (
    tester,
  ) async {
    final gateway = ConfigurationFixture()..rejectConfiguration = true;
    final c = ProviderContainer(
      overrides: [plannerGatewayProvider.overrideWithValue(gateway)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('api-key')),
      'fixture-placeholder',
    );
    await tester.ensureVisible(find.text('保存 API 配置'));
    await tester.tap(find.text('保存 API 配置'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败：当前页面没有本地 AI 配置接口，请使用新版启动器打开设置页。'), findsOneWidget);
    expect(gateway.requests, 0);
    expect(gateway.configured, false);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  for (final width in [390.0, 1100.0]) {
    testWidgets(
      'settings accepts, saves and removes a fixture without AI at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gateway = ConfigurationFixture();
        final c = ProviderContainer(
          overrides: [plannerGatewayProvider.overrideWithValue(gateway)],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: const MaterialApp(home: Scaffold(body: SettingsPage())),
          ),
        );
        await tester.pumpAndSettle();
        final input = find.byKey(const Key('api-key'));
        expect(tester.widget<TextField>(input).enabled, true);
        await tester.enterText(input, 'fixture-placeholder-not-a-real-key');
        final save = find.text('保存 API 配置');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(gateway.configured, true);
        expect(gateway.requests, 0);
        expect(tester.widget<TextField>(input).controller!.text, isEmpty);
        expect(
          tester.widget<TextField>(input).decoration!.hintText,
          '••••••••••••••••',
        );
        expect(gateway.reads, 0);
        await tester.ensureVisible(find.byTooltip('显示密钥'));
        await tester.tap(find.byTooltip('显示密钥'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(input).obscureText, false);
        expect(
          tester.widget<TextField>(input).controller!.text,
          'fixture-placeholder-not-a-real-key',
        );
        expect(gateway.reads, 1);
        await tester.tap(find.byTooltip('隐藏密钥'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(input).obscureText, true);
        if (kIsWeb) {
          expect(c.read(appProvider).workspace.demoAgent, false);
          expect(c.read(appProvider).workspace.autoReview, false);
          expect(find.text('密钥已保存在本地服务内存中，尚未测试连接。'), findsOneWidget);
        }
        await tester.tap(find.text('移除密钥'));
        await tester.pumpAndSettle();
        expect(gateway.configured, false);
        expect(gateway.requests, 0);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
}
