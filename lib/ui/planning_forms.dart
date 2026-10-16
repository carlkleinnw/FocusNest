import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/planning.dart';
import 'components.dart';

Future<void> editGoal(BuildContext context, WidgetRef ref, [Goal? goal]) async {
  final state = ref.read(appProvider);
  final title = TextEditingController(text: goal?.title ?? '');
  final total = TextEditingController(
    text: (goal?.totalUnits ?? 20).toString(),
  );
  final unit = TextEditingController(text: goal?.unit ?? '题');
  final deadline = TextEditingController(
    text: goal?.deadline ?? dateKey(state.now.add(const Duration(days: 30))),
  );
  final error = ValueNotifier<String>('');
  await showEditorDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(goal == null ? '制定长期目标' : '编辑长期目标'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: '目标名称',
                hintText: '例如：完成导数专题练习',
              ),
            ),
            TextField(
              controller: total,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '总量'),
            ),
            TextField(
              controller: unit,
              maxLength: 8,
              decoration: const InputDecoration(labelText: '单位（题、章、页等）'),
            ),
            TextField(
              controller: deadline,
              decoration: const InputDecoration(labelText: '截止日期 YYYY-MM-DD'),
            ),
            _DialogError(error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final result = ref
                .read(appProvider.notifier)
                .upsertGoal(
                  Goal(
                    id: goal?.id ?? 'g${DateTime.now().microsecondsSinceEpoch}',
                    title: title.text.trim(),
                    deadline: deadline.text,
                    totalUnits: int.tryParse(total.text) ?? 0,
                    unit: unit.text.trim(),
                  ),
                );
            if (result.ok) {
              Navigator.pop(ctx);
              showResult(context, result);
            } else {
              error.value = result.message;
            }
          },
          child: const Text('保存目标'),
        ),
      ],
    ),
  );
  error.dispose();
  for (final c in [title, total, unit, deadline]) {
    c.dispose();
  }
}

Future<void> editMilestone(
  BuildContext context,
  WidgetRef ref,
  Goal goal, [
  Milestone? stage,
]) async {
  final title = TextEditingController(text: stage?.title ?? '');
  final units = TextEditingController(text: (stage?.units ?? 5).toString());
  final deadline = TextEditingController(
    text: stage?.deadline ?? goal.deadline,
  );
  final error = ValueNotifier<String>('');
  await showEditorDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(stage == null ? '拆成一个阶段' : '编辑阶段'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: 60,
              decoration: const InputDecoration(labelText: '阶段名称'),
            ),
            TextField(
              controller: units,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '阶段总量（${goal.unit}）'),
            ),
            TextField(
              controller: deadline,
              decoration: const InputDecoration(labelText: '阶段截止日期 YYYY-MM-DD'),
            ),
            _DialogError(error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final result = ref
                .read(appProvider.notifier)
                .upsertMilestone(
                  Milestone(
                    id:
                        stage?.id ??
                        'm${DateTime.now().microsecondsSinceEpoch}',
                    goalId: goal.id,
                    title: title.text.trim(),
                    units: int.tryParse(units.text) ?? 0,
                    deadline: deadline.text,
                  ),
                );
            if (result.ok) {
              Navigator.pop(ctx);
              showResult(context, result);
            } else {
              error.value = result.message;
            }
          },
          child: const Text('保存阶段'),
        ),
      ],
    ),
  );
  error.dispose();
  for (final c in [title, units, deadline]) {
    c.dispose();
  }
}

Future<void> editPlan(
  BuildContext context,
  WidgetRef ref, {
  Plan? plan,
  String? goalId,
  String? milestoneId,
  String? day,
}) async {
  final state = ref.read(appProvider);
  final title = TextEditingController(text: plan?.title ?? '');
  final minutes = TextEditingController(text: (plan?.minutes ?? 30).toString());
  final time = TextEditingController(text: plan?.time ?? '09:00');
  final date = TextEditingController(
    text: day ?? (plan?.date.isNotEmpty == true ? plan!.date : state.dayKey),
  );
  final units = TextEditingController(text: (plan?.units ?? 1).toString());
  String? selectedGoal = plan?.goalId ?? goalId,
      selectedStage = plan?.milestoneId ?? milestoneId;
  final error = ValueNotifier<String>('');
  await showEditorDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(plan == null ? '安排每日任务' : '编辑每日任务'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: '具体任务'),
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('目标与完成量（可选）'),
                  initiallyExpanded:
                      selectedGoal != null || (plan?.units ?? 1) > 1,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedGoal ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '关联长期目标'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('独立任务')),
                        ...state.goals.map(
                          (g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(
                              g.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => set(() {
                        selectedGoal = v == '' ? null : v;
                        selectedStage = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedGoal),
                      initialValue: selectedStage ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '关联阶段'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('不指定阶段')),
                        ...state.milestones
                            .where((m) => m.goalId == selectedGoal)
                            .map(
                              (m) => DropdownMenuItem(
                                value: m.id,
                                child: Text(
                                  m.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                      ],
                      onChanged: (v) => selectedStage = v == '' ? null : v,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: units,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            '任务数量（${state.goals.where((g) => g.id == selectedGoal).firstOrNull?.unit ?? '项'}）',
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '专注时长 30—180分钟'),
                ),
                TextField(
                  controller: date,
                  decoration: const InputDecoration(
                    labelText: '安排日期 YYYY-MM-DD',
                  ),
                ),
                TextField(
                  controller: time,
                  decoration: const InputDecoration(labelText: '计划开始时间 HH:mm'),
                ),
                const SizedBox(height: 12),
                const Text('计划时间供安排参考，专注需要手动确认开启。'),
                _DialogError(error),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final result = ref
                  .read(appProvider.notifier)
                  .upsertPlan(
                    Plan(
                      id:
                          plan?.id ??
                          'p${DateTime.now().microsecondsSinceEpoch}',
                      title: title.text.trim(),
                      minutes: int.tryParse(minutes.text) ?? 0,
                      time: time.text,
                      date: date.text,
                      goalId: selectedGoal,
                      milestoneId: selectedStage,
                      units: int.tryParse(units.text) ?? 0,
                      doneUnits: plan?.doneUnits ?? 0,
                      category: plan?.category ?? '学习',
                    ),
                  );
              if (result.ok) Navigator.pop(ctx);
              showResult(context, result);
            },
            child: const Text('保存计划'),
          ),
        ],
      ),
    ),
  );
  error.dispose();
  for (final c in [title, minutes, time, date, units]) {
    c.dispose();
  }
}

Future<void> editProgress(
  BuildContext context,
  WidgetRef ref,
  Plan plan,
) async {
  final units = TextEditingController(text: plan.doneUnits.toString());
  final error = ValueNotifier<String>('');
  await showEditorDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('记录实际完成量'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: units,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '已完成数量（0—${plan.units}）',
              helperText: '累计到长期目标；专注计时独立计算。',
            ),
          ),
          _DialogError(error),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final result = ref
                .read(appProvider.notifier)
                .setTaskProgress(plan.id, int.tryParse(units.text) ?? -1);
            if (result.ok) {
              Navigator.pop(ctx);
              showResult(context, result);
            } else {
              error.value = result.message;
            }
          },
          child: const Text('保存进度'),
        ),
      ],
    ),
  );
  error.dispose();
  units.dispose();
}

class _DialogError extends StatelessWidget {
  const _DialogError(this.error);
  final ValueNotifier<String> error;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: error,
    builder: (context, message, child) => message.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
  );
}
