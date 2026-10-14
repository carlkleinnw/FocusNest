import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
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
    final protection = ref.watch(protectionStatusProvider);
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
                    : '打开受限应用会显示锁定提醒，点击「知道了」返回桌面。不读取应用页面内容。电话、系统设置等必要应用始终允许。',
              ),
              if (!device.simulated) ...[
                const SizedBox(height: 12),
                protection.when(
                  loading: () => const Text('正在检查保护状态…'),
                  error: (_, _) => const Text('暂时无法检查保护状态'),
                  data: (p) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.ready
                            ? (p.active
                                  ? '本次专注保护已启用 · 限制${p.blockedCount}个应用'
                                  : '服务已连接 · 尚未开始应用保护')
                            : '保护服务未连接，请重新开启系统权限',
                      ),
                      if (state.focusing && !p.active)
                        const Text('当前计时与应用保护状态不一致'),
                      Text('已显示${p.reminders}次提醒'),
                      Text('收到${p.windowEvents}次切换通知'),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('复制诊断信息'),
                        onPressed: () async {
                          final fresh = await device.status();
                          await Clipboard.setData(
                            ClipboardData(text: jsonEncode(fresh.toJson())),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已复制保护状态，可发给开发者排查；不包含应用内容或应用名单'),
                              ),
                            );
                          }
                        },
                      ),
                      if (p.homeResult.isNotEmpty)
                        Text(
                          p.homeResult == 'HOME_ACCEPTED'
                              ? '最近返回桌面请求：系统已执行'
                              : '最近返回桌面请求：系统未执行',
                        ),
                      if (p.error.isNotEmpty) Text(p.error),
                    ],
                  ),
                ),
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
