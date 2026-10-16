import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../ui/components.dart';
import '../ui/planning_forms.dart';
import '../ui/theme.dart';
import 'agent_page.dart';

class PlansPage extends ConsumerStatefulWidget {
  const PlansPage({super.key, this.day, this.all = false});
  final String? day;
  final bool all;
  @override
  ConsumerState<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends ConsumerState<PlansPage> {
  String? selectedDay;
  String query = '';
  bool? all;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final controller = ref.read(appProvider.notifier);
    final day = selectedDay ?? widget.day ?? s.dayKey;
    final showAll = all ?? widget.all;
    final plans =
        s.plans
            .where(
              (p) =>
                  (showAll || p.date == day) &&
                  p.title.toLowerCase().contains(query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            final d = a.date.compareTo(b.date);
            return d != 0
                ? d
                : a.done != b.done
                ? (a.done ? 1 : -1)
                : a.time.compareTo(b.time);
          });
    final today = s.plans.where((p) => p.date == s.dayKey).toList();
    final minutes = today
        .where((p) => !p.done)
        .fold(0, (sum, p) => sum + p.minutes);
    return PageFrame(
      title: '今天，向目标靠近一点',
      subtitle:
          '${shortDate(s.now)} · ${today.where((p) => p.done).length}/${today.length} 项完成 · 未完成任务会自动顺延',
      action: MainButton(
        '新增计划',
        icon: Icons.add,
        onPressed: s.focusing
            ? null
            : () => editPlan(
                context,
                ref,
                day: day.compareTo(s.dayKey) < 0 ? s.dayKey : day,
              ),
      ),
      children: [
        if (minutes > s.dailyCapacity)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '今日待办共 $minutes 分钟，超过可用的 ${s.dailyCapacity} 分钟。可以调整日期或拆分，任务不会丢失。',
              style: const TextStyle(color: NestColors.orange),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('今天'),
              selected: !showAll && day == s.dayKey,
              onSelected: (_) => setState(() {
                all = false;
                selectedDay = s.dayKey;
              }),
            ),
            ChoiceChip(
              label: const Text('全部计划'),
              selected: showAll,
              onSelected: (_) => setState(() => all = true),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(showAll ? '选择日期' : day),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(day) ?? s.now,
                  firstDate: DateTime(s.now.year - 10),
                  lastDate: DateTime(s.now.year + 10),
                );
                if (picked != null && mounted) {
                  setState(() {
                    selectedDay = dateKey(picked);
                    all = false;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('task-search'),
          decoration: const InputDecoration(
            hintText: '搜索任务',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 16),
        if (plans.isEmpty)
          EmptyPanel(
            title: query.isEmpty ? '给今天留一个清晰的任务' : '没有匹配的任务',
            body: query.isEmpty ? '手动新增一件事，或告诉 AI 你想完成的目标。' : '试试其他关键词。',
          ),
        for (final plan in plans)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      key: ValueKey('done-${plan.id}'),
                      value: plan.done,
                      semanticLabel: plan.done
                          ? '取消完成 ${plan.title}'
                          : '完成 ${plan.title}',
                      onChanged: s.focusing
                          ? null
                          : (done) => showResult(
                              context,
                              controller.setTaskProgress(
                                plan.id,
                                done == true ? plan.units : 0,
                              ),
                            ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: plan.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: plan.done
                                  ? NestColors.muted
                                  : NestColors.ink,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${showAll ? '${plan.date} · ' : ''}${plan.time} · ${plan.minutes} 分钟${plan.done ? ' · 已完成' : ''}',
                            style: const TextStyle(
                              color: NestColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          if (plan.rollovers > 0)
                            Text(
                              '原定 ${plan.originalDate} · 已顺延 ${plan.rollovers} 天',
                              style: const TextStyle(
                                color: NestColors.orange,
                                fontSize: 12,
                              ),
                            ),
                          if (plan.goalId != null)
                            Text(
                              s.goals
                                      .where((g) => g.id == plan.goalId)
                                      .firstOrNull
                                      ?.title ??
                                  '学习目标',
                              style: const TextStyle(
                                color: NestColors.green,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (!plan.done)
                                TextButton.icon(
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  label: const Text('进入沉浸'),
                                  onPressed: s.focusing || plan.date != s.dayKey
                                      ? null
                                      : () {
                                          controller.dismissSession();
                                          context.go('/focus?plan=${plan.id}');
                                        },
                                ),
                              TextButton(
                                onPressed: s.focusing
                                    ? null
                                    : () => editPlan(context, ref, plan: plan),
                                child: const Text('编辑'),
                              ),
                              if (plan.units > 1)
                                TextButton(
                                  onPressed: s.focusing
                                      ? null
                                      : () => editProgress(context, ref, plan),
                                  child: const Text('记录完成量'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '删除计划',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: s.focusing
                          ? null
                          : () async {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('删除这项计划？'),
                                  content: Text(
                                    '「${plan.title}」会移除，已有专注计时仍保留。',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('保留'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('删除'),
                                    ),
                                  ],
                                ),
                              );
                              if (yes == true) controller.removePlan(plan.id);
                            },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.route_outlined),
            onPressed: () => context.go('/agent'),
            label: const Text('让 AI 帮我拆解目标'),
          ),
        ),
        if (s.workspace.roadmaps.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('目标路线', style: Theme.of(context).textTheme.titleLarge),
          for (final entry in s.workspace.roadmaps.entries)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('${(entry.value as Map)['title']}'),
              subtitle: Text(
                '${s.plans.where((p) => p.goalId == entry.key && p.done).length + s.workspace.reviews.fold(0, (n, r) => n + (r.byGoal[entry.key] ?? 0))} 项完成',
              ),
              children: [
                RoadmapPreview(
                  draft: Map<String, dynamic>.from(entry.value as Map),
                ),
              ],
            ),
        ],
        const SizedBox(height: 20),
        const Text(
          '专注计时与任务完成分别记录；完成后由你勾选确认。',
          style: TextStyle(color: NestColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
