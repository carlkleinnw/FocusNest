import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import 'focus_exit.dart';
import 'theme.dart';

const destinations = [
  ('/plans', '计划', Icons.checklist_rounded),
  ('/agent', 'AI 规划', Icons.auto_awesome_outlined),
  ('/focus', '沉浸专注', Icons.timelapse_rounded),
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
    final nested = index < 0 && widget.path != '/settings';
    return PopScope(
      canPop: !state.focusing,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && state.focusing) await requestFocusExit(context, ref);
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: NestColors.paper,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(
                focusing: state.focusing,
                nested: nested,
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/plans');
                  }
                },
              ),
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
        ),
        bottomNavigationBar: wide ? null : _FloatingNavBar(selected: selected),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 30});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8A3D), NestColors.orange],
      ),
      borderRadius: BorderRadius.circular(size * 0.32),
      boxShadow: NestShadow.accentGlow,
    ),
    child: Icon(
      Icons.auto_stories_rounded,
      size: size * 0.56,
      color: Colors.white,
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.focusing,
    required this.nested,
    required this.onBack,
  });
  final bool focusing, nested;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 14, 8),
    child: Row(
      children: [
        if (nested)
          _CircleAction(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回',
            onPressed: onBack,
          )
        else
          const _BrandMark(),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '伴学小屋',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: NestColors.ink,
            ),
          ),
        ),
        if (focusing)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(NestRadius.pill),
              onTap: () => context.go('/focus'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: NestColors.softOrange,
                  borderRadius: BorderRadius.circular(NestRadius.pill),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_clock_rounded,
                      size: 14,
                      color: NestColors.orangeDeep,
                    ),
                    SizedBox(width: 5),
                    Text(
                      '专注中',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NestColors.orangeDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        _CircleAction(
          icon: Icons.settings_outlined,
          tooltip: '设置',
          onPressed: () => context.go('/settings'),
        ),
      ],
    ),
  );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: NestColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 19, color: NestColors.inkSoft),
        ),
      ),
    ),
  );
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NestColors.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, size: 14, color: NestColors.blue),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              '网页演示 · 虚拟数据，刷新重置 · 不会限制真实应用',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: NestColors.blue,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StorageError extends StatelessWidget {
  const _StorageError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: NestColors.softDanger,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: NestColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: NestColors.danger,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.selected});
  final int selected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Container(
      decoration: BoxDecoration(
        color: NestColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: NestColors.line),
        boxShadow: NestShadow.floating,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? NestColors.softOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? NestColors.orangeDeep : NestColors.muted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? NestColors.orangeDeep : NestColors.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.selected});
  final int selected;
  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    margin: const EdgeInsets.fromLTRB(12, 4, 0, 20),
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: NestColors.surface,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: NestColors.line),
      boxShadow: NestShadow.card,
    ),
    child: Column(
      children: [
        _BrandMark(size: 36),
        const SizedBox(height: 26),
        for (var i = 0; i < destinations.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.go(destinations[i].$1),
              child: Container(
                width: 74,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: i == selected
                      ? NestColors.softOrange
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(
                      destinations[i].$3,
                      size: 22,
                      color: i == selected
                          ? NestColors.orangeDeep
                          : NestColors.muted,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      destinations[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i == selected
                            ? NestColors.orangeDeep
                            : NestColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Spacer(),
        IconButton(
          tooltip: '设置',
          onPressed: () => context.go('/settings'),
          icon: Icon(
            Icons.settings_outlined,
            color: selected == -1 ? NestColors.orange : NestColors.muted,
          ),
        ),
      ],
    ),
  );
}
