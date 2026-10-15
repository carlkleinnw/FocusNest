import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_pet_demo/core/planning.dart';
import 'package:focus_pet_demo/ui/app_picker_dialog.dart';

void main() {
  testWidgets('picker adds multiple apps without changing the existing list', (
    tester,
  ) async {
    List<InstalledApp>? result;
    const apps = [
      InstalledApp(package: 'demo.course', name: '课程平台', category: '学习'),
      InstalledApp(package: 'demo.dictionary', name: '词典', category: '学习'),
      InstalledApp(package: 'demo.video', name: '视频', category: '视频'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showDialog<List<InstalledApp>>(
                    context: context,
                    builder: (_) => const AppPickerDialog(apps: apps),
                  ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('课程平台'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick-demo.course')));
    await tester.tap(find.byKey(const Key('pick-demo.dictionary')));
    await tester.pump();
    expect(find.text('已选 2 个'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('app-picker-search')), '视频');
    await tester.pump();
    expect(find.text('视频'), findsWidgets);
    expect(find.text('课程平台'), findsNothing);
    await tester.tap(find.byKey(const Key('confirm-app-picker')));
    await tester.pumpAndSettle();
    expect(result?.map((a) => a.package).toSet(), {
      'demo.course',
      'demo.dictionary',
    });
  });
}
