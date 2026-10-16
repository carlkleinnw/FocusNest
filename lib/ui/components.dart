import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/ports.dart';
import 'theme.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.eyebrow = 'FOCUS NEST',
    this.action,
  });
  final String title, subtitle, eyebrow;
  final List<Widget> children;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 40),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1060),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                ?action,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: NestColors.muted),
            ),
            const SizedBox(height: 28),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? NestColors.surface,
      border: Border.all(color: NestColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.warning = false, this.icon});
  final String text;
  final bool warning;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: warning ? NestColors.sand : NestColors.softGreen,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 14,
            color: warning ? NestColors.orange : NestColors.green,
          ),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: warning ? NestColors.orange : NestColors.green,
          ),
        ),
      ],
    ),
  );
}

class MainButton extends StatelessWidget {
  const MainButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 19),
    label: Text(label),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.icon = Icons.spa_outlined,
  });
  final String title, body;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    child: Column(
      children: [
        Icon(icon, size: 48, color: NestColors.green),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

class StatBlock extends StatelessWidget {
  const StatBlock(this.label, this.value, {super.key, this.unit = ''});
  final String label, value, unit;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.headlineMedium,
          children: [
            TextSpan(text: value),
            TextSpan(
              text: ' $unit',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
}

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.onStart,
    this.onEdit,
    this.onDelete,
  });
  final Plan plan;
  final VoidCallback? onStart, onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: SurfacePanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(plan.category),
              const Spacer(),
              Text(
                plan.time,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: NestColors.muted,
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: '编辑计划',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: '删除计划',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 19),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(plan.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.schedule, size: 17, color: NestColors.muted),
              const SizedBox(width: 7),
              Text(
                '${plan.minutes} 分钟',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('选择任务'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void showResult(BuildContext context, OperationResult result) =>
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));

// Wait until the closing route has removed its overlay before disposing fields.
Future<T?> showEditorDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<T>(context: context, builder: builder);
  final result = await Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(route);
  await route.completed;
  return result;
}
