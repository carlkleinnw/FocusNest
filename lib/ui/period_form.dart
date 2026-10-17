import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/plan_management.dart';
import 'components.dart';

const planLevelNames = {
  'day': '日计划',
  'week': '周计划',
  'month': '月计划',
  'quarter': '季度计划',
  'goal': '总目标',
};

Future<void> editPeriod(
  BuildContext context,
  WidgetRef ref,
  String level,
  DateTime anchor, [
  PeriodPlan? period,
]) async {
  final s = ref.read(appProvider);
  final start = level == 'week'
      ? anchor.subtract(Duration(days: anchor.weekday - 1))
      : level == 'month'
      ? DateTime(anchor.year, anchor.month)
      : DateTime(anchor.year, ((anchor.month - 1) ~/ 3) * 3 + 1);
  final end = level == 'week'
      ? start.add(const Duration(days: 6))
      : DateTime(start.year, start.month + (level == 'month' ? 1 : 3), 0);
  final title = TextEditingController(text: period?.title ?? '');
  final from = TextEditingController(text: period?.start ?? dateKey(start));
  final to = TextEditingController(text: period?.end ?? dateKey(end));
  String? goalId = period?.goalId;
  String error = '';
  bool busy = false;
  await showEditorDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('${period == null ? '新增' : '编辑'}${planLevelNames[level]}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('period-title'),
                  controller: title,
                  maxLength: 240,
                  decoration: const InputDecoration(labelText: '本阶段想完成什么'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('period-start'),
                  controller: from,
                  decoration: const InputDecoration(
                    labelText: '开始日期 YYYY-MM-DD',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('period-end'),
                  controller: to,
                  decoration: const InputDecoration(
                    labelText: '结束日期 YYYY-MM-DD',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: goalId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '所属总目标'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('独立周期计划')),
                    ...s.goals.map(
                      (g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.title, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => set(() => goalId = v == '' ? null : v),
                ),
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    set(() => busy = true);
                    final result = await ref
                        .read(appProvider.notifier)
                        .managePlans([
                          {
                            'op': period == null ? 'create' : 'update',
                            'entity': 'period',
                            if (period != null) 'id': period.id,
                            'values': {
                              'title': title.text.trim(),
                              'start': from.text.trim(),
                              'end': to.text.trim(),
                              'level': level,
                              'goalId': goalId,
                            },
                          },
                        ]);
                    if (ctx.mounted) {
                      if (result.ok) {
                        Navigator.pop(ctx);
                        showResult(context, result);
                      } else {
                        set(() {
                          busy = false;
                          error = result.message;
                        });
                      }
                    }
                  },
            child: Text(busy ? '正在保存…' : '保存周期计划'),
          ),
        ],
      ),
    ),
  );
  for (final c in [title, from, to]) {
    c.dispose();
  }
}
