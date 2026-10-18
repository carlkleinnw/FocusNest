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

const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

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
  String? goalFilter;
  bool? all;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

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

  Future<void> pickDate(AppState s) async {
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

    final todays = s.plans.where((p) => p.date == s.dayKey).toList();
    final todayDone = todays.where((p) => p.done).length;
    final todayMinutes = s.records
        .where((r) => r.completed && dateKey(r.at) == s.dayKey)
        .fold(0, (n, r) => n + r.minutes);

    return PageFrame(
      title: '日程',
      subtitle: level == 'day' ? '今天安排的任务，按时间排好。' : '查看周、月、季与总目标的安排。',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            key: const Key('open-views'),
            onPressed: _openViews,
            icon: const Icon(Icons.view_agenda_outlined, size: 18),
            label: const Text('视图'),
            style: TextButton.styleFrom(
              foregroundColor: NestColors.link,
              visualDensity: VisualDensity.compact,
            ),
          ),
          TextButton.icon(
            onPressed: s.focusing ? null : () => _add(s, from),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('新增'),
            style: TextButton.styleFrom(
              foregroundColor: NestColors.link,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      children: [
        if (level == 'day' && !showAll)
          _WeekGroup(
            anchor: anchor(s),
            today: s.now,
            plans: s.plans,
            onSelect: (d) => setState(() {
              selected = d;
              all = false;
            }),
            onShift: (dir) => move(s, dir),
            onPickDate: () => pickDate(s),
          )
        else if (level != 'goal')
          _PeriodBar(
            label: showAll
                ? '全部${planLevelNames[level]}'
                : from == to
                ? from
                : '$from — $to',
            onPrev: () => move(s, -1),
            onNext: () => move(s, 1),
            onToday: () => setState(() {
              level = 'day';
              selected = s.now;
              all = false;
            }),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                level = 'day';
                selected = s.now;
                all = false;
              }),
              icon: const Icon(Icons.chevron_left_rounded, size: 18),
              label: const Text('回到日程'),
              style: TextButton.styleFrom(
                foregroundColor: NestColors.link,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        if (level == 'day' && !showAll) ...[
          const SizedBox(height: 10),
          _TodayLine(
            done: todayDone,
            total: todays.length,
            minutes: todayMinutes,
          ),
        ],
        if (level != 'goal') ...[
          const SizedBox(height: 10),
          _SearchBar(
            controller: search,
            hint: level == 'day' ? '搜索日程' : '搜索${planLevelNames[level]}',
            showAll: showAll,
            onQuery: (v) => setState(() => query = v),
            onToggleAll: () => setState(() => all = !showAll),
            goals: s.goals,
            goalFilter: goalFilter,
            onGoal: (v) => setState(() => goalFilter = v),
          ),
        ],
        const SizedBox(height: 14),
        if (level == 'day') ...[
          if (tasks.isEmpty)
            const EmptyPanel(
              title: '这个日期还没有任务',
              body: '手动新增，或让 AI 安排一个具体行动。',
              icon: Icons.checklist_rounded,
            )
          else
            _taskGroup([
              for (final p in tasks) taskTile(s, p, agenda: !showAll),
            ]),
        ] else if (level == 'goal') ...[
          if (goals.isEmpty)
            const EmptyPanel(
              title: '从一个总目标开始',
              body: '填写期望成果和截止日期，再按季度、月、周拆解。',
              icon: Icons.flag_outlined,
            )
          else
            SettingsGroup(children: [for (final g in goals) goalRow(s, g)]),
        ] else ...[
          if (periods.isEmpty)
            EmptyPanel(
              title: '这个周期还没有${planLevelNames[level]}',
              body: '新增一个阶段成果；每日任务可单独安排，也可让 AI 一起拆解。',
              icon: Icons.flag_outlined,
            )
          else
            for (final p in periods) periodGroup(s, p),
        ],
        const SizedBox(height: 18),
        SettingsGroup(
          children: [
            SettingsRow(
              title: '让 AI 调整计划',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: NestColors.faint,
              ),
              onTap: () => context.go('/agent'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '计时与完成分别记录 · 修改周期成果不会移动每日任务',
            style: TextStyle(fontSize: 12, color: NestColors.faint),
          ),
        ),
      ],
    );
  }

  Future<void> _openViews() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  '查看视图',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: NestColors.ink,
                  ),
                ),
              ),
              PillTabs(
                labels: const ['日', '周', '月', '季', '目标'],
                index: planLevelNames.keys.toList().indexOf(level),
                keys: [
                  for (final e in planLevelNames.entries) Key('view-${e.key}'),
                ],
                scrollable: false,
                onChanged: (i) {
                  Navigator.pop(ctx);
                  setState(() {
                    level = planLevelNames.keys.elementAt(i);
                    query = '';
                    search.clear();
                    goalFilter = null;
                  });
                },
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 10),
                child: Text(
                  '周、月、季与总目标用于查看长期安排。',
                  style: TextStyle(fontSize: 12, color: NestColors.faint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _add(AppState s, String from) {
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
  }

  String _shortGoal(String title) {
    final chars = title.characters;
    return chars.length > 12 ? '${chars.take(12)}…' : title;
  }

  String? _goalTitle(AppState s, Plan p) =>
      s.goals.where((g) => g.id == p.goalId).firstOrNull?.title;

  Widget _taskGroup(List<Widget> children) => SurfacePanel(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, indent: 16, endIndent: 0),
          children[i],
        ],
      ],
    ),
  );

  Widget taskTile(AppState s, Plan p, {bool agenda = false}) {
    final goal = _goalTitle(s, p);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (agenda)
            SizedBox(
              width: 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.time,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: NestColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p.minutes} 分钟',
                    style: const TextStyle(
                      fontSize: 11,
                      color: NestColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          if (agenda) const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _CheckCircle(
              key: ValueKey('done-${p.id}'),
              done: p.done,
              semanticLabel: '${p.done ? '取消完成' : '完成'} ${p.title}',
              onTap: s.focusing
                  ? null
                  : () => showResult(
                      context,
                      ref
                          .read(appProvider.notifier)
                          .setTaskProgress(p.id, p.done ? 0 : p.units),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: p.done ? NestColors.faint : NestColors.ink,
                    decoration: p.done ? TextDecoration.lineThrough : null,
                    decorationColor: NestColors.faint,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!agenda) ...[
                      MetaText('${p.date} ${p.time}'),
                      MetaText('${p.minutes} 分钟'),
                    ],
                    if (goal != null) TagLabel(_shortGoal(goal)),
                    if (p.units > 1)
                      TagLabel(
                        '${p.doneUnits}/${p.units}',
                        color: p.done ? NestColors.greenDeep : NestColors.muted,
                        background: p.done
                            ? NestColors.softGreen
                            : NestColors.tagBg,
                      ),
                  ],
                ),
                if (p.rollovers > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '原定 ${p.originalDate} · 已顺延 ${p.rollovers} 天',
                      style: const TextStyle(
                        fontSize: 12,
                        color: NestColors.amber,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 0,
                  children: [
                    if (!p.done)
                      TextButton(
                        onPressed: s.focusing || p.date != s.dayKey
                            ? null
                            : () {
                                ref.read(appProvider.notifier).dismissSession();
                                context.go('/focus?plan=${p.id}');
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: NestColors.orangeDeep,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('进入沉浸'),
                      ),
                    TextButton(
                      onPressed: s.focusing
                          ? null
                          : () => editPlan(context, ref, plan: p),
                      style: TextButton.styleFrom(
                        foregroundColor: NestColors.link,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('编辑'),
                    ),
                    if (p.units > 1)
                      TextButton(
                        onPressed: s.focusing
                            ? null
                            : () => editProgress(context, ref, p),
                        style: TextButton.styleFrom(
                          foregroundColor: NestColors.link,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('记录完成量'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '删除计划',
            visualDensity: VisualDensity.compact,
            onPressed: s.focusing ? null : () => remove('task', p.id, p.title),
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: NestColors.faint,
            ),
          ),
        ],
      ),
    );
  }

  Widget periodGroup(AppState s, PeriodPlan p) {
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
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfacePanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TagLabel(planLevelNames[p.level] ?? p.level),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.start == p.end ? p.start : '${p.start} — ${p.end}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: NestColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: NestColors.ink,
                    ),
                  ),
                  if (p.goalId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s.goals
                                .where((g) => g.id == p.goalId)
                                .firstOrNull
                                ?.title ??
                            '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: NestColors.muted,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 0,
                    children: [
                      TextButton(
                        onPressed: s.focusing
                            ? null
                            : () => editPeriod(
                                context,
                                ref,
                                p.level,
                                anchor(s),
                                p,
                              ),
                        style: TextButton.styleFrom(
                          foregroundColor: NestColors.link,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('编辑周期'),
                      ),
                      TextButton(
                        onPressed: s.focusing
                            ? null
                            : () => remove('period', p.id, p.title),
                        style: TextButton.styleFrom(
                          foregroundColor: NestColors.link,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('删除周期'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text(
                '每日任务',
                style: TextStyle(fontSize: 14, color: NestColors.muted),
              ),
              subtitle: Text(
                '${tasks.length} 项 · ${tasks.where((t) => t.done).length} 项已完成',
                style: const TextStyle(fontSize: 13),
              ),
              children: [
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '尚未安排每日任务。',
                      style: TextStyle(fontSize: 13, color: NestColors.muted),
                    ),
                  )
                else
                  for (var i = 0; i < tasks.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 0,
                      ),
                    taskTile(s, tasks[i]),
                  ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget goalRow(AppState s, Goal g) {
    final tasks = s.plans.where((p) => p.goalId == g.id);
    final done =
        tasks.fold(0, (n, p) => n + p.doneUnits) +
        s.workspace.reviews.fold(0, (n, r) => n + (r.byGoal[g.id] ?? 0));
    final ratio = g.totalUnits == 0
        ? 0.0
        : (done / g.totalUnits).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  g.title,
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
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: ratio, minHeight: 4),
          ),
          const SizedBox(height: 8),
          Text(
            '截止 ${g.deadline} · 已完成 $done/${g.totalUnits} ${g.unit} · 待办 ${tasks.where((p) => !p.done).length} 项',
            style: const TextStyle(fontSize: 13, color: NestColors.muted),
          ),
          Wrap(
            spacing: 0,
            children: [
              TextButton(
                onPressed: s.focusing ? null : () => editGoal(context, ref, g),
                style: TextButton.styleFrom(
                  foregroundColor: NestColors.link,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
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
                style: TextButton.styleFrom(
                  foregroundColor: NestColors.link,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('查看每日任务'),
              ),
              TextButton(
                onPressed: s.focusing
                    ? null
                    : () => remove('goal', g.id, g.title),
                style: TextButton.styleFrom(
                  foregroundColor: NestColors.link,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('删除目标'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayLine extends StatelessWidget {
  const _TodayLine({
    required this.done,
    required this.total,
    required this.minutes,
  });
  final int done, total, minutes;
  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : done / total;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '今天 $done / $total 项已完成',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: NestColors.muted),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '专注 $minutes 分钟',
                style: const TextStyle(fontSize: 13, color: NestColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: ratio, minHeight: 3),
        ),
      ],
    );
  }
}

class _WeekGroup extends StatelessWidget {
  const _WeekGroup({
    required this.anchor,
    required this.today,
    required this.plans,
    required this.onSelect,
    required this.onShift,
    required this.onPickDate,
  });
  final DateTime anchor, today;
  final List<Plan> plans;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onShift;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final start = anchor.subtract(Duration(days: anchor.weekday - 1));
    final monthLabel = anchor.month == start.month && start.day > 20
        ? '${start.year}年${start.month}月'
        : '${anchor.year}年${anchor.month}月';
    final isToday = dateKey(anchor) == dateKey(today);
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            Text(
              monthLabel,
              style: const TextStyle(fontSize: 13, color: NestColors.muted),
            ),
            const Spacer(),
            if (!isToday)
              TextButton(
                onPressed: () => onSelect(today),
                style: TextButton.styleFrom(
                  foregroundColor: NestColors.link,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('今天'),
              ),
            IconButton(
              tooltip: '选择日期',
              visualDensity: VisualDensity.compact,
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            IconButton(
              tooltip: '上一周',
              visualDensity: VisualDensity.compact,
              onPressed: () => onShift(-1),
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
            ),
            IconButton(
              tooltip: '下一周',
              visualDensity: VisualDensity.compact,
              onPressed: () => onShift(1),
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _DayCell(
                    date: start.add(Duration(days: i)),
                    today: today,
                    selected:
                        dateKey(start.add(Duration(days: i))) ==
                        dateKey(anchor),
                    hasTasks: plans.any(
                      (p) => p.date == dateKey(start.add(Duration(days: i))),
                    ),
                    done: plans
                        .where(
                          (p) =>
                              p.date == dateKey(start.add(Duration(days: i))),
                        )
                        .every((p) => p.done),
                    onTap: () => onSelect(start.add(Duration(days: i))),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.selected,
    required this.hasTasks,
    required this.done,
    required this.onTap,
  });
  final DateTime date, today;
  final bool selected, hasTasks, done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = dateKey(date) == dateKey(today);
    final color = selected
        ? NestColors.orange
        : isToday
        ? NestColors.ink
        : NestColors.inkSoft;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(
              _weekdayLabels[date.weekday - 1],
              style: const TextStyle(fontSize: 11, color: NestColors.muted),
            ),
            const SizedBox(height: 6),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? NestColors.softOrange : Colors.transparent,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: selected || isToday
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasTasks
                    ? (done ? NestColors.green : NestColors.orange)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });
  final String label;
  final VoidCallback onPrev, onNext, onToday;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Row(
      children: [
        IconButton(
          tooltip: '上一个周期',
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: NestColors.ink),
          ),
        ),
        TextButton(
          onPressed: onToday,
          style: TextButton.styleFrom(
            foregroundColor: NestColors.link,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 13),
          ),
          child: const Text('日程'),
        ),
        IconButton(
          tooltip: '下一个周期',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.showAll,
    required this.onQuery,
    required this.onToggleAll,
    required this.goals,
    required this.goalFilter,
    required this.onGoal,
  });
  final TextEditingController controller;
  final String hint;
  final bool showAll;
  final ValueChanged<String> onQuery;
  final VoidCallback onToggleAll;
  final List<Goal> goals;
  final String? goalFilter;
  final ValueChanged<String?> onGoal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: NestColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: NestColors.line),
            ),
            child: TextField(
              controller: controller,
              key: const Key('task-search'),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: NestColors.faint,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
              onChanged: onQuery,
            ),
          ),
        ),
        TextButton(
          onPressed: onToggleAll,
          style: TextButton.styleFrom(
            foregroundColor: showAll ? NestColors.orangeDeep : NestColors.link,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 13),
          ),
          child: const Text('全部'),
        ),
        if (goals.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: '筛选总目标',
            onSelected: (v) => onGoal(v == '' ? null : v),
            itemBuilder: (context) => [
              const PopupMenuItem(value: '', child: Text('所有目标与独立计划')),
              for (final g in goals)
                PopupMenuItem(value: g.id, child: Text(g.title)),
            ],
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: goalFilter == null
                    ? NestColors.surface
                    : NestColors.softOrange,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: goalFilter == null
                      ? NestColors.line
                      : NestColors.softOrange,
                ),
              ),
              child: Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: goalFilter == null
                    ? NestColors.muted
                    : NestColors.orangeDeep,
              ),
            ),
          ),
      ],
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    super.key,
    required this.done,
    required this.onTap,
    this.semanticLabel,
  });
  final bool done;
  final VoidCallback? onTap;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    checked: done,
    button: true,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? NestColors.green : Colors.transparent,
            border: Border.all(
              color: done ? NestColors.green : NestColors.faint,
              width: 1.4,
            ),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
        ),
      ),
    ),
  );
}
