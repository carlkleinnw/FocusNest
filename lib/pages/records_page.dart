import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/review_engine.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});
  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  bool busy = false;
  String message = '';
  String filter = 'all';
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final reviews =
        s.workspace.reviews
            .where((r) => filter == 'all' || r.level == filter)
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final tasks = s.plans.where((p) => p.done).toList()
      ..sort(
        (a, b) => (b.completedAt ?? b.date).compareTo(a.completedAt ?? a.date),
      );
    final total =
        s.records
            .where((r) => r.completed && !r.virtual)
            .fold(0, (n, r) => n + r.minutes) +
        s.workspace.reviews.fold(0, (n, r) => n + r.minutes);
    return PageFrame(
      title: '每一步，都留下回响',
      subtitle: '完整专注 $total 分钟 · 提前结束的用时另记在明细中，任务由你确认完成。',
      action: MainButton(
        busy ? '正在复盘…' : '复盘并压缩',
        icon: Icons.auto_awesome_outlined,
        onPressed: busy || s.focusing
            ? null
            : () async {
                setState(() => busy = true);
                final result = await ref
                    .read(appProvider.notifier)
                    .summarizeDue();
                if (mounted) {
                  setState(() {
                    busy = false;
                    message = result.message;
                  });
                }
              },
      ),
      children: [
        Text(
          message.isNotEmpty
              ? message
              : s.message.startsWith('复盘：')
              ? s.message
              : nextReview(s) == null
              ? '本周期明细保留中，结束后才能生成正式复盘。'
              : '有已结束的周期可以复盘。',
          style: const TextStyle(color: NestColors.green),
        ),
        const SizedBox(height: 12),
        const Text(
          '周 → 月 → 季 → 年逐级压缩。统计由程序核算；关键任务引用原文。建议是 AI 的下一步建议，不是已完成事实。',
          style: TextStyle(color: NestColors.muted),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in {
              'all': '全部',
              'week': '周',
              'month': '月',
              'quarter': '季',
              'year': '年',
            }.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: filter == e.key,
                onSelected: (_) => setState(() => filter = e.key),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (reviews.isEmpty)
          const EmptyPanel(
            title: '复盘会在这里积累',
            body: '先执行计划、勾选完成。周期结束后可手动复盘，或在设置中开启自动复盘。',
          ),
        for (final r in reviews)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              '${{'week': '周', 'month': '月', 'quarter': '季度', 'year': '年度'}[r.level]}复盘 · ${r.start}',
            ),
            subtitle: Text('${r.tasks} 项完成 · ${r.minutes} 分钟专注'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '周期：${r.start} — ${dateKey(DateTime.parse(r.end).subtract(const Duration(days: 1)))}',
                    ),
                    Text(
                      '用户确认完成 ${r.tasks} 项 · 完成量 ${r.units} · 完整专注 ${r.sessions} 次 / ${r.minutes} 分钟 · 提前结束 ${r.cancelledMinutes} 分钟',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '关键记录（摘自原文）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final h in r.highlights)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(h),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      '下一步建议',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(r.advice),
                    const SizedBox(height: 12),
                    Text(
                      '基于 ${r.sources} 条来源 · SHA-256 ${r.digest.substring(0, 12)}…',
                      style: const TextStyle(
                        color: NestColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 32),
        Text('尚未压缩的完成任务', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (tasks.isEmpty) const Text('完成任务后，回到计划表勾选即可记录。'),
        for (final p in tasks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.task_alt, color: NestColors.green),
            title: Text(p.title),
            subtitle: Text(
              p.completedAt == null
                  ? '旧版完成任务：完成日期未知，暂不压缩'
                  : '确认完成于 ${p.completedAt!.substring(0, 10)} · 完成量 ${p.doneUnits}',
            ),
          ),
        const SizedBox(height: 24),
        Text('专注计时明细', style: Theme.of(context).textTheme.titleLarge),
        if (s.records.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('还没有专注记录。'),
          ),
        for (final r in s.records)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              r.completed ? Icons.timer_outlined : Icons.pause_circle_outline,
            ),
            title: Text(r.title),
            subtitle: Text(
              '${dateKey(r.at)} · ${r.minutes} 分钟 · ${r.completed ? '完整完成' : '提前结束'}${r.virtual ? ' · 虚拟演示' : ''}',
            ),
          ),
      ],
    );
  }
}
