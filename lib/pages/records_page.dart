import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/journal.dart';
import '../core/models.dart';
import '../core/review_engine.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

const _levelLabels = {
  'week': '周复盘',
  'month': '月复盘',
  'quarter': '季复盘',
  'year': '年复盘',
};

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});
  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  bool busy = false;
  String message = '';
  String filter = 'all';

  static const filters = ['all', 'week', 'month', 'quarter', 'year'];
  static const filterLabels = ['全部', '周', '月', '季', '年'];

  String _duration(int minutes) {
    if (minutes < 180) return '$minutes';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h' : '$h.${(m / 60 * 10).round()}';
  }

  String _durationUnit(int minutes) => minutes < 180 ? '分钟' : '小时';

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
    final int total =
        s.records
            .where((r) => r.completed && !r.virtual)
            .fold(0, (n, r) => n + r.minutes) +
        s.workspace.reviews.fold(0, (n, r) => n + r.minutes);
    final weekStart = DateTime(
      s.now.year,
      s.now.month,
      s.now.day,
    ).subtract(Duration(days: s.now.weekday - 1));
    final weekMinutes = s.records
        .where((r) => r.completed && !r.virtual && !r.at.isBefore(weekStart))
        .fold<int>(0, (n, r) => n + r.minutes);
    final status = message.isNotEmpty
        ? message
        : s.message.startsWith('复盘：')
        ? s.message
        : nextReview(s) == null
        ? '本周期明细保留中，结束后才能生成正式复盘。'
        : '有已结束的周期可以复盘。';

    return PageFrame(
      title: '复盘',
      subtitle: '周、月、季、年逐级压缩。统计由程序核算，建议由 AI 给出。',
      action: TextButton(
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
        child: Text(busy ? '正在复盘…' : '复盘并压缩'),
      ),
      children: [
        SurfacePanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MetricRow(
                left: ('累计专注', _duration(total), _durationUnit(total)),
                right: ('已完成任务', '${tasks.length}', '项'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 0),
              _MetricRow(
                left: (
                  '本周专注',
                  _duration(weekMinutes),
                  _durationUnit(weekMinutes),
                ),
                right: ('复盘记录', '${s.workspace.reviews.length}', '份'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SurfacePanel(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: NestColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 14),
        PillTabs(
          labels: filterLabels,
          index: filters.indexOf(filter),
          onChanged: (i) => setState(() => filter = filters[i]),
        ),
        const SizedBox(height: 14),
        if (reviews.isEmpty)
          const EmptyPanel(
            title: '复盘会在这里积累',
            body: '先执行计划、勾选完成。周期结束后可手动复盘，或在设置中开启自动复盘。',
            icon: Icons.auto_stories_outlined,
          ),
        for (final r in reviews) _ReviewCard(review: r),
        const SizedBox(height: 20),
        const SectionTitle('尚未压缩的完成任务'),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '完成任务后，回到计划表勾选即可记录。',
              style: TextStyle(fontSize: 13, color: NestColors.muted),
            ),
          )
        else
          SettingsGroup(
            children: [
              for (final p in tasks)
                SettingsRow(
                  title: p.title,
                  subtitle: p.completedAt == null
                      ? '旧版完成任务：完成日期未知，暂不压缩'
                      : '${p.completedAt!.substring(0, 10)} 确认完成 · 完成量 ${p.doneUnits}',
                ),
            ],
          ),
        const SizedBox(height: 20),
        const SectionTitle('专注计时明细'),
        if (s.records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '还没有专注记录。',
              style: TextStyle(fontSize: 13, color: NestColors.muted),
            ),
          )
        else
          SettingsGroup(
            children: [
              for (final r in s.records)
                SettingsRow(
                  title: r.title,
                  subtitle:
                      '${dateKey(r.at)} · ${r.minutes} 分钟 · ${r.completed ? '完整完成' : '提前结束'}${r.virtual ? ' · 虚拟演示' : ''}',
                ),
            ],
          ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '压缩后只保留统计和最多 6 条关键任务原文',
            style: TextStyle(fontSize: 12, color: NestColors.faint),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.left, required this.right});
  final (String, String, String) left, right;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: MetricTile(label: left.$1, value: left.$2, unit: left.$3),
        ),
      ),
      Container(width: 1, height: 44, color: NestColors.line),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: MetricTile(label: right.$1, value: right.$2, unit: right.$3),
        ),
      ),
    ],
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Review review;
  @override
  Widget build(BuildContext context) {
    final end = dateKey(
      DateTime.parse(review.end).subtract(const Duration(days: 1)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfacePanel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TagLabel(_levelLabels[review.level] ?? '复盘'),
                const Spacer(),
                Text(
                  '${review.start} — $end',
                  style: const TextStyle(fontSize: 12, color: NestColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${review.tasks} 项完成 · ${review.minutes} 分钟专注',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: NestColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '完整专注 ${review.sessions} 次 · 完成量 ${review.units} · 提前结束 ${review.cancelledMinutes} 分钟',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: NestColors.muted,
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                '查看复盘细节',
                style: TextStyle(fontSize: 14, color: NestColors.link),
              ),
              childrenPadding: const EdgeInsets.only(bottom: 10),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '周期：${review.start} — $end',
                        style: const TextStyle(
                          fontSize: 13,
                          color: NestColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '用户确认完成 ${review.tasks} 项 · 完成量 ${review.units} · 完整专注 ${review.sessions} 次 / ${review.minutes} 分钟 · 提前结束 ${review.cancelledMinutes} 分钟',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: NestColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '关键记录（摘自原文）',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: NestColors.ink,
                        ),
                      ),
                      for (final h in review.highlights)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            h,
                            style: const TextStyle(fontSize: 13, height: 1.6),
                          ),
                        ),
                      const SizedBox(height: 14),
                      const Text(
                        '下一步建议',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: NestColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NestColors.fill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          review.advice,
                          style: const TextStyle(fontSize: 13, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '基于 ${review.sources} 条来源 · SHA-256 ${review.digest.substring(0, 12)}…',
                        style: const TextStyle(
                          fontSize: 11,
                          color: NestColors.faint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
