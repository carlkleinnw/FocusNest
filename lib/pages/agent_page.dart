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
      title: 'AI 规划',
      subtitle: w.demoAgent
          ? '演示模式 · 固定示例，没有调用 DeepSeek'
          : '直接说目标、补充要求，或让 AI 查询和调整已有计划。只在必要时追问。',
      action: OutlinedButton.icon(
        onPressed: () => context.go('/settings'),
        icon: const Icon(Icons.tune_rounded, size: 16),
        label: const Text('模型设置'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          backgroundColor: NestColors.surface,
          side: BorderSide.none,
          textStyle: const TextStyle(fontSize: 12.5),
        ),
      ),
      children: [
        if (w.chat.isEmpty) ...[
          _IntroCard(
            onPick: (text) {
              input.text = text;
              input.selection = TextSelection.collapsed(offset: text.length);
              setState(() {});
            },
          ),
          const SizedBox(height: 18),
        ],
        for (final m in w.chat) _Bubble(message: m),
        if (w.draft != null) ...[
          const SizedBox(height: 6),
          RoadmapPreview(draft: w.draft!),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              icon: const Icon(Icons.playlist_add_check_rounded, size: 20),
              label: Text(busy ? '正在保存…' : '确认并保存到计划表'),
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
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: NestColors.softDanger,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: NestColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: NestColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (activity.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activity,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: NestColors.muted,
                      ),
                    ),
                  ),
                ],
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
        const SizedBox(height: 12),
        const Text(
          '按需追问，直到关键需求明确 · 已保存计划可直接用对话调整。',
          style: TextStyle(fontSize: 11.5, color: NestColors.faint),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.onPick});
  final ValueChanged<String> onPick;

  static const suggestions = [
    '用两周学会采集公开网页，每天 30 分钟',
    '把本周未完成的任务挪到下周',
    '检查我明天的安排是否太多',
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF6EF), Color(0xFFFFEFE2)],
      ),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1AFF6900),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 22,
            color: NestColors.orange,
          ),
        ),
        const SizedBox(height: 16),
        Text('你想完成什么？', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text(
          '说清目标和当前情况就够了。信息不足时，规划助手会继续追问，而不是直接给一份空泛的安排。',
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: NestColors.inkSoft,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final text in suggestions)
              InkWell(
                borderRadius: BorderRadius.circular(NestRadius.pill),
                onTap: () => onPick(text),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(NestRadius.pill),
                    border: Border.all(color: const Color(0x1AFF6900)),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: NestColors.inkSoft,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final Map<String, String> message;
  @override
  Widget build(BuildContext context) {
    final mine = message['role'] == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!mine) ...[
            const IconBadge(
              Icons.auto_awesome_rounded,
              size: 30,
              radius: 10,
              iconSize: 15,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  mine ? '你' : '规划助手',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: NestColors.faint,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxWidth: 640),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? NestColors.softOrange : NestColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 6),
                      bottomRight: Radius.circular(mine ? 6 : 18),
                    ),
                  ),
                  child: SelectableText(
                    message['content'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: NestColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (mine) const SizedBox(width: 40),
        ],
      ),
    );
  }
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
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
    shadow: false,
    border: Border.all(color: NestColors.lineStrong),
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
          style: const TextStyle(fontSize: 14, height: 1.6),
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            counterText: '',
            hintText: hasChat ? '补充条件、查看安排，或直接要求增删改计划' : '想学什么、当前基础、期望成果…',
          ),
          onSubmitted: (_) => enabled ? onSend() : null,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (hasChat)
              TextButton(
                onPressed: enabled ? onReset : null,
                style: TextButton.styleFrom(
                  foregroundColor: NestColors.muted,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('新建对话'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: enabled ? onSend : null,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded, size: 18),
              label: Text(busy ? '正在思考…' : '发送给规划助手'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const TagLabel(
              '计划草稿',
              color: NestColors.orangeDeep,
              background: NestColors.softOrange,
              icon: Icons.edit_note_rounded,
            ),
            const Spacer(),
            Text(
              '${(draft['tasks'] as List).length} 项任务',
              style: const TextStyle(fontSize: 11.5, color: NestColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          draft['title'] as String,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final a in draft['assumptions'] as List)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '计划假设：$a',
              style: const TextStyle(fontSize: 12, color: NestColors.muted),
            ),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('每月目标'),
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
          title: const Text('每周安排'),
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
          title: Text('每日任务 · ${(draft['tasks'] as List).length} 项'),
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
