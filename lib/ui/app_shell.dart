import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../pet/pet_drawing.dart';
import 'theme.dart';

const destinations = [
  ('/home', '宠物小屋', Icons.cottage_outlined),
  ('/plans', '学习计划', Icons.event_note_outlined),
  ('/focus', '沉浸专注', Icons.timelapse),
  ('/records', '专注记录', Icons.bar_chart_rounded),
  ('/rest', '休息安排', Icons.spa_outlined),
  ('/apps', '允许的应用', Icons.apps_rounded),
  ('/adopt', '重新领养', Icons.pets_outlined),
  ('/demo', '演示控制', Icons.tune_rounded),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.path});
  final Widget child;
  final String path;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final floating = ref.watch(appProvider.select((s) => s.floating));
    final focusing = ref.watch(appProvider.select((s) => s.focusing));
    final selected = destinations.indexWhere((d) => d.$1 == path).clamp(0, 7);
    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const Text(
                '伴学小屋',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              actions: [
                TextButton(
                  onPressed: () => context.go('/demo'),
                  child: const Text('Demo'),
                ),
              ],
            ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(child: _Navigation(path: path, drawer: true)),
            ),
      body: Stack(
        children: [
          Row(
            children: [
              if (wide)
                Container(
                  width: 222,
                  decoration: const BoxDecoration(
                    color: NestColors.surface,
                    border: Border(right: BorderSide(color: NestColors.line)),
                  ),
                  child: _Navigation(path: path),
                ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 13,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: NestColors.line),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            focusing ? Icons.lock_outline : Icons.eco_outlined,
                            size: 16,
                            color: NestColors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              focusing ? '正在专注 · 宠物互动已暂停' : '慢慢来，每一小步都算数。',
                              style: const TextStyle(
                                fontSize: 12,
                                color: NestColors.muted,
                              ),
                            ),
                          ),
                          if (wide)
                            TextButton(
                              onPressed: () => context.go('/demo'),
                              child: const Text('虚拟数据 Demo'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
          if (floating) const FloatingPetPreview(),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : Builder(
              builder: (scaffoldContext) => NavigationBar(
                height: 70,
                selectedIndex: selected > 3 ? 4 : selected,
                onDestinationSelected: (index) {
                  if (index == 4) {
                    Scaffold.of(scaffoldContext).openDrawer();
                  } else {
                    context.go(destinations[index].$1);
                  }
                },
                destinations: [
                  ...destinations
                      .take(4)
                      .map(
                        (d) => NavigationDestination(
                          icon: Icon(d.$3),
                          label: d.$2,
                        ),
                      ),
                  const NavigationDestination(
                    icon: Icon(Icons.menu),
                    label: '更多',
                  ),
                ],
              ),
            ),
    );
  }
}

class _Navigation extends StatelessWidget {
  const _Navigation({required this.path, this.drawer = false});
  final String path;
  final bool drawer;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 20, 28),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NestColors.green,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.pets, color: Colors.white, size: 23),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '伴学小屋',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                Text(
                  'FOCUS NEST',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: NestColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (var i = 0; i < destinations.length; i++) ...[
              if (i == 4)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Text(
                    '照顾与体验',
                    style: TextStyle(
                      fontSize: 11,
                      color: NestColors.muted,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: path == destinations[i].$1,
                  selectedTileColor: NestColors.softGreen,
                  selectedColor: NestColors.green,
                  leading: Icon(destinations[i].$3, size: 21),
                  title: Text(
                    destinations[i].$2,
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () {
                    if (drawer) Navigator.pop(context);
                    context.go(destinations[i].$1);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '陪伴，让坚持有了形状。',
              style: TextStyle(fontSize: 12, color: NestColors.green),
            ),
            SizedBox(height: 8),
            Text(
              '体验版 0.1 · 虚拟数据',
              style: TextStyle(fontSize: 10, color: NestColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}

class FloatingPetPreview extends ConsumerStatefulWidget {
  const FloatingPetPreview({super.key});
  @override
  ConsumerState<FloatingPetPreview> createState() => _FloatingPetPreviewState();
}

class _FloatingPetPreviewState extends ConsumerState<FloatingPetPreview> {
  Offset? position;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final area = MediaQuery.sizeOf(context);
    final p = position ?? Offset(area.width - 150, area.height - 300);
    return Positioned(
      left: p.dx.clamp(0, (area.width - 140).clamp(0, double.infinity)),
      top: p.dy.clamp(0, (area.height - 270).clamp(0, double.infinity)),
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => position = p + d.delta),
        child: Container(
          width: 136,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: NestColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: NestColors.line),
            boxShadow: const [
              BoxShadow(color: Color(0x12604A30), blurRadius: 15),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    '悬浮预览',
                    style: TextStyle(fontSize: 10, color: NestColors.muted),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: '关闭悬浮预览',
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: ref.read(appProvider.notifier).toggleFloating,
                    ),
                  ),
                ],
              ),
              PetPortrait(pet: state.pet, sleeping: state.focusing, size: 80),
              Text(
                state.pet.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: state.focusing ? null : () => context.go('/home'),
                child: Text(
                  state.focusing ? '安静陪伴中' : '回小屋互动',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
