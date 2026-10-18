import 'package:flutter/material.dart';
import '../core/ports.dart';
import 'theme.dart';

/// Page body: grey canvas, one quiet title line, then white list groups.
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
        compact ? 16 : 24,
        compact ? 10 : 16,
        compact ? 16 : 24,
        108,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(width: 12), action!],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: NestColors.muted,
                ),
              ),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A white WeChat-style list group. No border, no shadow.
class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.gradient,
    this.radius = NestRadius.card,
    this.border,
    this.shadow = false,
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
    final fg =
        foreground ?? (warning ? NestColors.amber : NestColors.greenDeep);
    final bg = background ?? NestColors.tagBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(fontSize: 11, height: 1.4, color: fg)),
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

/// Grey section heading above a group, like WeChat settings sections.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.subtitle});
  final String text;
  final Widget? action;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: NestColors.muted,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
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

/// One white group of rows with hairline separators inset from the left.
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
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 0),
        );
      }
      rows.add(children[i]);
    }
    return SurfacePanel(
      padding: padding ?? EdgeInsets.zero,
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
    this.iconColor = NestColors.muted,
    this.leading,
    this.dense = false,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;
  final Widget? trailing, leading;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 11 : 14),
      child: Row(
        children: [
          leading ??
              (icon == null
                  ? const SizedBox(width: 0)
                  : Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(icon, size: 22, color: iconColor),
                    )),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: NestColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: NestColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.icon,
    this.color = NestColors.ink,
  });
  final String label, value, unit;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: NestColors.muted),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: color,
            ),
            children: [
              TextSpan(text: value),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
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
    this.icon = Icons.inbox_outlined,
  });
  final String title, body;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
    child: Column(
      children: [
        Icon(icon, size: 36, color: NestColors.faint),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: NestColors.ink,
          ),
        ),
        const SizedBox(height: 6),
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
        if (action != null) ...[const SizedBox(height: 16), action!],
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
        style: const TextStyle(fontSize: 13, color: NestColors.muted),
      ),
      const SizedBox(height: 4),
      RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: NestColors.ink,
          ),
          children: [
            TextSpan(text: value),
            TextSpan(
              text: ' $unit',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: NestColors.muted,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Flat text tabs with a short orange underline, used for level/filter switching.
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
    final glyph = MediaQuery.textScalerOf(context).scale(15);
    final tabs = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      final selected = i == index;
      final width = glyph * labels[i].runes.length + 16;
      tabs.add(
        InkWell(
          onTap: () => onChanged(i),
          child: Container(
            width: width,
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? NestColors.orange : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: ChoiceChip(
              key: keys?[i],
              label: SizedBox(
                width: width - 16,
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
              selectedColor: Colors.transparent,
              side: BorderSide.none,
              shape: const RoundedRectangleBorder(),
              labelStyle: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? NestColors.ink : NestColors.muted,
              ),
              padding: const EdgeInsets.only(bottom: 11),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              pressElevation: 0,
              elevation: 0,
            ),
          ),
        ),
      );
    }
    return SurfacePanel(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: scrollable
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: tabs),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: tabs),
      ),
    );
  }
}

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
        const SizedBox(width: 4),
      ],
      Flexible(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: color ?? NestColors.muted,
          ),
        ),
      ),
    ],
  );
}

/// Small grey label, WeChat tag style.
class TagLabel extends StatelessWidget {
  const TagLabel(
    this.text, {
    super.key,
    this.color = NestColors.muted,
    this.background = NestColors.tagBg,
    this.icon,
  });
  final String text;
  final Color color, background;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, height: 1.4, color: color),
          ),
        ),
      ],
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
