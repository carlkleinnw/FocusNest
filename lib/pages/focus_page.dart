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
      title: '沉浸模式',
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
          const SizedBox(height: 14),
          _ProtectionGroup(),
          const SizedBox(height: 14),
          const Text(
            '单次 30—180 分钟 · 提前结束需两次确认 · 计时不会自动完成任务',
            style: TextStyle(fontSize: 12, color: NestColors.faint),
          ),
        ] else if (running) ...[
          _RunningGroup(
            session: session,
            now: s.now,
            onExit: () => requestFocusExit(context, ref),
          ),
          const SizedBox(height: 14),
          _ProtectionGroup(
            trailing: c.simulated
                ? TextButton(
                    onPressed: () => context.go('/demo'),
                    child: const Text('演示快进'),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          const Text(
            '提前结束后，这次记录会以「提前结束」保存，用时仍会计入明细。',
            style: TextStyle(fontSize: 12, color: NestColors.faint),
          ),
        ] else ...[
          _ResultGroup(session: session, message: s.message),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                c.dismissSession();
                context.go('/plans');
              },
              child: const Text('返回计划表'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: c.dismissSession,
              child: const Text('准备下一次专注'),
            ),
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
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          children: [
            if (task != null) ...[
              Text(
                task!.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: NestColors.inkSoft,
                ),
              ),
              const SizedBox(height: 18),
            ] else ...[
              TextField(
                key: const Key('focus-title'),
                controller: titleController,
                maxLength: 60,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '这段时间做什么',
                  counterText: '',
                  filled: true,
                  fillColor: NestColors.fill,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              '$minutes',
              style: const TextStyle(
                fontSize: 64,
                height: 1,
                fontWeight: FontWeight.w300,
                letterSpacing: -1,
                color: NestColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '分钟',
              style: TextStyle(fontSize: 13, color: NestColors.muted),
            ),
            const SizedBox(height: 20),
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
                  selected: !presets.contains(minutes),
                  onTap: onCustom,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 46,
        child: FilledButton(
          onPressed: busy ? null : onStart,
          child: Text(busy ? '正在开启…' : '确认并开始专注'),
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
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(4),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? NestColors.softOrange : NestColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected ? NestColors.orange : NestColors.lineStrong,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: selected ? NestColors.orangeDeep : NestColors.inkSoft,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _RunningGroup extends StatelessWidget {
  const _RunningGroup({
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
    final end = session.deadline;
    final endLabel =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: NestColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '专注中',
                style: TextStyle(fontSize: 13, color: NestColors.orangeDeep),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: NestColors.muted),
          ),
          const SizedBox(height: 12),
          Text(
            timerLabel(remaining),
            style: const TextStyle(
              fontSize: 64,
              height: 1,
              fontWeight: FontWeight.w300,
              letterSpacing: -1,
              color: NestColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '剩余 ${(remaining / 60).ceil()} 分钟',
                style: const TextStyle(fontSize: 13, color: NestColors.muted),
              ),
              Text(
                '预计 $endLabel 结束',
                style: const TextStyle(fontSize: 13, color: NestColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onExit,
            style: TextButton.styleFrom(foregroundColor: NestColors.danger),
            child: const Text('提前结束'),
          ),
        ],
      ),
    );
  }
}

class _ResultGroup extends StatelessWidget {
  const _ResultGroup({required this.session, required this.message});
  final FocusSession session;
  final String message;
  @override
  Widget build(BuildContext context) {
    final completed = session.status == FocusStatus.completed;
    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      child: Column(
        children: [
          Icon(
            completed
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            size: 44,
            color: completed ? NestColors.green : NestColors.faint,
          ),
          const SizedBox(height: 12),
          Text(
            completed ? '这一段，你坚持下来了' : '这次先停在这里',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: NestColors.ink,
            ),
          ),
          const SizedBox(height: 6),
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
            const SizedBox(height: 10),
            Text(
              '专注 ${session.minutes} 分钟',
              style: const TextStyle(fontSize: 13, color: NestColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProtectionGroup extends ConsumerWidget {
  const _ProtectionGroup({this.trailing});
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
        iconColor: ready ? NestColors.green : NestColors.amber,
        title: c.simulated
            ? '应用保护为模拟'
            : s.protectionReady
            ? '专注保护已连接'
            : '请先开启专注保护',
        subtitle: '使用开始时的白名单，电话和必要系统设置始终放行。',
        trailing:
            trailing ??
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: NestColors.faint,
            ),
        onTap: () => context.go('/apps'),
      ),
    );
  }
}
