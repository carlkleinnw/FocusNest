import 'dart:convert';
import 'dart:io';
import 'package:focus_pet_demo/core/planner_agent.dart';

class TrackedPlannerGateway implements PlannerGateway, SavedKeyReader {
  TrackedPlannerGateway(this.delegate);
  final PlannerGateway delegate;
  int completedRequests = 0;
  @override
  Future<Map<String, dynamic>> request(
    List<Map<String, String>> messages,
  ) async {
    try {
      return await delegate.request(messages);
    } finally {
      completedRequests++;
    }
  }

  @override
  Future<Map<String, dynamic>> settings() => delegate.settings();
  @override
  Future<void> configure({
    required String key,
    required String model,
    required bool remove,
  }) => delegate.configure(key: key, model: model, remove: remove);
  @override
  Future<String> readSavedKey() => (delegate as SavedKeyReader).readSavedKey();
}

/// Opt-in emulator adapter. adb reverse connects to the user's local service;
/// credentials stay in that process, never in test arguments or source files.
class HostPlannerGateway implements PlannerGateway, SavedKeyReader {
  final _client = HttpClient();
  int completedRequests = 0;
  Future<Map<String, dynamic>> _call(String path, [Object? body]) async {
    const port = int.fromEnvironment('HOST_AGENT_PORT', defaultValue: 8788);
    final uri = Uri.parse('http://127.0.0.1:$port/api/agent/$path');
    final request = await _client.openUrl(body == null ? 'GET' : 'POST', uri);
    request.headers.contentType = ContentType.json;
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close().timeout(
      const Duration(seconds: 135),
    );
    final result =
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AgentFailure(result['error'] as String? ?? 'Local gateway failed');
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> settings() => _call('settings');
  @override
  Future<String> readSavedKey() async =>
      (await _call('reveal', {}))['key'] as String? ?? '';
  @override
  Future<Map<String, dynamic>> request(
    List<Map<String, String>> messages,
  ) async {
    try {
      return await _call('request', {'messages': messages});
    } finally {
      completedRequests++;
    }
  }

  @override
  Future<void> configure({
    required String key,
    required String model,
    required bool remove,
  }) => throw UnsupportedError('Configure in the settings UI');
  void close() => _client.close(force: true);
}
