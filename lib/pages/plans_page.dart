import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../ui/components.dart';
import '../ui/planning_forms.dart';

class PlansPage extends ConsumerStatefulWidget {
  const PlansPage({super.key, this.day});
  final String? day;
  @override
  ConsumerState<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends ConsumerState<PlansPage> {
  String? selectedDay;
  bool backlog = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final controller = ref.read(appProvider.notifier);
    final day = selectedDay ?? widget.day ?? state.dayKey;
    final plans =
        state.plans
            .where(
              (p) => backlog
                  ? !p.done &&
                        p.date.isNotEmpty &&
                        p.date.compareTo(state.dayKey) < 0
                  : (p.date.isEmpty ? state.dayKey : p.date) == day,
            )
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    final allocated = plans.fold(0, (sum, p) => sum + p.minutes);
    return PageFrame(
      title: '给每天安排具体的一步',
      subtitle: '关联长期目标、记录完成量；未完成任务保留在待调整列表。',
      action: MainButton(
        '新增计划',
        icon: Icons.add,
        onPressed: state.focusing
            ? null
            : () => editPlan(
                context,
                ref,
                day: day.compareTo(state.dayKey) < 0 ? state.dayKey : day,
              ),
      ),
      children: [
        SurfacePanel(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('每日安排'),
                selected: !backlog,
                onSelected: (_) => setState(() => backlog = false),
              ),
              ChoiceChip(
                label: const Text('待调整'),
                selected: backlog,
                onSelected: (_) => setState(() => backlog = true),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(day),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(day) ?? state.now,
                    firstDate: DateTime(state.now.year - 1),
                    lastDate: DateTime(state.now.year + 5),
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      selectedDay = dateKey(picked);
                      backlog = false;
                    });
                  }
                },
              ),
              Text(
                backlog
                    ? '过去日期中尚未完成的任务'
                    : '已安排 $allocated / ${state.dailyCapacity} 分钟',
              ),
              TextButton(
                onPressed: state.focusing
                    ? null
                    : () async {
                        final input = TextEditingController(
                          text: state.dailyCapacity.toString(),
                        );
                        final value = await showEditorDialog<int>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('每日可用时间'),
                            content: TextField(
                              controller: input,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '分钟（30—720）',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(
                                  ctx,
                                  int.tryParse(input.text) ?? 0,
                                ),
                                child: const Text('保存'),
                              ),
                            ],
                          ),
                        );
                        if (value != null && context.mounted) {
                          showResult(context, controller.setCapacity(value));
                        }
                        input.dispose();
                      },
                child: const Text('调整可用时间'),
              ),
              TextButton(
                onPressed: () => context.go('/goals'),
                child: const Text('制定长期目标'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (plans.isEmpty)
          const EmptyPanel(title: '这里暂时没有任务', body: '从一件具体的小事开始，或从长期目标安排阶段任务。'),
        for (final plan in plans)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${plan.date.isEmpty ? state.dayKey : plan.date} ${plan.time} · ${plan.minutes} 分钟',
                  ),
                  Text(
                    '${state.goals.where((g) => g.id == plan.goalId).firstOrNull?.title ?? '独立任务'} · 完成 ${plan.doneUnits}/${plan.units}${plan.done ? ' · 已完成' : ''}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('选择任务'),
                        onPressed:
                            state.focusing ||
                                state.pet.dead ||
                                plan.done ||
                                day != state.dayKey ||
                                backlog
                            ? null
                            : () {
                                controller.dismissSession();
                                context.go('/focus?plan=${plan.id}');
                              },
                      ),
                      OutlinedButton(
                        onPressed: state.focusing
                            ? null
                            : () => editProgress(context, ref, plan),
                        child: const Text('记录完成量'),
                      ),
                      TextButton(
                        onPressed: state.focusing
                            ? null
                            : () => editPlan(
                                context,
                                ref,
                                plan: plan,
                                day: backlog ? state.dayKey : null,
                              ),
                        child: Text(backlog ? '重新安排' : '编辑计划'),
                      ),
                      IconButton(
                        tooltip: '删除计划',
                        onPressed: state.focusing
                            ? null
                            : () async {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('删除这项计划？'),
                                    content: const Text(
                                      '该任务的完成量也会从目标中移除，专注记录仍保留。',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('保留'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                                );
                                if (yes == true) controller.removePlan(plan.id);
                              },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const Text('手动开始专注。完整计时给宠物喂食，任务完成量需要另行记录。'),
      ],
    );
  }
}
