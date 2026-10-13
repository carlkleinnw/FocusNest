import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class AppsPage extends ConsumerWidget {
  const AppsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    const apps = [
      ('课程平台', '听课与学习', Icons.school_outlined),
      ('词典', '查词与翻译', Icons.translate),
      ('浏览器', '查资料，也可能分心', Icons.public),
      ('视频平台', '课程与娱乐混合', Icons.ondemand_video),
      ('短视频', '娱乐与推荐内容', Icons.smart_display_outlined),
      ('游戏', '休闲娱乐', Icons.sports_esports_outlined),
      ('电话', '必要通讯，始终保留', Icons.phone_outlined),
    ];
    return PageFrame(
      title: '留下学习需要的工具',
      subtitle: '打开开关表示专注时允许使用。这里的应用列表与拦截效果均为模拟。',
      eyebrow: 'MAKE ROOM FOR WHAT MATTERS',
      children: [
        SurfacePanel(
          child: Column(
            children: apps
                .map(
                  (app) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: Icon(app.$3, color: NestColors.green),
                    title: Text(app.$1),
                    subtitle: Text(
                      app.$2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Switch(
                      value: state.allowedApps.contains(app.$1),
                      onChanged: state.focusing || app.$1 == '电话'
                          ? null
                          : (_) => ref
                                .read(appProvider.notifier)
                                .toggleApp(app.$1),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '同一应用中的课程与娱乐，应用白名单无法区分。第一版先让你体验按应用选择的方式。',
          style: TextStyle(fontSize: 12, color: NestColors.muted),
        ),
      ],
    );
  }
}
