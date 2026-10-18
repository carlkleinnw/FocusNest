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

  bool get _failed =>
      status.contains('失败') || status.contains('无法') || status.contains('不支持');

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final locked = busy || s.focusing || !loaded;
    return PageFrame(
      title: '设置',
      subtitle: '配置你的学习助手和专注保护。所有数据保存在本机。',
      children: [
        _ProfileCard(configured: configured),
        const SizedBox(height: 24),
        const SectionTitle('AI 助手'),
        SurfacePanel(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconBadge(
                    Icons.key_rounded,
                    size: 36,
                    radius: 11,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DeepSeek 密钥',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: NestColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          configured ? '已保存 · 可随时替换' : '未配置',
                          style: const TextStyle(
                            fontSize: 12,
                            color: NestColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    configured ? '已保存' : '未配置',
                    icon: configured
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    background: configured
                        ? NestColors.softGreen
                        : NestColors.paperDeep,
                    foreground: configured
                        ? NestColors.green
                        : NestColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                kIsWeb
                    ? '密钥只保存在本机服务内存中，不写入浏览器存储或文件，关闭服务后清除。保存不会调用 DeepSeek；测试连接或发送目标时才会联网并产生 API 费用。'
                    : '密钥仅在本机加密保存。调用 AI 时会把你输入的目标、对话或待复盘记录发给 DeepSeek，并产生 API 费用。应用名单不发送。',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: NestColors.muted,
                ),
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
                    icon: Icon(
                      reveal
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '模型',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: NestColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: ValueKey(model),
                initialValue: model,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded),
                decoration: const InputDecoration(
                  hintText: '选择模型',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
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
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                    style: TextButton.styleFrom(
                      foregroundColor: NestColors.muted,
                    ),
                    child: const Text('移除密钥'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _failed ? NestColors.softDanger : NestColors.paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      Icon(
                        _failed
                            ? Icons.error_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 15,
                        color: _failed ? NestColors.danger : NestColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: _failed
                                ? NestColors.danger
                                : NestColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('计划与复盘'),
        SurfacePanel(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: capacity,
                enabled: !s.focusing,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                decoration: const InputDecoration(
                  labelText: '每日可用时间',
                  suffixText: '分钟',
                  helperText: '30—720 分钟，AI 安排每日任务时会参考这个上限。',
                ),
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
              const Divider(height: 1),
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
              const Divider(height: 1),
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
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('专注保护'),
        SurfacePanel(
          padding: EdgeInsets.zero,
          child: SettingsRow(
            icon: Icons.shield_outlined,
            iconColor: NestColors.green,
            iconBackground: NestColors.softGreen,
            title: '专注保护与白名单',
            subtitle: '管理系统权限和专注期间允许使用的应用',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: NestColors.faint,
            ),
            onTap: () => context.go('/apps'),
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('关于'),
        SurfacePanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.storage_rounded,
                iconColor: NestColors.blue,
                iconBackground: NestColors.softBlue,
                title: '本地数据',
                subtitle: '计划与专注记录保存在手机私有数据库，密钥使用系统密钥库加密。',
              ),
              const Divider(height: 1, indent: 68, endIndent: 16),
              const SettingsRow(
                icon: Icons.history_rounded,
                title: '版本记录',
                subtitle: '0.4.4 · 体验版 · 界面重塑',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '复盘压缩后移除对应明细，只保留统计和选出的关键任务，无法恢复全部逐项内容。',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.6,
            color: NestColors.faint,
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.configured});
  final bool configured;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
    child: Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF8A3D), NestColors.orange],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: NestShadow.accentGlow,
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            size: 30,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '伴学小屋',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: NestColors.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const TagLabel(
                    '体验版',
                    color: NestColors.orangeDeep,
                    background: NestColors.softOrange,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'FocusNest · 计划、专注与复盘',
                style: TextStyle(fontSize: 12, color: NestColors.muted),
              ),
            ],
          ),
        ),
        IconBadge(
          configured ? Icons.link_rounded : Icons.link_off_rounded,
          color: configured ? NestColors.green : NestColors.muted,
          background: configured ? NestColors.softGreen : NestColors.paper,
          size: 36,
          iconSize: 18,
        ),
      ],
    ),
  );
}
