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
      title: '把目标变成每天的一步',
      subtitle: w.demoAgent
          ? '演示模式 · 固定示例，没有调用 DeepSeek'
          : '直接说目标、补充要求，或让 AI 查询和调整已有计划。只在必要时追问。',
      action: IconButton(
        tooltip: 'AI 设置',
        onPressed: () => context.go('/settings'),
        icon: const Icon(Icons.settings_outlined),
      ),
      children: [
        if (w.chat.isEmpty) ...[
          const SizedBox(height: 12),
          const Icon(Icons.route_outlined, size: 44, color: NestColors.green),
          const SizedBox(height: 16),
          Text('你想完成什么？', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('例如：我会 Python 基础，用两周学会采集公开网页，每天30分钟。也可以说：把本周未完成的任务挪到下周。'),
          const SizedBox(height: 24),
        ],
        for (final m in w.chat)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Align(
              alignment: m['role'] == 'user'
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: m['role'] == 'user'
                      ? NestColors.softGreen
                      : NestColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['role'] == 'user' ? '你' : '规划助手',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: NestColors.green,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(m['content']!),
                  ],
                ),
              ),
            ),
          ),
        if (w.draft != null) ...[
          RoadmapPreview(draft: w.draft!),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.playlist_add_check),
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
          const SizedBox(height: 24),
        ],
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: const TextStyle(color: NestColors.orange),
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
                style: const TextStyle(color: NestColors.green),
              ),
            ),
          ),
        TextField(
          key: const Key('goal-input'),
          controller: input,
          maxLength: 2000,
          minLines: 2,
          maxLines: 5,
          enabled: !busy && !s.focusing,
          decoration: InputDecoration(
            labelText: w.chat.isEmpty ? '目标或计划操作' : '继续对话或调整计划',
            hintText: w.chat.isEmpty
                ? '想学什么、当前基础、期望成果…'
                : '补充条件、查看安排，或直接要求增删改计划',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward),
              label: Text(busy ? '正在思考…' : '发送给规划助手'),
              onPressed: busy || s.focusing ? null : send,
            ),
            TextButton(
              onPressed: busy || s.focusing || w.chat.isEmpty
                  ? null
                  : () async {
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
              child: const Text('新建对话'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '按需追问，连续最多3轮 · 已保存计划可直接用对话调整。',
          style: const TextStyle(color: NestColors.muted),
        ),
      ],
    );
  }
}

class RoadmapPreview extends StatelessWidget {
  const RoadmapPreview({super.key, required this.draft});
  final Map<String, dynamic> draft;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 32),
      Text(
        draft['title'] as String,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final a in draft['assumptions'] as List)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '计划假设：$a',
            style: const TextStyle(color: NestColors.muted),
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
              subtitle: Text('${t['date']} ${t['time']} · ${t['minutes']} 分钟'),
            ),
        ],
      ),
    ],
  );
}
