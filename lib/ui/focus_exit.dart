import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'components.dart';

Future<void> requestFocusExit(BuildContext context, WidgetRef ref) async {
  final session = ref.read(appProvider).session;
  if (session == null) return;
  final first = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('再给自己一点时间？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusPill('确认 1 / 2'),
          const SizedBox(height: 18),
          Text('正在专注：${session.title}'),
          const SizedBox(height: 10),
          Text(
            '还剩 ${timerLabel(session.remainingSeconds(ref.read(appProvider).now))}。开始已经不容易，接下来只需要继续这一小段。',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('仍要退出'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('继续坚持'),
        ),
      ],
    ),
  );
  if (first != true || !context.mounted || !ref.read(appProvider).focusing) {
    return;
  }
  final second = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('确认结束这次专注？'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill('确认 2 / 2', warning: true),
          SizedBox(height: 18),
          Text('提前结束后，本次不会获得食物或重新领养资格。'),
          SizedBox(height: 12),
          Text('如果可以，试着回到眼前的一小步；如果需要离开，也可以之后重新开始。'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('确认结束'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('返回专注'),
        ),
      ],
    ),
  );
  if (second == true && context.mounted) {
    final result = await ref.read(appProvider.notifier).cancelFocus();
    if (context.mounted) showResult(context, result);
  }
}
