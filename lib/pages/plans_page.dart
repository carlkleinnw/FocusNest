import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/planning.dart';
import '../core/plan_management.dart';
import '../ui/components.dart';
import '../ui/planning_forms.dart';
import '../ui/period_form.dart';
import '../ui/theme.dart';

class PlansPage extends ConsumerStatefulWidget {
  const PlansPage({super.key, this.day, this.all = false});
  final String? day;
  final bool all;
  @override
  ConsumerState<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends ConsumerState<PlansPage> {
  DateTime? selected;
  String level = 'day', query = '';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String? goalFilter;
  bool? all;
  DateTime anchor(AppState s) =>
      selected ?? DateTime.tryParse(widget.day ?? s.dayKey) ?? s.now;
  (String, String) range(AppState s) {
    final d = anchor(s);
    final start = level == 'week'
        ? d.subtract(Duration(days: d.weekday - 1))
        : level == 'month'
        ? DateTime(d.year, d.month)
        : level == 'quarter'
        ? DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1)
        : d;
    final end = level == 'week'
        ? start.add(const Duration(days: 6))
        : level == 'month'
        ? DateTime(d.year, d.month + 1, 0)
        : level == 'quarter'
        ? DateTime(start.year, start.month + 3, 0)
        : d;
    return (dateKey(start), dateKey(end));
  }

  void move(AppState s, int direction) {
    final d = anchor(s);
    setState(
      () => selected = level == 'day'
          ? d.add(Duration(days: direction))
          : level == 'week'
          ? d.add(Duration(days: 7 * direction))
          : DateTime(
              d.year,
              d.month + direction * (level == 'quarter' ? 3 : 1),
            ),
    );
  }

