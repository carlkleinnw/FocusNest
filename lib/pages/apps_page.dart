import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/planning.dart';
import '../ui/app_picker_dialog.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final device = ref.read(deviceProvider);
    final catalog = ref.watch(appsProvider);
    final protection = ref.watch(protectionStatusProvider);
    return PageFrame(
      title: '专注保护',
      subtitle: '应用默认受限，只把专注时确实需要的应用加入白名单。',
      children: [
        if (state.focusing)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: NestColors.softOrange,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '本次专注采用开始时确认的名单，结束后可调整。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: NestColors.orangeDeep,
                ),
              ),
            ),
          ),
        catalog.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => EmptyPanel(
            title: '未能读取应用列表',
            body: '已有名单会保留。',
            icon: Icons.apps_rounded,
            action: MainButton(
              '重试',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(appsProvider),
            ),
          ),
          data: (apps) {
            final allowed = apps
                .where(
                  (a) => !a.protected && state.allowedApps.contains(a.package),
                )
                .toList();
            final available = apps
                .where(
                  (a) => !a.protected && !state.allowedApps.contains(a.package),
                )
                .toList();
            return SurfacePanel(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '白名单 · ${allowed.length} 个',
                            style: const TextStyle(
                              fontSize: 16,
                              color: NestColors.ink,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('open-app-picker'),
                          onPressed: state.focusing
                              ? null
                              : () => _addApps(available),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('添加'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      '其他 ${available.length} 个应用在专注时默认受限。电话、桌面和必要系统应用始终允许。',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: NestColors.muted,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  if (allowed.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 22,
                      ),
                      child: Text(
                        '白名单还是空的。需要学习工具时，点右上角「添加」一次勾选多个应用。',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: NestColors.muted,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < allowed.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 0,
                        ),
                      _AppRow(
                        app: allowed[i],
                        key: Key('allowed-${allowed[i].package}'),
                        trailing: IconButton(
                          tooltip: '移除${allowed[i].name}',
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: NestColors.faint,
                          ),
                          onPressed: state.focusing
                              ? null
                              : () => ref
                                    .read(appProvider.notifier)
                                    .toggleInstalledApp(allowed[i]),
                        ),
                      ),
                    ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '保护状态',
                      style: TextStyle(fontSize: 16, color: NestColors.ink),
                    ),
                  ),
                  StatusPill(
                    device.simulated
                        ? '网页模拟'
                        : state.protectionReady
                        ? '已开启'
                        : '未生效',
                    warning: !device.simulated && !state.protectionReady,
                    background: device.simulated || state.protectionReady
                        ? NestColors.softGreen
                        : NestColors.softOrange,
                    foreground: device.simulated || state.protectionReady
                        ? NestColors.greenDeep
                        : NestColors.amber,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                device.simulated
                    ? '这里使用虚拟应用列表，真实拦截请在手机体验。'
                    : '打开未加入白名单的应用会显示锁定提醒，点击「知道了」返回桌面。只读取窗口所属应用标识，不读取页面文字、输入内容或截图。',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: NestColors.muted,
                ),
              ),
            ),
            if (!device.simulated)
              protection.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('正在检查保护状态…'),
                ),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('暂时无法检查保护状态'),
                ),
                data: (p) => Column(
                  children: [
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      endIndent: 0,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        p.ready
                            ? (p.active
                                  ? '本次专注保护已启用 · 限制 ${p.blockedCount} 个应用'
                                  : '服务已连接 · 尚未开始应用保护')
                            : '保护服务未连接，请重新开启系统权限',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: p.ready && p.active
                              ? NestColors.greenDeep
                              : NestColors.amber,
                        ),
                      ),
                    ),
                    if (state.focusing && !p.active)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('计时仍在继续，但系统保护已停止。请重新开启权限。'),
                      ),
                    if (p.active)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            p.backgroundRunning
                                ? '后台保护正在运行'
                                : '后台保护未运行，离开小屋后可能漏拦截',
                            style: const TextStyle(
                              fontSize: 13,
                              color: NestColors.muted,
                            ),
                          ),
                        ),
                      ),
                    if (p.active && !p.windowAccess)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('当前缺少窗口识别能力，需重新开启新版保护服务'),
                      ),
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text(
                        '查看保护诊断',
                        style: TextStyle(fontSize: 14),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('提醒已显示${p.reminders}次'),
                                Text('收到${p.windowEvents}次切换通知'),
                                Text('已核对前台窗口${p.foregroundChecks}次'),
                                if (p.homeResult.isNotEmpty) Text(p.homeResult),
                                if (p.error.isNotEmpty) Text(p.error),
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 15,
                                  ),
                                  label: const Text('复制诊断信息'),
                                  onPressed: () async {
                                    final fresh = await device.status();
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: jsonEncode(fresh.toJson()),
                                      ),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('已复制保护状态，不包含应用内容或应用名单'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (!device.simulated) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await device.openSettings();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('请在系统设置中允许悬浮窗并开启伴学小屋专注保护'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('管理系统保护权限'),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!device.simulated) ...[
          const SectionTitle('后台稳定性'),
          SurfacePanel(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '请在系统的应用信息中检查后台设置：小米／澎湃 OS 开启「自启动」，并把「省电策略」设为「无限制」；其他手机按系统提供的后台运行选项设置。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: NestColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '仅设置省电无限制或锁定最近任务卡片还不够。若划除后保护失效，请先检查自启动，再重新开启专注保护。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: NestColors.muted,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      try {
                        await device.openBackgroundSettings();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('请在系统的伴学小屋应用信息中检查自启动与省电策略'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('检查自启动与省电设置'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _addApps(List<InstalledApp> available) async {
    final selected = await showDialog<List<InstalledApp>>(
      context: context,
      builder: (_) => AppPickerDialog(apps: available),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    ref.read(appProvider.notifier).addAllowedApps(selected);
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({super.key, required this.app, required this.trailing});
  final InstalledApp app;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NestColors.fill,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            app.name.characters.first,
            style: const TextStyle(fontSize: 14, color: NestColors.inkSoft),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, color: NestColors.ink),
              ),
              const SizedBox(height: 1),
              Text(
                app.category,
                style: const TextStyle(fontSize: 13, color: NestColors.muted),
              ),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}
