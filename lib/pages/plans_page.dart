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
      title: '计划表',
      subtitle: '一次看清一个层级。每日任务完成后勾选，未完成会自动顺延。',
      action: MainButton(
        '新增${planLevelNames[level]}',
        icon: Icons.add_rounded,
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
        _TodayOverview(
          now: s.now,
          done: todayDone,
          total: todays.length,
          minutes: todayMinutes,
        ),
        const SizedBox(height: 18),
        PillTabs(
          labels: const ['日', '周', '月', '季', '目标'],
          index: planLevelNames.keys.toList().indexOf(level),
          keys: [for (final e in planLevelNames.entries) Key('view-${e.key}')],
          onChanged: (i) {
            setState(() {
              level = planLevelNames.keys.elementAt(i);
              query = '';
              search.clear();
              goalFilter = null;
            });
          },
        ),
        const SizedBox(height: 14),
        if (level == 'day' && !showAll)
          _WeekStrip(
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
        else if (level != 'goal') ...[
          Row(
            children: [
              IconButton(
                tooltip: '上一个周期',
                onPressed: () => move(s, -1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  showAll
                      ? '全部${planLevelNames[level]}'
                      : from == to
                      ? from
                      : '$from — $to',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NestColors.ink,
                  ),
                ),
              ),
              _RoundIcon(
                icon: Icons.event_outlined,
                tooltip: '选择日期',
                onTap: () => pickDate(s),
              ),
              IconButton(
                tooltip: '下一个周期',
                onPressed: () => move(s, 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
        if (level != 'goal') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: search,
                    key: const Key('task-search'),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '搜索${planLevelNames[level]}',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: NestColors.faint,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 42,
                        minHeight: 40,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      fillColor: NestColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: NestColors.orange,
                          width: 1.4,
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TogglePill(
                label: '全部',
                selected: showAll,
                onTap: () => setState(() => all = !showAll),
              ),
              if (s.goals.isNotEmpty) ...[
                const SizedBox(width: 6),
                _GoalFilterButton(
                  goals: s.goals,
                  value: goalFilter,
                  onChanged: (v) => setState(() => goalFilter = v),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (level == 'day') ...[
          _CountLine(
            total: tasks.length,
            done: tasks.where((p) => p.done).length,
            label: '项任务',
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            const EmptyPanel(title: '这个日期还没有任务', body: '手动新增，或让 AI 安排一个具体行动。')
          else
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
        const SizedBox(height: 22),
        SurfacePanel(
          padding: EdgeInsets.zero,
          child: SettingsRow(
            icon: Icons.auto_awesome_outlined,
            title: '用 AI 查询或调整计划',
            subtitle: '说目标、补充条件，或直接增删改已有安排。',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: NestColors.faint,
            ),
            onTap: () => context.go('/agent'),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '计时与完成分别记录。修改周期成果不会自动移动每日任务。',
          style: TextStyle(color: NestColors.faint, fontSize: 11.5),
        ),
      ],
    );
  }

  String _shortGoal(String title) {
    final chars = title.characters;
    return chars.length > 10 ? '${chars.take(10)}…' : title;
  }

  Widget taskTile(AppState s, Plan p) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SurfacePanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckCircle(
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
            // Keep the original checkbox semantics key for existing widgets.
            key: ValueKey('done-${p.id}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    p.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: p.done ? NestColors.muted : NestColors.ink,
                      decoration: p.done ? TextDecoration.lineThrough : null,
                      decorationColor: NestColors.faint,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MetaText(
                      '${p.date} · ${p.time}',
                      icon: Icons.event_rounded,
                    ),
                    MetaText('${p.minutes} 分钟', icon: Icons.timelapse_rounded),
                    if (p.goalId != null)
                      TagLabel(
                        _shortGoal(
                          s.goals
                                  .where((g) => g.id == p.goalId)
                                  .firstOrNull
                                  ?.title ??
                              '独立任务',
                        ),
                      ),
                    if (p.units > 1)
                      TagLabel(
                        '${p.doneUnits} / ${p.units}',
                        color: p.done
                            ? NestColors.green
                            : NestColors.orangeDeep,
                        background: p.done
                            ? NestColors.softGreen
                            : NestColors.softOrange,
                      ),
                  ],
                ),
                if (p.rollovers > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '原定 ${p.originalDate} · 已顺延 ${p.rollovers} 天',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: NestColors.orangeDeep,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 2,
                  children: [
                    if (!p.done)
                      TextButton.icon(
                        onPressed: s.focusing || p.date != s.dayKey
                            ? null
                            : () {
                                ref.read(appProvider.notifier).dismissSession();
                                context.go('/focus?plan=${p.id}');
                              },
                        icon: const Icon(Icons.play_arrow_rounded, size: 17),
                        label: const Text('进入沉浸'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    TextButton(
                      onPressed: s.focusing
                          ? null
                          : () => editPlan(context, ref, plan: p),
                      style: TextButton.styleFrom(
                        foregroundColor: NestColors.muted,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('编辑'),
                    ),
                    if (p.units > 1)
                      TextButton(
                        onPressed: s.focusing
                            ? null
                            : () => editProgress(context, ref, p),
                        style: TextButton.styleFrom(
                          foregroundColor: NestColors.muted,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfacePanel(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TagLabel(
                  planLevelNames[p.level] ?? p.level,
                  color: NestColors.orangeDeep,
                  background: NestColors.softOrange,
                  icon: Icons.flag_rounded,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.start == p.end ? p.start : '${p.start} — ${p.end}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: NestColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(p.title, style: Theme.of(context).textTheme.titleLarge),
            if (p.goalId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  s.goals.where((g) => g.id == p.goalId).firstOrNull?.title ??
                      '',
                  style: const TextStyle(color: NestColors.muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: s.focusing
                      ? null
                      : () => editPeriod(context, ref, p.level, anchor(s), p),
                  style: TextButton.styleFrom(
                    foregroundColor: NestColors.muted,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('编辑周期'),
                ),
                TextButton(
                  onPressed: s.focusing
                      ? null
                      : () => remove('period', p.id, p.title),
                  style: TextButton.styleFrom(
                    foregroundColor: NestColors.muted,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('删除周期'),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('每日任务'),
              subtitle: Text(
                '${tasks.length} 项 · ${tasks.where((t) => t.done).length} 项已完成',
              ),
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
    final ratio = g.totalUnits == 0
        ? 0.0
        : (done / g.totalUnits).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfacePanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    g.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${(ratio * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: NestColors.orangeDeep,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: ratio, minHeight: 6),
            ),
            const SizedBox(height: 10),
            Text(
              '截止 ${g.deadline} · 已完成 $done ${g.unit} · 待办 ${tasks.where((p) => !p.done).length} 项',
              style: const TextStyle(color: NestColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: s.focusing
                      ? null
                      : () => editGoal(context, ref, g),
                  style: TextButton.styleFrom(
                    foregroundColor: NestColors.muted,
                    visualDensity: VisualDensity.compact,
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
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('查看每日任务'),
                ),
                TextButton(
                  onPressed: s.focusing
                      ? null
                      : () => remove('goal', g.id, g.title),
                  style: TextButton.styleFrom(
                    foregroundColor: NestColors.muted,
                    visualDensity: VisualDensity.compact,
                  ),
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

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({
    required this.now,
    required this.done,
    required this.total,
    required this.minutes,
  });
  final DateTime now;
  final int done, total, minutes;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : done / total;
    final week = _weekdayLabels[now.weekday - 1];
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NestColors.heroStart, NestColors.heroEnd],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F17181A),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -34,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x3DFF6900), Color(0x00FF6900)],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: NestColors.orange,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '今天 · ${shortDate(now)} 周$week',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xA6FFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$done',
                          style: const TextStyle(
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          ' / $total 项',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0x8CFFFFFF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      total == 0
                          ? '今天还没有安排，添加第一项任务吧。'
                          : done == total
                          ? '今天的任务都完成了，很好。'
                          : '已完成 ${(ratio * 100).round()}% · 今日专注 $minutes 分钟',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Color(0x99FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ProgressRing(
                value: ratio,
                size: 66,
                stroke: 7,
                gradient: const SweepGradient(
                  colors: [Color(0xFFFFA45C), NestColors.orange],
                ),
                trackColor: const Color(0x1FFFFFFF),
                child: Text(
                  '${(ratio * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
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
            Text(
              monthLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: NestColors.ink,
              ),
            ),
            const Spacer(),
            if (!isToday)
              TextButton(
                onPressed: () => onSelect(today),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('今天'),
              ),
            _RoundIcon(
              icon: Icons.event_outlined,
              tooltip: '选择日期',
              onTap: onPickDate,
            ),
            const SizedBox(width: 6),
            _RoundIcon(
              icon: Icons.chevron_left_rounded,
              tooltip: '上一周',
              onTap: () => onShift(-1),
            ),
            const SizedBox(width: 6),
            _RoundIcon(
              icon: Icons.chevron_right_rounded,
              tooltip: '下一周',
              onTap: () => onShift(1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                    plans: plans
                        .where(
                          (p) =>
                              p.date == dateKey(start.add(Duration(days: i))),
                        )
                        .toList(),
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
    required this.plans,
    required this.onTap,
  });
  final DateTime date, today;
  final bool selected;
  final List<Plan> plans;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = dateKey(date) == dateKey(today);
    final done = plans.isNotEmpty && plans.every((p) => p.done);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              _weekdayLabels[date.weekday - 1],
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: selected
                    ? NestColors.orangeDeep
                    : isToday
                    ? NestColors.ink
                    : NestColors.faint,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? NestColors.orange
                    : isToday
                    ? NestColors.paper
                    : Colors.transparent,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : isToday
                      ? NestColors.ink
                      : NestColors.inkSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 5,
              child: plans.isEmpty
                  ? null
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? NestColors.green : NestColors.orange,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? NestColors.softOrange : NestColors.surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 62,
        height: 46,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? NestColors.orangeDeep : NestColors.muted,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: NestColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 20, color: NestColors.inkSoft),
        ),
      ),
    ),
  );
}

class _CountLine extends StatelessWidget {
  const _CountLine({
    required this.total,
    required this.done,
    required this.label,
  });
  final int total, done;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '$total $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: NestColors.ink,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: done == total && total > 0
              ? NestColors.softGreen
              : NestColors.paperDeep,
          borderRadius: BorderRadius.circular(NestRadius.pill),
        ),
        child: Text(
          '$done 已完成',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: done == total && total > 0
                ? NestColors.green
                : NestColors.muted,
          ),
        ),
      ),
    ],
  );
}

class _GoalFilterButton extends StatelessWidget {
  const _GoalFilterButton({
    required this.goals,
    required this.value,
    required this.onChanged,
  });
  final List<Goal> goals;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return const SizedBox(width: 46, height: 46);
    }
    return PopupMenuButton<String>(
      tooltip: '筛选总目标',
      onSelected: (v) => onChanged(v == '' ? null : v),
      itemBuilder: (context) => [
        const PopupMenuItem(value: '', child: Text('所有目标与独立计划')),
        for (final g in goals)
          PopupMenuItem(
            value: g.id,
            child: Text(g.title, overflow: TextOverflow.ellipsis),
          ),
      ],
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: value == null ? NestColors.surface : NestColors.softOrange,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.filter_list_rounded,
          size: 20,
          color: value == null ? NestColors.inkSoft : NestColors.orangeDeep,
        ),
      ),
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
          duration: const Duration(milliseconds: 160),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? NestColors.green : Colors.transparent,
            border: Border.all(
              color: done ? NestColors.green : NestColors.faint,
              width: 1.6,
            ),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
        ),
      ),
    ),
  );
}
