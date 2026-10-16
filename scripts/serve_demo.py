"""Loopback-only demo server. User credentials live only in process memory."""
import argparse
import json
import threading
import urllib.error
import urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class AgentError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def deepseek_request(key, model, messages):
    body = json.dumps({
        'model': model, 'messages': messages, 'stream': False,
        'thinking': {'type': 'disabled'},
        'response_format': {'type': 'json_object'},
        'max_tokens': 24000, 'temperature': 0.2,
    }).encode('utf-8')
    request = urllib.request.Request(
        'https://api.deepseek.com/chat/completions', data=body,
        headers={'Authorization': 'Bearer ' + key,
                 'Content-Type': 'application/json; charset=utf-8'}, method='POST')
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=120) as response:
            raw = response.read(2_000_001)
        if len(raw) > 2_000_000:
            raise AgentError('AI 返回过长，请缩短计划周期。')
        choice = json.loads(raw)['choices'][0]
        if choice.get('finish_reason') != 'stop':
            raise AgentError('AI 输出不完整，原数据未修改，请缩短计划后重试。')
        result = json.loads(choice['message']['content'])
        if not isinstance(result, dict):
            raise AgentError('AI 返回格式错误，原数据未修改。')
        return result
    except urllib.error.HTTPError as error:
        messages = {401: '密钥无效，请重新填写。', 402: 'DeepSeek 余额不足，请检查账户。',
                    429: '请求过于频繁，请稍后重试。', 400: '模型或请求不受支持，请检查模型。',
                    422: '模型或请求不受支持，请检查模型。'}
        raise AgentError(messages.get(error.code, 'DeepSeek 暂不可用，请稍后重试。')) from None
    except AgentError:
        raise
    except Exception:
        raise AgentError('连接失败或响应无效，请检查网络和模型后重试。') from None


class DemoServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, directory, complete=deepseek_request):
        self.directory = str(Path(directory).resolve())
        self.key = ''
        self.model = 'deepseek-flash'
        self.state_lock = threading.Lock()
        self.request_lock = threading.Lock()
        self.complete = complete
        super().__init__(address, DemoHandler)


class DemoHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=args[2].directory, **kwargs)

    def log_message(self, *_args):
        pass  # No URLs, bodies, keys, or upstream response bodies in logs.

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Content-Security-Policy', "frame-ancestors 'none'")
        super().end_headers()

    def _same_origin(self):
        port = self.server.server_port
        hosts = {f'127.0.0.1:{port}', f'localhost:{port}'}
        origin = self.headers.get('Origin')
        return (self.headers.get('Host') in hosts
                and (origin is None or origin in {'http://' + h for h in hosts})
                and self.headers.get('Sec-Fetch-Site') != 'cross-site')

    def _json(self, status, value):
        body = json.dumps(value, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if not self._same_origin():
            return self._json(403, {'error': '仅允许本机同源访问。'})
        path = urlsplit(self.path).path
        if path == '/api/agent/settings':
            with self.server.state_lock:
                result = {'configured': bool(self.server.key), 'model': self.server.model,
                          'storage': 'process-memory', 'bridgeVersion': 2}
            return self._json(200, result)
        if path.startswith('/api/'):
            return self._json(404, {'error': '接口不存在。'})
        super().do_GET()

    def do_POST(self):
        if not self._same_origin():
            return self._json(403, {'error': '仅允许本机同源访问。'})
        if self.headers.get_content_type() != 'application/json':
            return self._json(415, {'error': '请求应为 JSON。'})
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 2_000_000:
                raise ValueError()
            body = json.loads(self.rfile.read(size))
            if not isinstance(body, dict):
                raise ValueError()
        except (ValueError, UnicodeError):
            return self._json(400, {'error': '请求格式错误或过长。'})
        path = urlsplit(self.path).path
        if path == '/api/agent/reveal':
            with self.server.state_lock:
                key = self.server.key
            return self._json(200, {'key': key})
        if path == '/api/agent/configure':
            key, model, remove = body.get('key', ''), body.get('model'), body.get('remove', False)
            if (not isinstance(model, str)
                    or model not in {'deepseek-flash', 'deepseek-v4-pro', 'deepseek-chat'}
                    or not isinstance(remove, bool) or not isinstance(key, str)):
                return self._json(400, {'error': '配置无效，请检查模型或密钥。'})
            key = key.strip()
            if key and not (10 <= len(key) <= 256 and all(33 <= ord(c) <= 126 for c in key)):
                return self._json(400, {'error': '密钥格式无效，请重新填写。'})
            with self.server.state_lock:
                if remove:
                    self.server.key = ''
                elif key:
                    self.server.key = key
                self.server.model = model
            return self._json(200, {'ok': True})
        if path == '/api/agent/request':
            messages = body.get('messages')
            if (not isinstance(messages, list) or not 1 <= len(messages) <= 20
                    or any(not isinstance(m, dict)
                           or not isinstance(m.get('role'), str)
                           or m.get('role') not in {'system', 'user', 'assistant'}
                           or not isinstance(m.get('content'), str)
                           or len(m['content']) > 120_000 for m in messages)):
                return self._json(400, {'error': '对话格式错误或过长。'})
            with self.server.state_lock:
                key, model = self.server.key, self.server.model
            if not key:
                return self._json(400, {'error': '请先在设置页填写并保存 API 密钥。'})
            if not self.server.request_lock.acquire(blocking=False):
                return self._json(429, {'error': '已有 AI 请求正在处理，请稍候。'})
            try:
                result = self.server.complete(key, model, messages)
                return self._json(200, result)
            except AgentError as error:
                return self._json(502, {'error': str(error)})
            except Exception:
                return self._json(502, {'error': 'AI 请求失败，原数据保留，请重试。'})
            finally:
                self.server.request_lock.release()
        return self._json(404, {'error': '接口不存在。'})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8787)
    parser.add_argument('--directory', default=str(Path(__file__).resolve().parents[1] / 'build' / 'web'))
    args = parser.parse_args()
    server = DemoServer(('127.0.0.1', args.port), args.directory)
    print(f'FocusNest: http://127.0.0.1:{args.port}/#/settings', flush=True)
    try:
        server.serve_forever()
    finally:
        server.key = ''
        server.server_close()
