import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/ports.dart';
import '../ui/components.dart';
import '../ui/focus_exit.dart';
import '../ui/theme.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key, this.planId});
  final String? planId;
  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  final title = TextEditingController();
  int? selectedMinutes;
  bool busy = false;

  @override
  void didUpdateWidget(covariant FocusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planId != widget.planId) selectedMinutes = null;
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> customTime(int current) async {
    final input = TextEditingController(text: current.toString());
    String error = '';
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('自定义专注时长'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('custom-minutes'),
                controller: input,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '分钟（30—180）',
                  errorText: error.isEmpty ? null : error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(input.text);
                if (n == null || n < 30 || n > 180) {
                  set(() => error = '请输入30—180之间的整数');
                } else {
                  Navigator.pop(ctx, n);
                }
              },
              child: const Text('使用此时长'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    input.dispose();
    if (chosen != null && mounted) setState(() => selectedMinutes = chosen);
  }

  Future<void> start(int minutes) async {
    final s = ref.read(appProvider);
    final task = s.plans.where((p) => p.id == widget.planId).firstOrNull;
    if (widget.planId != null && task == null) {
      showResult(
        context,
        const OperationResult(false, 'MISSING_TASK', '任务已移除，请返回计划表。'),
      );
      return;
    }
    setState(() => busy = true);
    final result = await ref
        .read(appProvider.notifier)
        .start(
          Plan(
            id: task?.id ?? 'free_${DateTime.now().microsecondsSinceEpoch}',
            title:
                task?.title ??
                (title.text.trim().isEmpty ? '自由专注' : title.text.trim()),
            minutes: minutes,
            time: task?.time ?? '00:00',
          ),
        );
    if (!mounted) return;
    setState(() => busy = false);
    showResult(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final c = ref.read(appProvider.notifier);
    final task = s.plans.where((p) => p.id == widget.planId).firstOrNull;
    final session = s.session;
    final minutes = selectedMinutes ?? task?.minutes ?? 30;
    final running = session != null && s.focusing;
    return PageFrame(
      title: session == null
          ? '沉浸专注'
          : running
          ? '专注进行中'
          : '本次专注',
      subtitle: session == null
          ? (task == null ? '自由安排一段不被打扰的时间。' : '这次只做 · ${task.title}')
          : running
          ? '把手机放在一边，时间会替你留下记录。'
          : '计时结束，不会自动勾选任务。',
      children: [
        if (session == null) ...[
          _IdleFocus(
            task: task,
            minutes: minutes,
            busy: busy,
            titleController: title,
            onMinutes: (n) => setState(() => selectedMinutes = n),
            onCustom: () => customTime(minutes),
            onStart: () => start(minutes),
          ),
          const SizedBox(height: 16),
          const _ProtectionRow(),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              '单次 30—180 分钟 · 提前结束需两次确认 · 计时不会自动完成任务',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: NestColors.faint),
            ),
          ),
        ] else if (running) ...[
          _RunningHero(
            session: session,
            now: s.now,
            onExit: () => requestFocusExit(context, ref),
          ),
          const SizedBox(height: 16),
          _RunningFacts(session: session, now: s.now),
          const SizedBox(height: 16),
          _ProtectionRow(
            trailing: c.simulated
                ? TextButton(
                    onPressed: () => context.go('/demo'),
                    child: const Text('演示快进'),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              '提前结束后，这次记录会以「提前结束」保存，用时仍会计入明细。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: NestColors.faint),
            ),
          ),
        ] else ...[
          _ResultHero(session: session, message: s.message),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: MainButton(
                  '返回计划表',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () {
                    c.dismissSession();
                    context.go('/plans');
                  },
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: c.dismissSession,
                child: const Text('准备下一次专注'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _IdleFocus extends StatelessWidget {
  const _IdleFocus({
    required this.task,
    required this.minutes,
    required this.busy,
    required this.titleController,
    required this.onMinutes,
    required this.onCustom,
    required this.onStart,
  });
  final Plan? task;
  final int minutes;
  final bool busy;
  final TextEditingController titleController;
  final ValueChanged<int> onMinutes;
  final VoidCallback onCustom;
  final VoidCallback onStart;

  static const presets = [30, 45, 60, 90];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SurfacePanel(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Column(
          children: [
            if (task != null) ...[
              const Text(
                '本次任务',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: NestColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                task!.title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              MetaText(
                '${task!.date} ${task!.time} · 计划 ${task!.minutes} 分钟',
                icon: Icons.event_note_rounded,
              ),
            ] else
              TextField(
                key: const Key('focus-title'),
                controller: titleController,
                maxLength: 60,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: '这段时间做什么',
                  hintText: '例如：整理函数笔记',
                  counterText: '',
                ),
              ),
            const SizedBox(height: 14),
            _TimerOrb(minutes: minutes),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final n in {
                  ...presets,
                  if (!presets.contains(minutes)) minutes,
                })
                  _MinuteChip(
                    label: '$n 分钟',
                    selected: minutes == n,
                    onTap: () => onMinutes(n),
                  ),
                _MinuteChip(
                  label: '自定义',
                  icon: Icons.tune_rounded,
                  selected: !presets.contains(minutes),
                  onTap: onCustom,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 54,
        child: FilledButton.icon(
          onPressed: busy ? null : onStart,
          icon: const Icon(Icons.play_arrow_rounded, size: 22),
          label: Text(
            busy ? '正在开启…' : '确认并开始专注',
            style: const TextStyle(fontSize: 15.5),
          ),
        ),
      ),
    ],
  );
}

class _MinuteChip extends StatelessWidget {
  const _MinuteChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(NestRadius.pill),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? NestColors.orange : NestColors.paper,
        borderRadius: BorderRadius.circular(NestRadius.pill),
        border: Border.all(
          color: selected ? NestColors.orange : NestColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : NestColors.muted,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : NestColors.inkSoft,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Large number orb — the idle "how long" control.
class _TimerOrb extends StatelessWidget {
  const _TimerOrb({required this.minutes});
  final int minutes;
  @override
  Widget build(BuildContext context) => Container(
    width: 246,
    height: 246,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [Color(0xFFFFF6EF), Color(0xFFFFE9D8)],
        stops: [0.35, 1],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$minutes',
            style: const TextStyle(
              fontSize: 86,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: -2,
              color: NestColors.orangeDeep,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '分钟',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
              color: NestColors.orange,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RunningHero extends StatelessWidget {
  const _RunningHero({
    required this.session,
    required this.now,
    required this.onExit,
  });
  final FocusSession session;
  final DateTime now;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) {
    final remaining = session.remainingSeconds(now);
    final total = session.minutes * 60;
    final progress = total == 0 ? 0.0 : (total - remaining) / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NestColors.heroStart, NestColors.heroEnd],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2417181A),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x2EFF6900),
                  borderRadius: BorderRadius.circular(NestRadius.pill),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StaticDot(),
                    SizedBox(width: 6),
                    Text(
                      '保护中',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFB27A),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '剩余 ${(remaining / 60).ceil()} 分钟',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0x8CFFFFFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            session.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: FittedBox(
              child: Text(
                timerLabel(remaining),
                style: const TextStyle(
                  fontSize: 78,
                  height: 1.05,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -1.5,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: const Color(0x24FFFFFF),
              color: NestColors.orange,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: onExit,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x33FFFFFF)),
                backgroundColor: const Color(0x14FFFFFF),
              ),
              child: const Text('提前结束'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticDot extends StatelessWidget {
  const _StaticDot();
  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: const BoxDecoration(
      color: NestColors.orange,
      shape: BoxShape.circle,
    ),
  );
}

class _RunningFacts extends StatelessWidget {
  const _RunningFacts({required this.session, required this.now});
  final FocusSession session;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final end = session.deadline;
    final label =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return SurfacePanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: MetricTile(
              label: '本次时长',
              value: '${session.minutes}',
              unit: '分钟',
              icon: Icons.timelapse_rounded,
            ),
          ),
          Container(width: 1, height: 46, color: NestColors.line),
          const SizedBox(width: 18),
          Expanded(
            child: MetricTile(
              label: '预计结束',
              value: label,
              icon: Icons.flag_rounded,
              color: NestColors.blue,
              background: NestColors.softBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.session, required this.message});
  final FocusSession session;
  final String message;
  @override
  Widget build(BuildContext context) {
    final completed = session.status == FocusStatus.completed;
    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed ? NestColors.softGreen : NestColors.paper,
            ),
            child: Icon(
              completed ? Icons.check_rounded : Icons.pause_rounded,
              size: 42,
              color: completed ? NestColors.green : NestColors.muted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            completed ? '这一段，你坚持下来了' : '这次先停在这里',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: NestColors.muted,
            ),
          ),
          if (completed) ...[
            const SizedBox(height: 18),
            StatusPill(
              '专注 ${session.minutes} 分钟',
              icon: Icons.timelapse_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProtectionRow extends ConsumerWidget {
  const _ProtectionRow({this.trailing});
  final Widget? trailing;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(appProvider.notifier);
    final s = ref.watch(appProvider);
    final ready = s.protectionReady || c.simulated;
    return SurfacePanel(
      padding: EdgeInsets.zero,
      child: SettingsRow(
        icon: Icons.shield_outlined,
        iconColor: ready ? NestColors.green : NestColors.orange,
        iconBackground: ready ? NestColors.softGreen : NestColors.softOrange,
        title: c.simulated
            ? '应用保护为模拟'
            : s.protectionReady
            ? '专注保护已连接'
            : '请先开启专注保护',
        subtitle: '使用开始时的白名单，电话和必要系统设置始终放行。',
        trailing:
            trailing ??
            const Icon(Icons.chevron_right_rounded, color: NestColors.faint),
        onTap: () => context.go('/apps'),
      ),
    );
  }
}
