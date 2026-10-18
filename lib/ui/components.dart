import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/ports.dart';
import 'theme.dart';

/// Scroll body shared by every page: an optional eyebrow, a large title,
/// a supporting line, then the page content on a max-width column.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.eyebrow = '',
    this.action,
  });
  final String title, subtitle, eyebrow;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 36,
        compact ? 8 : 16,
        compact ? 20 : 36,
        132,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 3,
                      decoration: BoxDecoration(
                        color: NestColors.orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      eyebrow,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: NestColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (context, box) {
                  final titleText = Text(
                    title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  );
                  if (action == null || box.maxWidth < 560) {
                    return titleText;
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: titleText),
                      const SizedBox(width: 16),
                      action!,
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: NestColors.muted),
                ),
              ),
              if (action != null && compact) ...[
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: action!),
              ],
              SizedBox(height: compact ? 22 : 28),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// White card. [color] or [gradient] replaces the plain surface, [onTap] adds
/// an ink response. Hairline border is opt-in so cards can sit quietly on the
/// grey canvas.
class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.gradient,
    this.radius = NestRadius.card,
    this.border,
    this.shadow = true,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final Border? border;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color ?? NestColors.surface : null,
        gradient: gradient,
        border: border,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow && (color == null || color == NestColors.surface)
            ? NestShadow.card
            : null,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    super.key,
    this.warning = false,
    this.icon,
    this.background,
    this.foreground,
  });
  final String text;
  final bool warning;
  final IconData? icon;
  final Color? background, foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? (warning ? NestColors.amber : NestColors.green);
    final bg = background ?? (warning ? NestColors.sand : NestColors.softGreen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(NestRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
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
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

/// Small uppercase section label used above grouped content.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.subtitle});
  final String text;
  final Widget? action;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: NestColors.muted,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: NestColors.faint),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// Rounded-square icon tile, the recurring Xiaomi list/settings ornament.
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.color = NestColors.orange,
    this.background = NestColors.softOrange,
    this.size = 40,
    this.radius = 12,
    this.iconSize,
  });
  final IconData icon;
  final Color color, background;
  final double size, radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(icon, size: iconSize ?? size * 0.5, color: color),
  );
}

/// Grouped settings list: one white card, hairline dividers between rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          const Divider(height: 1, thickness: 1, indent: 68, endIndent: 16),
        );
      }
      rows.add(children[i]);
    }
    return SurfacePanel(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: rows),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = NestColors.orange,
    this.iconBackground = NestColors.softOrange,
    this.leading,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor, iconBackground;
  final Widget? trailing, leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          leading ??
              (icon == null
                  ? const SizedBox(width: 4)
                  : IconBadge(
                      icon!,
                      color: iconColor,
                      background: iconBackground,
                      size: 38,
                    )),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NestColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: NestColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: row,
    );
  }
}

/// Big number + label + tinted icon, used in dashboard grids.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.icon,
    this.color = NestColors.orange,
    this.background = NestColors.softOrange,
  });
  final String label, value, unit;
  final IconData? icon;
  final Color color, background;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              IconBadge(
                icon!,
                color: color,
                background: background,
                size: 30,
                radius: 9,
                iconSize: 16,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: NestColors.muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 26,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: NestColors.ink,
            ),
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NestColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
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
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    child: Column(
      children: [
        IconBadge(
          icon,
          size: 60,
          radius: 20,
          color: NestColors.orange,
          background: NestColors.softOrange,
        ),
        const SizedBox(height: 18),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: NestColors.muted,
            ),
          ),
        ),
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
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: NestColors.muted,
        ),
      ),
      const SizedBox(height: 6),
      RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.displaySmall,
          children: [
            TextSpan(text: value),
            TextSpan(
              text: ' $unit',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: NestColors.muted,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Segmented pill control. Keeps [ChoiceChip] as the underlying widget so
/// existing keys/tests keep working while the visual becomes a Xiaomi track.
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.keys,
    this.scrollable = true,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<Key>? keys;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    // Reserve the label width explicitly: on Flutter web the fallback CJK face
    // can measure narrower than it paints, and Material's chip label fades
    // with overflow. An explicit box keeps every segment legible.
    final glyph = MediaQuery.textScalerOf(context).scale(13);
    for (var i = 0; i < labels.length; i++) {
      final selected = i == index;
      final width = glyph * labels[i].runes.length + 6;
      chips.add(
        Padding(
          padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 4),
          child: ChoiceChip(
            key: keys?[i],
            label: SizedBox(
              width: width,
              child: Text(
                labels[i],
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
              ),
            ),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onChanged(i),
            backgroundColor: Colors.transparent,
            selectedColor: NestColors.surface,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? NestColors.ink : NestColors.muted,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            elevation: selected ? 1 : 0,
            shadowColor: const Color(0x1A101828),
            pressElevation: 0,
          ),
        ),
      );
    }
    final track = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NestColors.paperDeep,
        borderRadius: BorderRadius.circular(NestRadius.pill),
      ),
      child: scrollable
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            )
          : Row(mainAxisSize: MainAxisSize.min, children: chips),
    );
    return Align(alignment: Alignment.centerLeft, child: track);
  }
}

/// Circular progress. Pass [gradient] for the hero rings, or [color] for a
/// flat arc.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 7,
    this.color = NestColors.orange,
    this.trackColor = NestColors.paperDeep,
    this.gradient,
    this.child,
  });
  final double value, size, stroke;
  final Color color, trackColor;
  final Gradient? gradient;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _RingPainter(
        value: value.clamp(0, 1).toDouble(),
        stroke: stroke,
        color: color,
        trackColor: trackColor,
        gradient: gradient,
      ),
      child: Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.trackColor,
    this.gradient,
  });
  final double value, stroke;
  final Color color, trackColor;
  final Gradient? gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(arcRect, 0, 6.2832, false, track);
    if (value <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (gradient != null) {
      paint.shader = gradient!.createShader(rect);
    } else {
      paint.color = color;
    }
    canvas.drawArc(arcRect, -1.5708, 6.2832 * value, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.stroke != stroke ||
      old.trackColor != trackColor;
}

/// Small meta line: icon + text.
class MetaText extends StatelessWidget {
  const MetaText(this.text, {super.key, this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 13, color: color ?? NestColors.faint),
        const SizedBox(width: 5),
      ],
      Flexible(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: color ?? NestColors.muted,
          ),
        ),
      ),
    ],
  );
}

/// Tiny label chip for goal names / categories.
class TagLabel extends StatelessWidget {
  const TagLabel(
    this.text, {
    super.key,
    this.color = NestColors.blue,
    this.background = NestColors.softBlue,
    this.icon,
  });
  final String text;
  final Color color, background;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
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
    padding: const EdgeInsets.only(bottom: 12),
    child: SurfacePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TagLabel(plan.category),
              const Spacer(),
              MetaText(plan.time, icon: Icons.schedule_rounded),
              if (onEdit != null)
                IconButton(
                  tooltip: '编辑计划',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: '删除计划',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(plan.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              MetaText('${plan.minutes} 分钟', icon: Icons.timelapse_rounded),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
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
