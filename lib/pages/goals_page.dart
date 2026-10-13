import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../ui/components.dart';
import '../ui/planning_forms.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    return PageFrame(
      title: '让每天走向同一个方向',
      subtitle: '长期目标拆成阶段，再安排到每天；完成量由每日任务累计。',
      action: MainButton(
        '新增长期目标',
        onPressed: state.focusing ? null : () => editGoal(context, ref),
      ),
      children: [
        if (state.goals.isEmpty)
          const EmptyPanel(title: '先确定一个想完成的目标', body: '例如：30天完成20道专题练习。'),
        for (final goal in state.goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '截止 ${goal.deadline} · ${state.plans.where((p) => p.goalId == goal.id).fold(0, (sum, p) => sum + p.doneUnits)} / ${goal.totalUnits} ${goal.unit}',
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value:
                        state.plans
                            .where((p) => p.goalId == goal.id)
                            .fold(0, (sum, p) => sum + p.doneUnits) /
                        goal.totalUnits,
                  ),
                  const SizedBox(height: 16),
                  MainButton(
                    '查看阶段与任务',
                    onPressed: () => context.go('/goals/${goal.id}'),
                  ),
                ],
              ),
            ),
          ),
      ],
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
    return PageFrame(
      title: goal.title,
      subtitle: '截止 ${goal.deadline} · 按每日任务的实际完成量累计',
      action: OutlinedButton(
        onPressed: state.focusing ? null : () => editGoal(context, ref, goal),
        child: const Text('编辑目标'),
      ),
      children: [
        TextButton(
          onPressed: () => context.go('/goals'),
          child: const Text('返回长期目标'),
        ),
        SurfacePanel(
          child: Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              StatBlock(
                '实际完成',
                done.toString(),
                unit: '/ ${goal.totalUnits}${goal.unit}',
              ),
              StatBlock(
                '尚待安排',
                (goal.totalUnits - assigned).toString(),
                unit: goal.unit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MainButton(
              '新增阶段',
              onPressed: state.focusing
                  ? null
                  : () => editMilestone(context, ref, goal),
            ),
            OutlinedButton(
              onPressed: state.focusing
                  ? null
                  : () => editPlan(context, ref, goalId: goalId),
              child: const Text('直接安排每日任务'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final stage in stages)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '截止 ${stage.deadline} · ${tasks.where((p) => p.milestoneId == stage.id).fold(0, (sum, p) => sum + p.doneUnits)} / ${stage.units}${goal.unit}',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: state.focusing
                            ? null
                            : () => editMilestone(context, ref, goal, stage),
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
                        child: const Text('安排阶段任务'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const Text('已安排到每天'),
        for (final task in tasks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(task.title),
            subtitle: Text(
              '${task.date} · ${task.doneUnits}/${task.units}${goal.unit}',
            ),
            trailing: IconButton(
              tooltip: '查看每日计划',
              onPressed: () => context.go('/plans?day=${task.date}'),
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
      ],
    );
  }
}
