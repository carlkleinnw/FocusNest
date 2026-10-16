import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../core/planner_agent.dart';

PlannerGateway createWebPlannerGateway() => WebPlannerGateway();

class WebPlannerGateway implements PlannerGateway {
  Future<Map<String, dynamic>> _call(
    String path, [
    Map<String, Object?>? body,
  ]) async {
    try {
      final response = await web.window
          .fetch(
            Uri.base.resolve(path).toString().toJS,
            web.RequestInit(
              method: body == null ? 'GET' : 'POST',
              headers: {'Content-Type': 'application/json'}.jsify() as JSObject,
              body: body == null ? null : jsonEncode(body).toJS,
            ),
          )
          .toDart
          .timeout(const Duration(seconds: 130));
      final data =
          jsonDecode((await response.text().toDart).toDart)
              as Map<String, dynamic>;
      if (!response.ok) {
        throw AgentFailure(data['error'] as String? ?? '本地服务请求失败，请重试。');
      }
      return data;
    } on AgentFailure {
      rethrow;
    } catch (_) {
      throw const AgentFailure('无法连接本地 AI 服务，请使用新版启动器打开网页。');
    }
  }

  @override
  Future<Map<String, dynamic>> settings() => _call('/api/agent/settings');
  @override
  Future<void> configure({
    required String key,
    required String model,
    required bool remove,
  }) async {
    await _call('/api/agent/configure', {
      'key': key,
      'model': model,
      'remove': remove,
    });
  }

  @override
  Future<Map<String, dynamic>> request(List<Map<String, String>> messages) =>
      _call('/api/agent/request', {'messages': messages});
}
