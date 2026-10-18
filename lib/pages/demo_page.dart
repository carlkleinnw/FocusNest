import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class DemoPage extends ConsumerWidget {
  const DemoPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final controller = ref.read(appProvider.notifier);
    if (!controller.simulated) {
      return const PageFrame(
        subtitle: '手机使用真实时间，计划和记录保存在本机。',
        children: [
          SurfacePanel(
            child: Text(
              '应用锁定需要在「应用锁定」页开启无障碍权限。\n完成完整专注才会喂食。手机不提供快进或清空数据按钮。\n智能扩展接口已预留，尚未启用大模型和Agent。',
            ),
          ),
        ],
      );
    }
    Future<void> report(Future<dynamic> pending) async {
      final result = await pending;
      if (context.mounted) showResult(context, result);
    }

    return PageFrame(
      subtitle: '这里控制虚拟时间。快进结果会标记为演示，刷新恢复初始数据。',
      children: [
        SurfacePanel(
          color: NestColors.softGreen,
          child: Wrap(
            spacing: 40,
            runSpacing: 18,
            children: [
              StatBlock('虚拟日期', shortDate(state.now)),
              StatBlock('连续饥饿', '${state.pet.hungryDays}', unit: '/ 7 天'),
              StatBlock('当前会话', state.focusing ? '专注中' : '未进行'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('体验专注与喂食', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              const Text('先到专注页开始计时，再回来快进。完成后去小屋看宠物。'),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  MainButton(
                    '完成当前专注（模拟）',
                    icon: Icons.fast_forward,
                    onPressed: state.focusing
                        ? () => report(
                            controller.advanceMinutes(
                              (state.session!.remainingSeconds(state.now) / 60)
                                  .ceil()
                                  .clamp(1, 180),
                            ),
                          )
                        : null,
                  ),
                  OutlinedButton(
                    onPressed: state.focusing
                        ? () => report(controller.advanceMinutes(10))
                        : null,
                    child: const Text('快进10分钟'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/focus'),
                    child: const Text('前往专注页'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('体验饥饿、休息与死亡', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              const Text('推进一天会结算刚结束的日期。未喂食的学习日增加饥饿，休息日暂停；第7天进入死亡状态。'),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  MainButton(
                    '推进一天',
                    icon: Icons.wb_sunny_outlined,
                    onPressed: state.focusing
                        ? null
                        : () => report(controller.advanceDay()),
                  ),
                  TextButton(
                    onPressed: () => context.go('/rest'),
                    child: const Text('提前安排休息'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/adopt'),
                    child: const Text('体验重新领养'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('演示边界', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              const Text(
                '• 应用限制、提醒和外部悬浮均为模拟。\n• 计时可以正常运行，也能在这里快进。\n• 暂定完整专注将饥饿天数清零，不储存食物。\n• 智能扩展接口已预留，大模型和Agent尚未启用。',
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重置全部演示数据'),
                onPressed: () async {
                  final reset = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('回到演示的第一天？'),
                      content: const Text('本次演示新增的计划和记录会清空，宠物恢复初始状态。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('保留当前体验'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('确认重置'),
                        ),
                      ],
                    ),
                  );
                  if (reset == true) controller.resetDemo();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
