import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import 'focus_exit.dart';

const destinations = [
  ('/plans', '计划', Icons.checklist_rounded),
  ('/agent', 'AI 规划', Icons.route_outlined),
  ('/focus', '沉浸专注', Icons.timelapse),
  ('/records', '复盘', Icons.auto_stories_outlined),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.path});
  final Widget child;
  final String path;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  bool _checkingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _offerProtectionPermission(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _offerProtectionPermission();
      });
    }
  }

  Future<void> _offerProtectionPermission() async {
    if (_checkingPermission) return;
    _checkingPermission = true;
    try {
      final device = ref.read(deviceProvider);
      if (device.simulated) return;
      final status = await device.status();
      if (!mounted) return;
      final state = ref.read(appProvider);
      if (status.ready) {
        ref.read(appProvider.notifier).markPermissionReady();
        return;
      }
      final recovery = state.permissionEverReady;
      // A previously granted service may be stopped by the phone vendor.
      // Interrupt an active focus, but keep ordinary visits free of repeat dialogs.
      if (recovery && !state.focusing) return;
      if (recovery
          ? state.permissionRecoveryPromptSeen
          : state.permissionPromptSeen) {
        return;
      }
      final open = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(recovery ? '专注保护已关闭' : '开启专注保护？'),
          content: Text(
            recovery
                ? '专注计时仍在继续，但系统保护权限已关闭，暂时无法拦截非白名单应用。请到系统设置重新开启「伴学小屋专注保护」。'
                : '专注期间，伴学小屋需要无障碍窗口访问权限识别正在打开的应用，并在非白名单应用上显示提醒。'
                      '只读取应用标识，不读取页面文字、输入内容或截图。你可以暂不启用，之后在「应用锁定」里重新开启或前往系统设置关闭。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('暂不启用'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('去系统设置开启'),
            ),
          ],
        ),
      );
      if (!mounted || open == null) return;
      if (recovery) {
        ref.read(appProvider.notifier).markPermissionRecoveryPromptSeen();
      } else {
        ref.read(appProvider.notifier).markPermissionPromptSeen();
      }
      if (open) {
        try {
          await device.openSettings();
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('请从应用锁定页前往系统无障碍设置')));
          }
        }
      }
    } finally {
      _checkingPermission = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    ref.watch(appsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final index = destinations.indexWhere((d) => d.$1 == widget.path);
    final selected = index < 0 ? 0 : index;
    return PopScope(
      canPop: !state.focusing,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && state.focusing) await requestFocusExit(context, ref);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '伴学小屋',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            if (state.focusing)
              TextButton.icon(
                onPressed: () => context.go('/focus'),
                icon: const Icon(Icons.lock_clock_outlined, size: 18),
                label: const Text('专注中'),
              ),
            IconButton(
              tooltip: '设置',
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            if (ref.read(deviceProvider).simulated)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  '网页演示 · 虚拟数据，刷新重置 · 不会限制真实应用',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (state.storageError.isNotEmpty)
              MaterialBanner(
                content: Text(state.storageError),
                actions: [
                  TextButton(
                    onPressed: () => ref.read(appProvider.notifier).tick(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      selectedIndex: selected,
                      onDestinationSelected: (i) =>
                          context.go(destinations[i].$1),
                      labelType: NavigationRailLabelType.all,
                      destinations: destinations
                          .map(
                            (d) => NavigationRailDestination(
                              icon: Icon(d.$3),
                              label: Text(d.$2),
                            ),
                          )
                          .toList(),
                    ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (i) => context.go(destinations[i].$1),
                destinations: destinations
                    .map(
                      (d) =>
                          NavigationDestination(icon: Icon(d.$3), label: d.$2),
                    )
                    .toList(),
              ),
      ),
    );
  }
}
