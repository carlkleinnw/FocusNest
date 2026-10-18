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
      subtitle: '应用默认受限。只将专注时确实需要的应用加入白名单。',
      children: [
        if (state.focusing)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: NestColors.softOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    size: 16,
                    color: NestColors.orangeDeep,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '本次专注采用开始时确认的名单，结束后可调整。',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: NestColors.orangeDeep,
                      ),
                    ),
                  ),
                ],
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SurfacePanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: Row(
                          children: [
                            const IconBadge(
                              Icons.verified_user_outlined,
                              size: 40,
                              iconSize: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '专注白名单',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: NestColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '已添加 ${allowed.length} 个 · 其他 ${available.length} 个默认受限',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: NestColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '刷新应用列表',
                              onPressed: state.focusing
                                  ? null
                                  : () => ref.invalidate(appsProvider),
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: NestColors.muted,
                              ),
                            ),
                            IconButton(
                              tooltip: '添加应用',
                              onPressed: state.focusing
                                  ? null
                                  : () => _addApps(available),
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                color: NestColors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (allowed.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 22,
                          ),
                          child: Text(
                            '白名单还是空的。需要学习工具时，点下方按钮一次勾选多个应用。',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.6,
                              color: NestColors.muted,
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < allowed.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, indent: 70, endIndent: 16),
                          _AppRow(
                            app: allowed[i],
                            key: Key('allowed-${allowed[i].package}'),
                            trailing: IconButton(
                              tooltip: '移除${allowed[i].name}',
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 20,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                key: const Key('open-app-picker'),
                                onPressed: state.focusing
                                    ? null
                                    : () => _addApps(available),
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: const Text('添加应用'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '电话、桌面和必要系统应用始终允许，无需添加。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: NestColors.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SurfacePanel(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    device.simulated
                        ? Icons.science_outlined
                        : state.protectionReady
                        ? Icons.shield_rounded
                        : Icons.gpp_maybe_outlined,
                    color: device.simulated || state.protectionReady
                        ? NestColors.green
                        : NestColors.orange,
                    background: device.simulated || state.protectionReady
                        ? NestColors.softGreen
                        : NestColors.softOrange,
                    size: 40,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '保护状态',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: NestColors.ink,
                      ),
                    ),
                  ),
                  StatusPill(
                    device.simulated
                        ? '网页模拟'
                        : state.protectionReady
                        ? '保护权限已开启'
                        : '保护未生效',
                    warning: !device.simulated && !state.protectionReady,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                device.simulated
                    ? '这里使用虚拟应用列表，真实拦截请在手机体验。'
                    : '打开未加入白名单的应用会显示锁定提醒，点击「知道了」返回桌面。只读取窗口所属应用标识，不读取页面文字、输入内容或截图。电话、系统设置等必要应用始终允许。',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.65,
                  color: NestColors.muted,
                ),
              ),
              if (!device.simulated) ...[
                const SizedBox(height: 12),
                protection.when(
                  loading: () => const Text('正在检查保护状态…'),
                  error: (_, _) => const Text('暂时无法检查保护状态'),
                  data: (p) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: p.ready && p.active
                              ? NestColors.softGreen
                              : NestColors.softOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          p.ready
                              ? (p.active
                                    ? '本次专注保护已启用 · 限制${p.blockedCount}个应用'
                                    : '服务已连接 · 尚未开始应用保护')
                              : '保护服务未连接，请重新开启系统权限',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: p.ready && p.active
                                ? NestColors.green
                                : NestColors.orangeDeep,
                          ),
                        ),
                      ),
                      if (state.focusing && !p.active)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('计时仍在继续，但系统保护已停止。请重新开启权限。'),
                        ),
                      if (p.active)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            p.backgroundRunning
                                ? '后台保护正在运行'
                                : '后台保护未运行，离开小屋后可能漏拦截',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: NestColors.muted,
                            ),
                          ),
                        ),
                      if (p.active && !p.windowAccess)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('当前缺少窗口识别能力，需重新开启新版保护服务'),
                        ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('查看保护诊断'),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
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
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.settings_outlined, size: 19),
                    label: const Text('管理系统保护权限'),
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
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '专注保护需要「显示悬浮窗」和「伴学小屋专注保护」两项权限。点击上方按钮先补齐缺少的权限，返回后可再次点击管理另一项。应用只取窗口所属应用标识，用提醒遮挡受限内容，保留系统状态栏、电话和电源菜单。拒绝或关闭后仍可使用计划，但无法开始受保护的专注。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.65,
                    color: NestColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!device.simulated) ...[
          const SizedBox(height: 16),
          const SectionTitle('后台稳定性'),
          SurfacePanel(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '请在伴学小屋的系统应用信息中检查后台设置：小米／澎湃 OS 开启「自启动」，并将「省电策略」设为「无限制」；其他手机按系统提供的后台运行选项设置。专注期间会运行后台保护服务。',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.65,
                    color: NestColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '仅设置省电无限制或锁定最近任务卡片还不够。若划除后保护失效，请先检查自启动，再重新开启专注保护。系统强行停止或手动关闭权限后，仍需重新打开应用并恢复权限；保存的计时会保留。',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.65,
                    color: NestColors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('检查自启动与省电设置'),
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
    padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NestColors.paper,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            app.name.characters.first,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: NestColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: NestColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                app.category,
                style: const TextStyle(fontSize: 11.5, color: NestColors.muted),
              ),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}
