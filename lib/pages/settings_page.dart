import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/planner_agent.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final keyInput = TextEditingController();
  final capacity = TextEditingController();
  String model = 'deepseek-flash', status = '正在读取配置…';
  bool configured = false, busy = false, reveal = false, loaded = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(plannerGatewayProvider).settings();
      if (mounted) {
        setState(() {
          model = s['model'] as String? ?? 'deepseek-flash';
          configured = s['configured'] == true;
          loaded = true;
          status = configured
              ? (kIsWeb ? '密钥已保存在本地服务内存中，尚未测试连接。' : '密钥已保存，连接尚未测试。')
              : '尚未填写密钥';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loaded = true;
          status = '无法读取配置，请用新版启动器打开网页后重试。';
        });
      }
    }
    if (mounted) capacity.text = ref.read(appProvider).dailyCapacity.toString();
  }

  @override
  void dispose() {
    keyInput.dispose();
    capacity.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    final firstKey = !configured && !remove && keyInput.text.trim().isNotEmpty;
    setState(() => busy = true);
    try {
      await ref
          .read(plannerGatewayProvider)
          .configure(key: keyInput.text, model: model, remove: remove);
      keyInput.clear();
      reveal = false;
      await _load();
      if (firstKey && mounted) {
        ref
            .read(appProvider.notifier)
            .setWorkspaceOptions(
              autoReview: !kIsWeb,
              demoAgent: kIsWeb ? false : null,
            );
      }
      if (mounted) {
        setState(
          () => status = remove
              ? '密钥已移除'
              : kIsWeb
              ? '密钥已保存在本地服务内存中，尚未测试连接。'
              : '配置已保存，连接尚未测试。',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => status = e is AgentFailure
              ? '保存失败：${e.message}'
              : '保存失败，请检查配置后重试。',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      busy = true;
      status = '正在连接 DeepSeek…';
    });
    try {
      final r = await ref.read(plannerGatewayProvider).request([
        {'role': 'system', 'content': '只输出 JSON：{"ok":true}，用于连接测试。'},
        {'role': 'user', 'content': '测试连接'},
      ]);
      if (mounted) {
        setState(
          () => status = r['ok'] == true
              ? 'DeepSeek 连接成功（本次实测）'
              : '服务已响应，返回格式不符，请检查模型。',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => status = e is AgentFailure ? e.message : '连接失败，请检查密钥和网络。',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggleKey() async {
    if (!reveal && configured && keyInput.text.isEmpty) {
      setState(() => busy = true);
      try {
        final gateway = ref.read(plannerGatewayProvider);
        if (gateway is! SavedKeyReader) {
          throw const AgentFailure('当前配置服务不支持查看已保存密钥，请更新后重试。');
        }
        final key = await (gateway as SavedKeyReader).readSavedKey();
        if (!mounted) return;
        if (key.isEmpty) throw const AgentFailure('密钥已清除，请重新填写。');
        keyInput.text = key;
      } catch (e) {
        if (mounted) {
          setState(() => status = e is AgentFailure ? e.message : '读取失败，请重试。');
        }
        return;
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
    if (mounted) setState(() => reveal = !reveal);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final locked = busy || s.focusing || !loaded;
    return PageFrame(
      title: '设置',
      subtitle: '配置你的学习助手和专注保护。',
      children: [
        Text('DeepSeek', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          kIsWeb
              ? '密钥只保存在本机服务内存中，不写入浏览器存储或文件，关闭服务后清除。保存不会调用 DeepSeek；测试连接或发送目标时才会联网并产生 API 费用。'
              : '密钥仅在本机加密保存。调用 AI 时会把你输入的目标、对话或待复盘记录发给 DeepSeek，并产生 API 费用。应用名单不发送。',
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('api-key'),
          controller: keyInput,
          obscureText: !reveal,
          enableSuggestions: false,
          autocorrect: false,
          enabled: !locked,
          decoration: InputDecoration(
            labelText: configured ? 'API 密钥（留空保留原值）' : 'API 密钥',
            hintText: configured ? '••••••••••••••••' : null,
            helperText: configured ? '密钥已保存，点击眼睛查看；留空保存保留原值。' : null,
            suffixIcon: IconButton(
              tooltip: reveal ? '隐藏密钥' : '显示密钥',
              onPressed: locked ? null : _toggleKey,
              icon: Icon(reveal ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(model),
          initialValue: model,
          decoration: const InputDecoration(labelText: '模型'),
          items: const [
            DropdownMenuItem(
              value: 'deepseek-flash',
              child: Text('DeepSeek Flash'),
            ),
            DropdownMenuItem(
              value: 'deepseek-v4-pro',
              child: Text('DeepSeek V4 Pro'),
            ),
            DropdownMenuItem(
              value: 'deepseek-chat',
              child: Text('DeepSeek Chat（兼容名称）'),
            ),
          ],
          onChanged: locked ? null : (v) => setState(() => model = v!),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: locked ? null : () => _save(),
              child: const Text('保存 API 配置'),
            ),
            OutlinedButton(
              onPressed: locked || !configured ? null : _test,
              child: const Text('测试连接'),
            ),
            TextButton(
              onPressed: locked || !configured
                  ? null
                  : () => _save(remove: true),
              child: const Text('移除密钥'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(status, style: const TextStyle(color: NestColors.green)),
        ),
        const Divider(height: 48),
        Text('计划与复盘', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: capacity,
          enabled: !s.focusing,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '每日可用时间（30—720 分钟）'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: s.focusing
                ? null
                : () => showResult(
                    context,
                    ref
                        .read(appProvider.notifier)
                        .setCapacity(int.tryParse(capacity.text) ?? 0),
                  ),
            child: const Text('保存每日时间'),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('自动复盘与压缩'),
          subtitle: const Text(
            '开启后，使用应用时自动处理已结束的周、月、季、年。关闭应用期间的积压会在下次打开补做；联网失败保留明细。',
          ),
          value: s.workspace.autoReview,
          onChanged: s.focusing
              ? null
              : (v) => showResult(
                  context,
                  ref
                      .read(appProvider.notifier)
                      .setWorkspaceOptions(autoReview: v),
                ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('AI 演示模式'),
          subtitle: const Text(
            '使用固定的 Python 采集计划与模拟复盘，不联网、不计费。关闭后才调用你的 DeepSeek。',
          ),
          value: s.workspace.demoAgent,
          onChanged: s.focusing
              ? null
              : (v) => showResult(
                  context,
                  ref
                      .read(appProvider.notifier)
                      .setWorkspaceOptions(demoAgent: v),
                ),
        ),
        const Divider(height: 40),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.shield_outlined),
          title: const Text('专注保护与白名单'),
          subtitle: const Text('管理系统权限和专注期间允许使用的应用'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/apps'),
        ),
        const SizedBox(height: 24),
        const Text(
          '伴学小屋 0.3.2 · 总结后移除对应明细，只保留统计和选出的关键任务，无法恢复全部逐项内容。',
          style: TextStyle(color: NestColors.muted),
        ),
      ],
    );
  }
}