  Future<void> remove(String entity, String id, String title) async {
    final cascade = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '删除${entity == 'goal'
              ? '总目标'
              : entity == 'period'
              ? '周期计划'
              : '这项计划'}？',
        ),
        content: Text(
          '「$title」将移除。${entity == 'goal'
              ? '可选择保留每日任务为独立任务。周期计划会一并移除。'
              : entity == 'period'
              ? '每日任务会保留；删除周期说明不会删除任务。'
              : '已有专注计时仍保留。'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          if (entity == 'goal')
            TextButton(
              onPressed: () => Navigator.pop(ctx, 1),
              child: const Text('连同未完成任务删除'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: Text(entity == 'goal' ? '删除目标，保留任务' : '删除'),
          ),
        ],
      ),
    );
    if (cascade != null && mounted) {
      final result = await ref.read(appProvider.notifier).managePlans([
        {
          'op': 'delete',
          'entity': entity,
          'id': id,
          if (entity == 'goal') 'cascade': cascade == 1,
        },
      ]);
      if (mounted) showResult(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final (from, to) = range(s);
    final showAll = all ?? widget.all;
    final needle = query.toLowerCase();
    bool match(String title) => title.toLowerCase().contains(needle);
    final tasks =
        s.plans
            .where(
              (p) =>
                  (showAll ||
                      p.date.compareTo(from) >= 0 &&
                          p.date.compareTo(to) <= 0) &&
                  (goalFilter == null || p.goalId == goalFilter) &&
                  match(p.title),
            )
            .toList()
          ..sort(
            (a, b) => '${a.date}${a.time}${a.id}'.compareTo(
              '${b.date}${b.time}${b.id}',
            ),
          );
    final periods =
        periodPlans(s)
            .where(
              (p) =>
                  p.level == level &&
                  (showAll ||
                      p.end.compareTo(from) >= 0 &&
                          p.start.compareTo(to) <= 0) &&
                  (goalFilter == null || p.goalId == goalFilter) &&
                  match(p.title),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final goals = s.goals.where((g) => match(g.title)).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    return PageFrame(
      title: '计划表',
      subtitle: '一次看清一个层级。每日任务完成后勾选，未完成会自动顺延。',
      action: MainButton(
        '新增${planLevelNames[level]}',
        icon: Icons.add,
        onPressed: s.focusing
            ? null
            : () {
                if (level == 'day') {
                  editPlan(
                    context,
                    ref,
                    day: from.compareTo(s.dayKey) < 0 ? s.dayKey : from,
                    goalId: goalFilter,
                  );
                } else if (level == 'goal') {
                  editGoal(context, ref);
                } else {
                  editPeriod(context, ref, level, anchor(s));
                }
              },
      ),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in planLevelNames.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('view-${entry.key}'),
                    label: Text(entry.value),
                    selected: level == entry.key,
                    onSelected: (_) => setState(() {
                      level = entry.key;
                      query = '';
                      search.clear();
                      goalFilter = null;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (level != 'goal') ...[
          Row(
            children: [
              IconButton(
                tooltip: '上一个周期',
                onPressed: () => move(s, -1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  showAll
                      ? '全部${planLevelNames[level]}'
                      : from == to
                      ? from
                      : '$from\n$to',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '下一个周期',
                onPressed: () => move(s, 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('全部计划'),
                selected: showAll,
                onSelected: (v) => setState(() => all = v),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: const Text('选择日期'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: anchor(s),
                    firstDate: DateTime(s.now.year - 10),
                    lastDate: DateTime(s.now.year + 10),
                  );
                  if (d != null && mounted) {
                    setState(() {
                      selected = d;
                      all = false;
                    });
                  }
                },
              ),
              TextButton(
                onPressed: () => setState(() {
                  selected = s.now;
                  all = false;
                }),
                child: const Text('回到当前周期'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (s.goals.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey('goal-filter-$goalFilter-${s.goals.length}'),
              initialValue: s.goals.any((g) => g.id == goalFilter)
                  ? goalFilter ?? ''
                  : '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: '筛选总目标'),
              items: [
                const DropdownMenuItem(value: '', child: Text('所有目标与独立计划')),
                ...s.goals.map(
                  (g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(g.title, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => goalFilter = v == '' ? null : v),
            ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: search,
          key: const Key('task-search'),
          decoration: InputDecoration(
            hintText: '搜索${planLevelNames[level]}',
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 20),
        if (level == 'day') ...[
          Text(
            '${tasks.length} 项 · ${tasks.where((p) => p.done).length} 项已完成',
            style: const TextStyle(color: NestColors.muted),
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            const EmptyPanel(title: '这个日期还没有任务', body: '手动新增，或让 AI 安排一个具体行动。'),
          for (final p in tasks) taskTile(s, p),
        ] else if (level == 'goal') ...[
          if (goals.isEmpty)
            const EmptyPanel(
              title: '从一个总目标开始',
              body: '填写期望成果和截止日期，再按季度、月、周拆解。',
            ),
          for (final g in goals) goalTile(s, g),
        ] else ...[
          if (periods.isEmpty)
            EmptyPanel(
              title: '这个周期还没有${planLevelNames[level]}',
              body: '新增一个阶段成果；每日任务可单独安排，也可让 AI 一起拆解。',
            ),
          for (final p in periods) periodTile(s, p),
        ],
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => context.go('/agent'),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('用 AI 查询或调整计划'),
        ),
        const SizedBox(height: 12),
        const Text(
          '计时与完成分别记录。修改周期成果不会自动移动每日任务。',
          style: TextStyle(color: NestColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget taskTile(AppState s, Plan p) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SurfacePanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: ValueKey('done-${p.id}'),
            value: p.done,
            semanticLabel: '${p.done ? '取消完成' : '完成'} ${p.title}',
            onChanged: s.focusing
                ? null
                : (v) => showResult(
                    context,
                    ref
                        .read(appProvider.notifier)
                        .setTaskProgress(p.id, v == true ? p.units : 0),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: p.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${p.date} · ${p.time} · ${p.minutes} 分钟',
                  style: const TextStyle(fontSize: 12, color: NestColors.muted),
                ),
                if (p.goalId != null)
                  Text(
                    s.goals.where((g) => g.id == p.goalId).firstOrNull?.title ??
                        '独立任务',
                    style: const TextStyle(
                      fontSize: 12,
                      color: NestColors.green,
                    ),
                  ),
                if (p.rollovers > 0)
                  Text(
                    '原定 ${p.originalDate} · 已顺延 ${p.rollovers} 天',
                    style: const TextStyle(
                      fontSize: 12,
                      color: NestColors.orange,
                    ),
                  ),
                Wrap(
                  spacing: 4,
                  children: [
                    if (!p.done)
                      TextButton.icon(
                        onPressed: s.focusing || p.date != s.dayKey
                            ? null
                            : () {
                                ref.read(appProvider.notifier).dismissSession();
                                context.go('/focus?plan=${p.id}');
                              },
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('进入沉浸'),
                      ),
                    TextButton(
                      onPressed: s.focusing
                          ? null
                          : () => editPlan(context, ref, plan: p),
                      child: const Text('编辑'),
                    ),
                    if (p.units > 1)
                      TextButton(
                        onPressed: s.focusing
                            ? null
                            : () => editProgress(context, ref, p),
                        child: const Text('记录完成量'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '删除计划',
            onPressed: s.focusing ? null : () => remove('task', p.id, p.title),
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    ),
  );
  Widget periodTile(AppState s, PeriodPlan p) {
    final tasks =
        s.plans
            .where(
              (t) =>
                  t.date.compareTo(p.start) >= 0 &&
                  t.date.compareTo(p.end) <= 0 &&
                  t.goalId == p.goalId,
            )
            .toList()
          ..sort(
            (a, b) => '${a.date}${a.time}'.compareTo('${b.date}${b.time}'),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfacePanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.start == p.end ? p.start : '${p.start} — ${p.end}',
              style: const TextStyle(color: NestColors.green, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(p.title, style: Theme.of(context).textTheme.titleMedium),
            if (p.goalId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  s.goals.where((g) => g.id == p.goalId).firstOrNull?.title ??
                      '',
                  style: const TextStyle(color: NestColors.muted, fontSize: 12),
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: s.focusing
                      ? null
                      : () => editPeriod(context, ref, p.level, anchor(s), p),
                  child: const Text('编辑周期'),
                ),
                TextButton(
                  onPressed: s.focusing
                      ? null
                      : () => remove('period', p.id, p.title),
                  child: const Text('删除周期'),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('每日任务 · ${tasks.length} 项'),
              subtitle: Text('${tasks.where((t) => t.done).length} 项已完成'),
              children: [
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('尚未安排每日任务。'),
                  ),
                for (final t in tasks) taskTile(s, t),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget goalTile(AppState s, Goal g) {
    final tasks = s.plans.where((p) => p.goalId == g.id);
    final done =
        tasks.fold(0, (n, p) => n + p.doneUnits) +
        s.workspace.reviews.fold(0, (n, r) => n + (r.byGoal[g.id] ?? 0));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfacePanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(
              '截止 ${g.deadline} · 已完成 $done${g.unit} · 待办 ${tasks.where((p) => !p.done).length} 项',
              style: const TextStyle(color: NestColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: s.focusing
                      ? null
                      : () => editGoal(context, ref, g),
                  child: const Text('编辑目标'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      goalFilter = g.id;
                      level = 'day';
                      all = true;
                      query = '';
                      search.clear();
                    });
                  },
                  child: const Text('查看每日任务'),
                ),
                TextButton(
                  onPressed: s.focusing
                      ? null
                      : () => remove('goal', g.id, g.title),
                  child: const Text('删除目标'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
