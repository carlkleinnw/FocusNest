import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class RestPage extends ConsumerWidget {
  const RestPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    return PageFrame(
      title: '也给休息留个位置',
      subtitle: '提前安排休息日。休息期间暂停饥饿，已经过去的日期不能补改。',
      eyebrow: 'REST IS PART OF THE PLAN',
      children: [
        SurfacePanel(
          color: NestColors.softGreen,
          child: Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, color: NestColors.green),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '今天是${shortDate(state.now)}，${state.resting ? '已提前安排休息，饥饿暂停。' : '学习日。今天不能临时补设为休息日。'}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(14, (index) {
            final date = DateTime(
              state.now.year,
              state.now.month,
              state.now.day + index + 1,
            );
            final selected = state.restDates.contains(dateKey(date));
            return SizedBox(
              width: 142,
              height: 118,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: selected
                      ? NestColors.softGreen
                      : NestColors.surface,
                  side: BorderSide(
                    color: selected ? NestColors.green : NestColors.line,
                  ),
                ),
                onPressed: state.focusing
                    ? null
                    : () => showResult(
                        context,
                        ref.read(appProvider.notifier).toggleRest(date),
                      ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      shortDate(date),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Icon(selected ? Icons.spa_outlined : Icons.add, size: 21),
                    const SizedBox(height: 5),
                    Text(
                      selected ? '已安排休息' : '设为休息日',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        const Text(
          '点击未来日期即可安排或取消。演示阶段暂未限制休息日数量，后续可调整。',
          style: TextStyle(fontSize: 12, color: NestColors.muted),
        ),
      ],
    );
  }
}
