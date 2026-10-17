import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/planner_agent.dart';

class AndroidPlannerGateway implements PlannerGateway, SavedKeyReader {
  static const channel = MethodChannel('focusnest/agent_v1');
  @override
  Future<String> readSavedKey() async =>
      await channel.invokeMethod<String>('revealKey') ?? '';
  @override
  Future<Map<String, dynamic>> settings() async => Map<String, dynamic>.from(
    await channel.invokeMapMethod<String, dynamic>('settings') ?? {},
  );
  @override
  Future<void> configure({
    required String key,
    required String model,
    required bool remove,
  }) => channel.invokeMethod<void>('configure', {
    'key': key,
    'model': model,
    'remove': remove,
  });
  @override
  Future<Map<String, dynamic>> request(
    List<Map<String, String>> messages,
  ) async {
    try {
      final result = await channel.invokeMethod<String>('request', {
        'messages': messages,
      });
      if (result == null) throw const AgentFailure('AI 没有返回内容，请重试。');
      return jsonDecode(result) as Map<String, dynamic>;
    } on PlatformException catch (e) {
      throw AgentFailure(e.message ?? 'AI 请求失败，请检查设置后重试。');
    } on FormatException {
      throw const AgentFailure('AI 返回内容格式错误，原数据未修改。');
    }
  }
}

/// Explicitly selected, labelled demonstration. Never used as network fallback.
class DemoPlannerGateway implements PlannerGateway {
  DemoPlannerGateway(this.today);
  final String today;
  @override
  Future<Map<String, dynamic>> settings() async => {
    'configured': false,
    'model': 'deepseek-flash',
  };
  @override
  Future<void> configure({
    required String key,
    required String model,
    required bool remove,
  }) async {
    throw const AgentFailure('网页演示不保存密钥，请在 Android 设置中填写。');
  }

  @override
  Future<Map<String, dynamic>> request(
    List<Map<String, String>> messages,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (messages.first['content']!.contains('SUMMARY_SELECTION')) {
      final input = jsonDecode(messages.last['content']!) as Map;
      return {
        'highlights': (input['facts'] as List)
            .take(4)
            .map((f) => (f as Map)['id'])
            .toList(),
        'advice': '根据实际完成情况安排下一阶段，保留复习时间。',
      };
    }
    var turns = messages.where((m) => m['role'] == 'user').length;
    try {
      final envelope = jsonDecode(messages.last['content']!);
      if (envelope is Map && envelope['conversation'] is List) {
        turns = (envelope['conversation'] as List)
            .where((m) => m['role'] == 'user')
            .length;
      }
    } on FormatException {
      /* Older callers pass ordinary chat messages. */
    }
    if (turns == 1) {
      return {'kind': 'question', 'question': '你目前的基础、期望完成期限，以及每天能安排多少分钟？'};
    }
    final start = DateTime.parse(today).add(const Duration(days: 1));
    final topics = [
      '认识 HTTP 请求与响应',
      '用 Python 获取公开示例页面',
      '解析 HTML 并提取标题',
      '处理分页与重复数据',
      '把结果保存为 CSV',
      '加入超时和错误处理',
      '完成采集脚本并写使用说明',
    ];
    final tasks = [
      for (var i = 0; i < topics.length; i++)
        {
          'date': _key(start.add(Duration(days: i))),
          'title': topics[i],
          'minutes': 30,
          'time': '19:00',
        },
    ];
    return {
      'kind': 'plan',
      'title': 'Python 数据采集入门（演示样例）',
      'assumptions': [
        '这是固定演示计划，没有调用 DeepSeek。',
        '假设已有 Python 基础，每天30分钟，只练习公开授权示例页面。',
      ],
      'months': tasks
          .map((t) => (t['date'] as String).substring(0, 7))
          .toSet()
          .map((m) => {'month': m, 'objective': '完成一个可重复运行的数据采集练习'})
          .toList(),
      'weeks': [
        {
          'start': tasks.first['date'],
          'end': tasks.last['date'],
          'objective': '从请求到保存，完成一个小型采集项目',
        },
      ],
      'tasks': tasks,
    };
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
