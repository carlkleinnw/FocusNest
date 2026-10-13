import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../ui/components.dart';

class AppsPage extends ConsumerWidget {
  const AppsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final device = ref.read(deviceProvider);
    final catalog = ref.watch(appsProvider);
    return PageFrame(
      title: '把分心留在门外',
      subtitle: '开关开启表示允许使用。娱乐分类仅为初始建议，请确认名单。',
      action: IconButton(
        tooltip: '刷新应用列表',
        onPressed: state.focusing ? null : () => ref.invalidate(appsProvider),
        icon: const Icon(Icons.refresh),
      ),
      children: [
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(
                device.simulated
                    ? '网页模拟'
                    : state.protectionReady
                    ? '保护权限已开启'
                    : '保护未生效',
                warning: !device.simulated && !state.protectionReady,
              ),
              const SizedBox(height: 12),
              Text(
                device.simulated
                    ? '这里使用虚拟应用列表，真实拦截请在手机体验。'
                    : '专注时识别打开的应用，显示锁定提醒并返回桌面。不读取应用页面内容。电话、系统设置等必要应用始终允许。',
              ),
              if (!device.simulated) ...[
                const SizedBox(height: 12),
                MainButton(
                  '前往系统开启权限',
                  onPressed: () async {
                    try {
                      await device.openSettings();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请在系统无障碍设置中找到伴学小屋')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text('在系统设置找到「伴学小屋专注保护」并开启。关闭权限后保护会失效。'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (state.focusing) const Text('本次专注采用开始时确认的名单，结束后可调整。'),
        catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => EmptyPanel(
            title: '未能读取应用列表',
            body: '已有名单会保留。',
            action: MainButton(
              '重试',
              onPressed: () => ref.invalidate(appsProvider),
            ),
          ),
          data: (apps) => SurfacePanel(
            child: Column(
              children: [
                Text(
                  '已限制 ${apps.where((a) => state.blockedApps.contains(a.package)).length} 个应用',
                ),
                for (final app in apps)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(app.name),
                    subtitle: Text(
                      app.protected
                          ? '必要应用 · 始终允许'
                          : '${app.category} · ${state.blockedApps.contains(app.package) ? '专注时限制' : '允许使用'}',
                    ),
                    value: !state.blockedApps.contains(app.package),
                    onChanged: app.protected || state.focusing
                        ? null
                        : (_) => ref
                              .read(appProvider.notifier)
                              .toggleInstalledApp(app),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
