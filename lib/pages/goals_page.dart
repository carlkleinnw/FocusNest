import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/planning.dart';
import '../ui/components.dart';
import '../ui/planning_forms.dart';
import '../ui/theme.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    return PageFrame(
      subtitle: '目标拆成阶段，再安排到每天。',
      action: TextButton(
        onPressed: state.focusing ? null : () => editGoal(context, ref),
        child: const Text('新增长期目标'),
      ),
      children: [
        if (state.goals.isEmpty)
          const EmptyPanel(
            title: '先确定一个想完成的目标',
            body: '例如：30天完成20道专题练习。',
            icon: Icons.flag_outlined,
          )
        else
          SettingsGroup(
            children: [for (final goal in state.goals) _GoalRow(goal: goal)],
          ),
      ],
    );
  }
}

class _GoalRow extends ConsumerWidget {
  const _GoalRow({required this.goal});
  final Goal goal;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final done = state.plans
        .where((p) => p.goalId == goal.id)
        .fold(0, (sum, p) => sum + p.doneUnits);
    final ratio = goal.totalUnits == 0
        ? 0.0
        : (done / goal.totalUnits).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: NestColors.ink,
                  ),
                ),
              ),
              Text(
                '${(ratio * 100).round()}%',
                style: const TextStyle(fontSize: 13, color: NestColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: ratio, minHeight: 3),
          ),
          const SizedBox(height: 8),
          Text(
            '截止 ${goal.deadline} · $done / ${goal.totalUnits} ${goal.unit}',
            style: const TextStyle(fontSize: 13, color: NestColors.muted),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go('/goals/${goal.id}'),
              style: TextButton.styleFrom(
                foregroundColor: NestColors.link,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('查看阶段与任务'),
            ),
          ),
        ],
      ),
    );
  }
}

class GoalDetailsPage extends ConsumerWidget {
  const GoalDetailsPage({super.key, required this.goalId});
  final String goalId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final goal = state.goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null) {
      return const PageFrame(subtitle: '请返回长期目标列表。', children: []);
    }
    final tasks = state.plans.where((p) => p.goalId == goalId).toList();
    final stages = state.milestones.where((m) => m.goalId == goalId);
    final assigned = tasks.fold(0, (sum, p) => sum + p.units);
    final done = tasks.fold(0, (sum, p) => sum + p.doneUnits);
    final ratio = goal.totalUnits == 0
        ? 0.0
        : (done / goal.totalUnits).clamp(0.0, 1.0);
    return PageFrame(
      subtitle: '截止 ${goal.deadline}',
      action: TextButton(
        onPressed: state.focusing ? null : () => editGoal(context, ref, goal),
        child: const Text('编辑'),
      ),
      children: [
        TextButton.icon(
          onPressed: () => context.go('/goals'),
          icon: const Icon(Icons.chevron_left_rounded, size: 18),
          label: const Text('返回长期目标'),
          style: TextButton.styleFrom(
            foregroundColor: NestColors.link,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          goal.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: NestColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        SurfacePanel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: StatBlock(
                      '实际完成',
                      done.toString(),
                      unit: '/ ${goal.totalUnits}${goal.unit}',
                    ),
                  ),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: NestColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: ratio, minHeight: 3),
              ),
              const SizedBox(height: 8),
              Text(
                '尚待安排 ${(goal.totalUnits - assigned).clamp(0, goal.totalUnits)} ${goal.unit}',
                style: const TextStyle(fontSize: 13, color: NestColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.focusing
                    ? null
                    : () => editMilestone(context, ref, goal),
                child: const Text('新增阶段'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: state.focusing
                    ? null
                    : () => editPlan(context, ref, goalId: goalId),
                child: const Text('直接安排每日任务'),
              ),
            ),
          ],
        ),
        const SectionTitle('阶段'),
        if (stages.isEmpty)
          const Text(
            '还没有阶段。',
            style: TextStyle(fontSize: 13, color: NestColors.muted),
          )
        else
          for (final stage in stages)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfacePanel(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.title,
                      style: const TextStyle(
                        fontSize: 16,
                        color: NestColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '截止 ${stage.deadline} · ${tasks.where((p) => p.milestoneId == stage.id).fold(0, (sum, p) => sum + p.doneUnits)} / ${stage.units}${goal.unit}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: NestColors.muted,
                      ),
                    ),
                    Wrap(
                      spacing: 0,
                      children: [
                        TextButton(
                          onPressed: state.focusing
                              ? null
                              : () => editMilestone(context, ref, goal, stage),
                          style: TextButton.styleFrom(
                            foregroundColor: NestColors.link,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          child: const Text('编辑阶段'),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: state.focusing
                              ? null
                              : () => editPlan(
                                  context,
                                  ref,
                                  goalId: goalId,
                                  milestoneId: stage.id,
                                ),
                          style: TextButton.styleFrom(
                            foregroundColor: NestColors.link,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          child: const Text('安排阶段任务'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        const SectionTitle('已安排到每天'),
        if (tasks.isEmpty)
          const Text(
            '还没有安排每日任务。',
            style: TextStyle(fontSize: 13, color: NestColors.muted),
          )
        else
          SettingsGroup(
            children: [
              for (final task in tasks)
                SettingsRow(
                  title: task.title,
                  subtitle:
                      '${task.date} · ${task.doneUnits}/${task.units}${goal.unit}',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: NestColors.faint,
                  ),
                  onTap: () => context.go('/plans?day=${task.date}'),
                ),
            ],
          ),
      ],
    );
  }
}
