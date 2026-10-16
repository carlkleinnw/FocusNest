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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final c = ref.read(appProvider.notifier);
    final task = s.plans.where((p) => p.id == widget.planId).firstOrNull;
    final session = s.session;
    final minutes = selectedMinutes ?? task?.minutes ?? 30;
    return PageFrame(
      title: '只做眼前这一件事',
      subtitle: task == null ? '自由安排一段不被打扰的时间。' : '从计划进入 · ${task.title}',
      children: [
        SurfacePanel(
          color: NestColors.softGreen,
          child: Column(
            children: [
              const SizedBox(height: 12),
              if (session == null) ...[
                if (task == null)
                  TextField(
                    key: const Key('focus-title'),
                    controller: title,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: '这段时间做什么',
                      hintText: '自由专注',
                    ),
                  )
                else
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 24),
                FittedBox(
                  child: Text(
                    '$minutes',
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w300,
                      color: NestColors.green,
                    ),
                  ),
                ),
                const Text('分钟', style: TextStyle(color: NestColors.green)),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final n in {
                      30,
                      45,
                      60,
                      90,
                      if (![30, 45, 60, 90].contains(minutes)) minutes,
                    })
                      ChoiceChip(
                        label: Text('$n 分钟'),
                        selected: minutes == n,
                        onSelected: (_) => setState(() => selectedMinutes = n),
                      ),
                    ActionChip(
                      label: const Text('自定义'),
                      avatar: const Icon(Icons.edit_outlined, size: 16),
                      onPressed: () => customTime(minutes),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                MainButton(
                  busy ? '正在开启…' : '确认并开始专注',
                  icon: Icons.play_arrow_rounded,
                  onPressed: busy
                      ? null
                      : () async {
                          if (widget.planId != null && task == null) {
                            showResult(
                              context,
                              const OperationResult(
                                false,
                                'MISSING_TASK',
                                '任务已移除，请返回计划表。',
                              ),
                            );
                            return;
                          }
                          setState(() => busy = true);
                          final result = await c.start(
                            Plan(
                              id:
                                  task?.id ??
                                  'free_${DateTime.now().microsecondsSinceEpoch}',
                              title:
                                  task?.title ??
                                  (title.text.trim().isEmpty
                                      ? '自由专注'
                                      : title.text.trim()),
                              minutes: minutes,
                              time: task?.time ?? '00:00',
                            ),
                          );
                          if (context.mounted) {
                            setState(() => busy = false);
                            showResult(context, result);
                          }
                        },
                ),
              ] else if (s.focusing) ...[
                const Icon(
                  Icons.lock_outline,
                  size: 32,
                  color: NestColors.green,
                ),
                const SizedBox(height: 20),
                Text(
                  session.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FittedBox(
                  child: Text(
                    timerLabel(session.remainingSeconds(s.now)),
                    style: const TextStyle(
                      fontSize: 76,
                      fontWeight: FontWeight.w300,
                      color: NestColors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value:
                      1 -
                      session.remainingSeconds(s.now) / (session.minutes * 60),
                  minHeight: 4,
                ),
                const SizedBox(height: 20),
                const Text('安心专注，时间会替你留下记录。'),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => requestFocusExit(context, ref),
                  child: const Text('提前结束'),
                ),
                if (c.simulated)
                  TextButton(
                    onPressed: () => context.go('/demo'),
                    child: const Text('演示：快进计时'),
                  ),
              ] else ...[
                Icon(
                  session.status == FocusStatus.completed
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  size: 52,
                  color: NestColors.green,
                ),
                const SizedBox(height: 20),
                Text(
                  session.status == FocusStatus.completed
                      ? '这一段，你坚持下来了'
                      : '这次先停在这里',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(s.message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                MainButton(
                  '返回今日计划',
                  onPressed: () {
                    c.dismissSession();
                    context.go('/plans');
                  },
                ),
                TextButton(
                  onPressed: c.dismissSession,
                  child: const Text('准备下一次专注'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.shield_outlined),
          title: Text(
            c.simulated
                ? '应用保护为模拟'
                : s.protectionReady
                ? '专注保护已连接'
                : '请先开启专注保护',
          ),
          subtitle: const Text('使用开始时的白名单，电话和必要系统设置始终放行。'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/apps'),
        ),
        const SizedBox(height: 12),
        const Text(
          '单次30—180分钟 · 提前结束需两次确认 · 计时不会自动完成任务',
          style: TextStyle(color: NestColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
