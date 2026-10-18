import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});
  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends ConsumerState<AgentPage> {
  final input = TextEditingController();
  bool busy = false;
  String error = '';

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = input.text;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      error = '';
    });
    final result = await ref.read(appProvider.notifier).askPlanner(text);
    if (mounted) {
      setState(() {
        busy = false;
        if (result.ok) {
          input.clear();
        } else {
          error = result.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final w = s.workspace;
    final activity = ref.watch(agentActivityProvider);
    return PageFrame(
      subtitle: w.demoAgent ? '演示模式 · 固定示例，没有调用 DeepSeek' : '说目标，AI 拆成可执行的安排。',
      action: TextButton(
        onPressed: () => context.go('/settings'),
        child: const Text('模型设置'),
      ),
      children: [
        if (w.chat.isEmpty) ...[
          _IntroGroup(
            onPick: (text) {
              input.text = text;
              input.selection = TextSelection.collapsed(offset: text.length);
              setState(() {});
            },
          ),
          const SizedBox(height: 14),
        ],
        for (final m in w.chat) _Bubble(message: m),
        if (w.draft != null) ...[
          const SizedBox(height: 4),
          RoadmapPreview(draft: w.draft!),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy || s.focusing
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final result = await ref
                          .read(appProvider.notifier)
                          .importDraft();
                      if (context.mounted) {
                        setState(() => busy = false);
                        showResult(context, result);
                        if (result.ok) context.go('/plans?all=true');
                      }
                    },
              child: Text(busy ? '正在保存…' : '确认并保存到计划表'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NestColors.softDanger,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  error,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: NestColors.danger,
                  ),
                ),
              ),
            ),
          ),
        if (activity.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                activity,
                style: const TextStyle(fontSize: 13, color: NestColors.muted),
              ),
            ),
          ),
        _Composer(
          controller: input,
          enabled: !busy && !s.focusing,
          busy: busy,
          hasChat: w.chat.isNotEmpty,
          onSend: send,
          onReset: () async {
            final yes = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('开始一个新目标？'),
                content: const Text('当前对话和未保存草稿会清除，已保存计划保留。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('继续当前目标'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('新建目标'),
                  ),
                ],
              ),
            );
            if (yes == true && context.mounted) {
              showResult(
                context,
                ref.read(appProvider.notifier).resetConversation(),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        const Text(
          '按需追问，直到关键需求明确 · 已保存计划可直接用对话调整。',
          style: TextStyle(fontSize: 12, color: NestColors.faint),
        ),
      ],
    );
  }
}

class _IntroGroup extends StatelessWidget {
  const _IntroGroup({required this.onPick});
  final ValueChanged<String> onPick;

  static const suggestions = [
    '用两周学会采集公开网页，每天 30 分钟',
    '把本周未完成的任务挪到下周',
    '检查我明天的安排是否太多',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SurfacePanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '你想完成什么？',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: NestColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '说清目标和当前情况就够了。信息不足时，规划助手会继续追问，而不是直接给一份空泛的安排。',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: NestColors.muted,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      SettingsGroup(
        children: [
          for (final text in suggestions)
            SettingsRow(
              title: text,
              dense: true,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: NestColors.faint,
              ),
              onTap: () => onPick(text),
            ),
        ],
      ),
    ],
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final Map<String, String> message;
  @override
  Widget build(BuildContext context) {
    final mine = message['role'] == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            const _BubbleAvatar(label: 'AI', green: true),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? NestColors.softOrange : NestColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                message['content'] ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: NestColors.ink,
                ),
              ),
            ),
          ),
          if (mine) ...[
            const SizedBox(width: 8),
            const _BubbleAvatar(label: '我', green: false),
          ],
        ],
      ),
    );
  }
}

class _BubbleAvatar extends StatelessWidget {
  const _BubbleAvatar({required this.label, required this.green});
  final String label;
  final bool green;
  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: green ? NestColors.softOrange : NestColors.line,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: green ? NestColors.orangeDeep : NestColors.muted,
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.busy,
    required this.hasChat,
    required this.onSend,
    required this.onReset,
  });
  final TextEditingController controller;
  final bool enabled, busy, hasChat;
  final VoidCallback onSend;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('goal-input'),
          controller: controller,
          maxLength: 2000,
          minLines: 1,
          maxLines: 5,
          enabled: enabled,
          style: const TextStyle(fontSize: 15, height: 1.5),
          decoration: const InputDecoration(
            filled: true,
            fillColor: NestColors.fill,
            border: OutlineInputBorder(borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide.none),
            counterText: '',
            hintText: '想学什么、当前基础、期望成果…',
          ),
          onSubmitted: (_) => enabled ? onSend() : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (hasChat)
              TextButton(
                onPressed: enabled ? onReset : null,
                style: TextButton.styleFrom(
                  foregroundColor: NestColors.link,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('新建对话'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: enabled ? onSend : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(fontSize: 14),
              ),
              child: Text(busy ? '正在思考…' : '发送给规划助手'),
            ),
          ],
        ),
      ],
    ),
  );
}

class RoadmapPreview extends StatelessWidget {
  const RoadmapPreview({super.key, required this.draft});
  final Map<String, dynamic> draft;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const TagLabel('计划草稿'),
            const Spacer(),
            Text(
              '${(draft['tasks'] as List).length} 项任务',
              style: const TextStyle(fontSize: 12, color: NestColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          draft['title'] as String,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: NestColors.ink,
          ),
        ),
        for (final a in draft['assumptions'] as List)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '计划假设：$a',
              style: const TextStyle(fontSize: 13, color: NestColors.muted),
            ),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('每月目标', style: TextStyle(fontSize: 14)),
          initiallyExpanded: true,
          children: [
            for (final m in draft['months'] as List)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${m['month']}'),
                subtitle: Text('${m['objective']}'),
              ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('每周安排', style: TextStyle(fontSize: 14)),
          children: [
            for (final w in draft['weeks'] as List)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${w['start']} — ${w['end']}'),
                subtitle: Text('${w['objective']}'),
              ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            '每日任务 · ${(draft['tasks'] as List).length} 项',
            style: const TextStyle(fontSize: 14),
          ),
          children: [
            for (final t in draft['tasks'] as List)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${t['title']}'),
                subtitle: Text(
                  '${t['date']} ${t['time']} · ${t['minutes']} 分钟',
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
