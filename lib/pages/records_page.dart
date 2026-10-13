import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class RecordsPage extends ConsumerWidget {
  const RecordsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(appProvider.select((s) => s.records));
    final completed = records.where((r) => r.completed);
    final minutes = completed.fold(0, (sum, r) => sum + r.minutes);
    return PageFrame(
      title: '努力都有迹可循',
      subtitle: '看见每一次坚持，也接纳偶尔的中断。这里包含预填及模拟记录。',
      eyebrow: 'YOUR LITTLE STEPS',
      children: [
        SurfacePanel(
          child: Wrap(
            spacing: 48,
            runSpacing: 20,
            children: [
              StatBlock('完整专注', '${completed.length}', unit: '次'),
              StatBlock('累计完成时长', '$minutes', unit: '分钟'),
              StatBlock(
                '提前结束',
                '${records.length - completed.length}',
                unit: '次',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...records.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SurfacePanel(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NestColors.softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      r.completed ? Icons.check : Icons.pause,
                      color: NestColors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${shortDate(r.at)} · ${r.minutes}分钟 · ${r.virtual ? '虚拟演示' : '本次计时'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    r.completed ? '已完成' : '提前结束',
                    warning: !r.completed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
