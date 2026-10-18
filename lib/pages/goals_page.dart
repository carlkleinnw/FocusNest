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
      title: '长期目标',
      subtitle: '长期目标拆成阶段，再安排到每天；完成量由每日任务累计。',
      action: MainButton(
        '新增长期目标',
        onPressed: state.focusing ? null : () => editGoal(context, ref),
      ),
      children: [
        if (state.goals.isEmpty)
          const EmptyPanel(
            title: '先确定一个想完成的目标',
            body: '例如：30天完成20道专题练习。',
            icon: Icons.flag_outlined,
          ),
        for (final goal in state.goals) _GoalCard(goal: goal),
      ],
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});
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
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfacePanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(Icons.flag_rounded, size: 40, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    goal.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${(ratio * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: NestColors.orangeDeep,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: ratio, minHeight: 7),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                MetaText('截止 ${goal.deadline}', icon: Icons.event_rounded),
                const Spacer(),
                MetaText(
                  '$done / ${goal.totalUnits} ${goal.unit}',
                  icon: Icons.functions_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => context.go('/goals/${goal.id}'),
                icon: const Icon(Icons.account_tree_outlined, size: 18),
                label: const Text('查看阶段与任务'),
                style: FilledButton.styleFrom(
                  backgroundColor: NestColors.softOrange,
                  foregroundColor: NestColors.orangeDeep,
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
        ),
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
      return const PageFrame(
        title: '目标不存在',
        subtitle: '请返回长期目标列表。',
        children: [],
      );
    }
    final tasks = state.plans.where((p) => p.goalId == goalId).toList();
    final stages = state.milestones.where((m) => m.goalId == goalId);
    final assigned = tasks.fold(0, (sum, p) => sum + p.units);
    final done = tasks.fold(0, (sum, p) => sum + p.doneUnits);
    final ratio = goal.totalUnits == 0
        ? 0.0
        : (done / goal.totalUnits).clamp(0.0, 1.0);
    return PageFrame(
      title: goal.title,
      subtitle: '截止 ${goal.deadline} · 按每日任务的实际完成量累计',
      action: OutlinedButton(
        onPressed: state.focusing ? null : () => editGoal(context, ref, goal),
        child: const Text('编辑目标'),
      ),
      children: [
        TextButton.icon(
          onPressed: () => context.go('/goals'),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('返回长期目标'),
          style: TextButton.styleFrom(
            foregroundColor: NestColors.muted,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          padding: const EdgeInsets.all(18),
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
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      color: NestColors.orangeDeep,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: ratio, minHeight: 7),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  MetaText('尚待安排', icon: Icons.pending_outlined),
                  const SizedBox(width: 6),
                  Text(
                    '${(goal.totalUnits - assigned).clamp(0, goal.totalUnits)} ${goal.unit}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: NestColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            MainButton(
              '新增阶段',
              icon: Icons.add_rounded,
              onPressed: state.focusing
                  ? null
                  : () => editMilestone(context, ref, goal),
            ),
            OutlinedButton.icon(
              onPressed: state.focusing
                  ? null
                  : () => editPlan(context, ref, goalId: goalId),
              icon: const Icon(Icons.today_outlined, size: 17),
              label: const Text('直接安排每日任务'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionTitle('阶段'),
        for (final stage in stages)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SurfacePanel(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stage.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TagLabel(
                        '截止 ${stage.deadline}',
                        color: NestColors.muted,
                        background: NestColors.paper,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${tasks.where((p) => p.milestoneId == stage.id).fold(0, (sum, p) => sum + p.doneUnits)} / ${stage.units}${goal.unit}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: NestColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: state.focusing
                            ? null
                            : () => editMilestone(context, ref, goal, stage),
                        style: TextButton.styleFrom(
                          foregroundColor: NestColors.muted,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('编辑阶段'),
                      ),
                      OutlinedButton(
                        onPressed: state.focusing
                            ? null
                            : () => editPlan(
                                context,
                                ref,
                                goalId: goalId,
                                milestoneId: stage.id,
                              ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(fontSize: 12.5),
                        ),
                        child: const Text('安排阶段任务'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
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
                  icon: Icons.today_outlined,
                  title: task.title,
                  subtitle:
                      '${task.date} · ${task.doneUnits}/${task.units}${goal.unit}',
                  trailing: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
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
