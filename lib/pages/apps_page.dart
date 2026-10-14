import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../ui/components.dart';

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final device = ref.read(deviceProvider);
    final catalog = ref.watch(appsProvider);
    final protection = ref.watch(protectionStatusProvider);
    return PageFrame(
      title: '把分心留在门外',
      subtitle: '应用默认受限。只将专注时确实需要的应用加入白名单。',
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
                    : '打开未加入白名单的应用会显示锁定提醒，点击「知道了」返回桌面。只读取窗口所属应用标识，不读取页面文字、输入内容或截图。电话、系统设置等必要应用始终允许。',
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
                      Text('提醒已获得前台焦点${p.reminders}次'),
                      Text('收到${p.windowEvents}次切换通知'),
                      Text('已核对前台窗口${p.foregroundChecks}次'),
                      if (p.active)
                        Text(
                          p.backgroundRunning
                              ? '后台保护正在运行'
                              : '后台保护未运行，离开小屋后可能漏拦截',
                        ),
                      if (p.active && !p.windowAccess)
                        const Text('当前缺少窗口识别能力，需重新开启新版保护服务'),
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
                          p.homeResult == 'HOME_VERIFIED'
                              ? '已确认返回桌面'
                              : p.homeResult == 'HOME_ACCEPTED'
                              ? '系统已接受返回桌面请求，等待核实'
                              : '系统未接受返回桌面请求',
                        ),
                      if (p.error.isNotEmpty) Text(p.error),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                MainButton(
                  '管理系统保护权限',
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
                const Text(
                  '在系统设置找到「伴学小屋专注保护」，可开启或关闭。系统需授予窗口访问能力，应用只取所属应用标识。拒绝或关闭后仍可使用计划和小屋，但无法开始受保护的专注。',
                ),
                const SizedBox(height: 16),
                const Text(
                  '如果离开小屋后不再拦截，请在应用信息里将「省电策略」设为「无限制／不限制」，让专注保护能持续运行。专注期间提供后台保护通知。',
                ),
                const SizedBox(height: 8),
                MainButton(
                  '检查后台运行设置',
                  onPressed: () async {
                    try {
                      await device.openBackgroundSettings();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请在系统的伴学小屋应用信息中检查省电策略')),
                        );
                      }
                    }
                  },
                ),
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
                  '已限制 ${apps.where((a) => !a.protected && !state.allowedApps.contains(a.package)).length} 个应用',
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: '搜索应用',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                for (final app in apps.where(
                  (a) =>
                      query.isEmpty ||
                      a.name.toLowerCase().contains(query) ||
                      a.package.toLowerCase().contains(query),
                ))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(app.name),
                    subtitle: Text(
                      app.protected
                          ? '必要应用 · 始终允许'
                          : '${app.category} · ${state.allowedApps.contains(app.package) ? '专注时允许' : '专注时限制'}',
                    ),
                    value:
                        app.protected ||
                        state.allowedApps.contains(app.package),
                    onChanged: app.protected || state.focusing
                        ? null
                        : (_) => ref
                              .read(appProvider.notifier)
                              .toggleInstalledApp(app),
                  ),
                if (query.isNotEmpty &&
                    !apps.any(
                      (a) =>
                          a.name.toLowerCase().contains(query) ||
                          a.package.toLowerCase().contains(query),
                    ))
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('没有找到匹配的应用'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
