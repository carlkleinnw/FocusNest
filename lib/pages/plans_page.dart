import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class PlansPage extends ConsumerWidget {
  const PlansPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final controller = ref.read(appProvider.notifier);
    return PageFrame(
      title: '把今天安排好',
      subtitle: '任务具体一点，开始就容易一点。计划时间用于提醒，专注由你手动开启。',
      eyebrow: 'ONE TASK AT A TIME',
      action: MainButton(
        '新增计划',
        icon: Icons.add,
        onPressed: state.focusing ? null : () => _edit(context, ref),
      ),
      children: [
        if (state.plans.isEmpty)
          const EmptyPanel(title: '从一个小任务开始', body: '添加一个你能在30分钟以上完成的学习安排。'),
        ...state.plans.map(
          (plan) => PlanCard(
            plan: plan,
            onEdit: state.focusing ? null : () => _edit(context, ref, plan),
            onDelete: state.focusing
                ? null
                : () => controller.removePlan(plan.id),
            onStart: state.focusing || state.pet.dead
                ? null
                : () {
                    controller.dismissSession();
                    context.go('/focus?plan=${plan.id}');
                  },
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '时间到了也不会自动锁定。进入专注页确认后，才开始计时。',
          style: TextStyle(color: NestColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [Plan? plan]) async {
    final title = TextEditingController(text: plan?.title ?? '');
    final minutes = TextEditingController(text: '${plan?.minutes ?? 30}');
    final time = TextEditingController(text: plan?.time ?? '09:00');
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(plan == null ? '新增一个计划' : '编辑计划'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  autofocus: true,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: '具体任务',
                    hintText: '例如：完成五道导数练习',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '写下一个具体任务' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '专注时长（分钟）'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 30 || n > 180
                        ? '请选择30—180分钟'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: time,
                  decoration: const InputDecoration(
                    labelText: '提醒时间',
                    hintText: '09:00',
                  ),
                  validator: (v) =>
                      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v ?? '')
                      ? null
                      : '请输入有效时间，如09:00',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              final result = ref
                  .read(appProvider.notifier)
                  .upsertPlan(
                    Plan(
                      id:
                          plan?.id ??
                          'p${DateTime.now().microsecondsSinceEpoch}',
                      title: title.text.trim(),
                      minutes: int.parse(minutes.text),
                      time: time.text,
                      category: plan?.category ?? '学习',
                    ),
                  );
              if (result.ok) Navigator.pop(dialogContext);
              showResult(context, result);
            },
            child: const Text('保存计划'),
          ),
        ],
      ),
    );
    // Controllers outlive dialog dismissal animation before being disposed.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    title.dispose();
    minutes.dispose();
    time.dispose();
  }
}
