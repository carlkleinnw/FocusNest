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
      subtitle: '周、月、季、年逐级压缩。统计由程序核算，建议由 AI 给出，不是已完成事实。',
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
        SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: '累计专注',
                      value: _duration(total),
                      unit: _durationUnit(total),
                      icon: Icons.timelapse_rounded,
                    ),
                  ),
                  Container(width: 1, height: 50, color: NestColors.line),
                  const SizedBox(width: 18),
                  Expanded(
                    child: MetricTile(
                      label: '已完成任务',
                      value: '${tasks.length}',
                      unit: '项',
                      icon: Icons.task_alt_rounded,
                      color: NestColors.green,
                      background: NestColors.softGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: '本周专注',
                      value: _duration(weekMinutes),
                      unit: _durationUnit(weekMinutes),
                      icon: Icons.date_range_rounded,
                      color: NestColors.blue,
                      background: NestColors.softBlue,
                    ),
                  ),
                  Container(width: 1, height: 50, color: NestColors.line),
                  const SizedBox(width: 18),
                  Expanded(
                    child: MetricTile(
                      label: '复盘记录',
                      value: '${s.workspace.reviews.length}',
                      unit: '份',
                      icon: Icons.auto_stories_rounded,
                      color: NestColors.orangeDeep,
                      background: NestColors.softOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SurfacePanel(
          padding: EdgeInsets.zero,
          child: SettingsRow(
            icon: Icons.insights_rounded,
            iconColor: NestColors.orangeDeep,
            iconBackground: NestColors.softOrange,
            title: status,
            subtitle: '周期结束后可手动复盘，或在设置中开启自动复盘。',
          ),
        ),
        const SizedBox(height: 20),
        PillTabs(
          labels: filterLabels,
          index: filters.indexOf(filter),
          onChanged: (i) => setState(() => filter = filters[i]),
        ),
        const SizedBox(height: 18),
        if (reviews.isEmpty)
          const EmptyPanel(
            title: '复盘会在这里积累',
            body: '先执行计划、勾选完成。周期结束后可手动复盘，或在设置中开启自动复盘。',
            icon: Icons.auto_stories_outlined,
          ),
        for (final r in reviews) _ReviewCard(review: r),
        const SizedBox(height: 26),
        const SectionTitle('尚未压缩的完成任务'),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
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
                  icon: Icons.check_rounded,
                  iconColor: NestColors.green,
                  iconBackground: NestColors.softGreen,
                  title: p.title,
                  subtitle: p.completedAt == null
                      ? '旧版完成任务：完成日期未知，暂不压缩'
                      : '${p.completedAt!.substring(0, 10)} 确认完成 · 完成量 ${p.doneUnits}',
                ),
            ],
          ),
        const SizedBox(height: 26),
        const SectionTitle('专注计时明细'),
        if (s.records.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
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
                  icon: r.completed
                      ? Icons.timelapse_rounded
                      : Icons.pause_rounded,
                  iconColor: r.completed
                      ? NestColors.orangeDeep
                      : NestColors.muted,
                  iconBackground: r.completed
                      ? NestColors.softOrange
                      : NestColors.paper,
                  title: r.title,
                  subtitle:
                      '${dateKey(r.at)} · ${r.minutes} 分钟 · ${r.completed ? '完整完成' : '提前结束'}${r.virtual ? ' · 虚拟演示' : ''}',
                ),
            ],
          ),
        const SizedBox(height: 20),
        const Text(
          '压缩后只保留统计和最多 6 条关键任务原文，逐项明细无法恢复。',
          style: TextStyle(fontSize: 11.5, color: NestColors.faint),
        ),
      ],
    );
  }
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
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TagLabel(
                  _levelLabels[review.level] ?? '复盘',
                  color: NestColors.orangeDeep,
                  background: NestColors.softOrange,
                  icon: Icons.auto_stories_rounded,
                ),
                const Spacer(),
                Text(
                  '${review.start} — $end',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: NestColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${review.tasks} 项完成 · ${review.minutes} 分钟专注',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    '完整专注',
                    '${review.sessions} 次',
                    Icons.local_fire_department_rounded,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    '完成量',
                    '${review.units}',
                    Icons.functions_rounded,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    '提前结束',
                    '${review.cancelledMinutes} 分',
                    Icons.pause_circle_outline_rounded,
                  ),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: const Text('查看复盘细节'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '周期：${review.start} — $end',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: NestColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '用户确认完成 ${review.tasks} 项 · 完成量 ${review.units} · 完整专注 ${review.sessions} 次 / ${review.minutes} 分钟 · 提前结束 ${review.cancelledMinutes} 分钟',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.6,
                          color: NestColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '关键记录（摘自原文）',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: NestColors.ink,
                        ),
                      ),
                      for (final h in review.highlights)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 7, right: 8),
                                child: SizedBox(
                                  width: 4,
                                  height: 4,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: NestColors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  h,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        '下一步建议',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: NestColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NestColors.paper,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          review.advice,
                          style: const TextStyle(fontSize: 13, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 12),
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 13, color: NestColors.faint),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: NestColors.muted),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: NestColors.ink,
        ),
      ),
    ],
  );
}
