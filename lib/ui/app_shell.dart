import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import 'focus_exit.dart';
import 'theme.dart';

const destinations = [
  ('/plans', '日程', Icons.event_note_rounded),
  ('/agent', 'AI', Icons.auto_awesome_outlined),
  ('/focus', '沉浸', Icons.timelapse_rounded),
  ('/me', '我的', Icons.person_outline_rounded),
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
                ? '专注计时仍在继续，但系统保护权限不完整，暂时无法完整拦截非白名单应用。请在系统设置补齐「显示悬浮窗」和「伴学小屋专注保护」。'
                : '专注期间，伴学小屋需要无障碍窗口访问权限识别正在打开的应用，以及「显示悬浮窗」权限遮挡受限内容。系统电话、状态栏和电源菜单保持可用。'
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请从专注保护与白名单页面补齐系统保护权限')),
            );
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
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final index = destinations.indexWhere((d) => d.$1 == widget.path);
    final selected = index < 0 ? -1 : index;
    final nested = index < 0;
    return PopScope(
      canPop: !state.focusing,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && state.focusing) await requestFocusExit(context, ref);
      },
      child: Scaffold(
        backgroundColor: NestColors.bg,
        appBar: AppBar(
          title: const Text('伴学小屋'),
          leading: nested
              ? IconButton(
                  tooltip: '返回',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/plans');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                )
              : null,
          actions: [
            if (state.focusing)
              TextButton(
                onPressed: () => context.go('/focus'),
                style: TextButton.styleFrom(
                  foregroundColor: NestColors.orangeDeep,
                ),
                child: const Text('专注中'),
              ),
            const SizedBox(width: 4),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1),
          ),
        ),
        body: Column(
          children: [
            if (ref.read(deviceProvider).simulated) const _DemoBanner(),
            if (state.storageError.isNotEmpty)
              _StorageError(state.storageError),
            Expanded(
              child: Row(
                children: [
                  if (wide) _SideRail(selected: selected),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide || nested
            ? null
            : _BottomNavBar(selected: selected),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: NestColors.softOrange,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    child: const Text(
      '网页演示 · 虚拟数据，刷新重置 · 不会限制真实应用',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: NestColors.orangeDeep),
    ),
  );
}

class _StorageError extends StatelessWidget {
  const _StorageError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: NestColors.softDanger,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      message,
      style: const TextStyle(fontSize: 13, color: NestColors.danger),
    ),
  );
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selected});
  final int selected;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: NestColors.surface,
      border: Border(top: BorderSide(color: NestColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _NavItem(
                  label: destinations[i].$2,
                  icon: destinations[i].$3,
                  selected: i == selected,
                  onTap: () => context.go(destinations[i].$1),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 23,
            color: selected ? NestColors.orange : NestColors.muted,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: selected ? NestColors.orange : NestColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.selected});
  final int selected;
  @override
  Widget build(BuildContext context) => Container(
    width: 88,
    decoration: const BoxDecoration(
      color: NestColors.surface,
      border: Border(right: BorderSide(color: NestColors.line)),
    ),
    child: SafeArea(
      right: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          for (var i = 0; i < destinations.length; i++)
            InkWell(
              onTap: () => context.go(destinations[i].$1),
              child: Container(
                width: 88,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Icon(
                      destinations[i].$3,
                      size: 23,
                      color: i == selected
                          ? NestColors.orange
                          : NestColors.muted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      destinations[i].$2,
                      style: TextStyle(
                        fontSize: 11,
                        color: i == selected
                            ? NestColors.orange
                            : NestColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
