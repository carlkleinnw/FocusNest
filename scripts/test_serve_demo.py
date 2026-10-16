import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from serve_demo import DemoServer


class DemoBridgeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        Path(self.directory.name, 'index.html').write_text('test page', encoding='utf-8')
        self.calls = []
        def complete(key, model, messages):
            self.calls.append((key, model, messages))
            return {'ok': True}
        self.server = DemoServer(('127.0.0.1', 0), self.directory.name, complete)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f'http://127.0.0.1:{self.server.server_port}'
        self.fake = 'integration-placeholder-not-a-real-key'

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.directory.cleanup()

    def call(self, path, body=None, headers=None):
        request_headers = {'Content-Type': 'application/json'}
        request_headers.update(headers or {})
        request = urllib.request.Request(self.url + path,
            data=None if body is None else json.dumps(body).encode(), headers=request_headers)
        try:
            response = urllib.request.urlopen(request, timeout=5)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.code, json.load(response)

    def configure(self, key=None, remove=False):
        return self.call('/api/agent/configure', {'key': self.fake if key is None else key,
            'model': 'deepseek-flash', 'remove': remove})

    def test_save_is_memory_only_never_calls_upstream_or_returns_key(self):
        self.assertEqual(self.configure(), (200, {'ok': True}))
        status, result = self.call('/api/agent/settings')
        self.assertEqual(status, 200)
        self.assertTrue(result['configured'])
        self.assertNotIn(self.fake, json.dumps(result))
        self.assertEqual(result['storage'], 'process-memory')
        self.assertEqual(self.calls, [])
        self.assertEqual(list(Path(self.directory.name).iterdir()), [Path(self.directory.name, 'index.html')])

    def test_blank_retains_key_and_remove_clears_it(self):
        self.configure()
        self.configure(key='')
        self.assertTrue(self.call('/api/agent/settings')[1]['configured'])
        self.configure(key='', remove=True)
        self.assertFalse(self.call('/api/agent/settings')[1]['configured'])

    def test_request_requires_key_then_uses_controlled_upstream(self):
        body = {'messages': [{'role': 'user', 'content': 'JSON connection test'}]}
        self.assertEqual(self.call('/api/agent/request', body)[0], 400)
        self.assertEqual(self.calls, [])
        self.configure()
        self.assertEqual(self.call('/api/agent/request', body), (200, {'ok': True}))
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.calls[0][0], self.fake)

    def test_cross_origin_and_rebound_host_cannot_save(self):
        body = {'key': self.fake, 'model': 'deepseek-flash'}
        for headers in [{'Origin': 'https://example.com'}, {'Host': 'example.com'},
                        {'Sec-Fetch-Site': 'cross-site'}]:
            self.assertEqual(self.call('/api/agent/configure', body, headers)[0], 403)
        self.assertFalse(self.call('/api/agent/settings')[1]['configured'])

    def test_invalid_inputs_do_not_change_configuration(self):
        for body in [{'key': self.fake, 'model': 'unknown'},
                     {'key': self.fake, 'model': []},
                     {'key': 123, 'model': 'deepseek-flash'},
                     {'key': 'short', 'model': 'deepseek-flash'}]:
            self.assertEqual(self.call('/api/agent/configure', body)[0], 400)
        self.assertEqual(self.call('/api/agent/configure', {}, {'Content-Type': 'text/plain'})[0], 415)
        self.assertEqual(self.call('/api/agent/request', {'messages': [{'role': 'system'}]})[0], 400)
        self.assertEqual(self.call('/api/agent/request', {'messages': [{'role': [], 'content': 'test'}]})[0], 400)

    def test_unexpected_upstream_error_cannot_expose_key(self):
        self.configure()
        def fail(*args):
            raise RuntimeError(self.fake)
        self.server.complete = fail
        status, result = self.call('/api/agent/request', {'messages': [{'role': 'user', 'content': 'test'}]})
        self.assertEqual(status, 502)
        self.assertNotIn(self.fake, json.dumps(result))

    def test_static_content_has_no_store_and_no_key_material(self):
        self.configure()
        with urllib.request.urlopen(self.url, timeout=5) as response:
            self.assertEqual(response.headers['Cache-Control'], 'no-store')
            self.assertNotIn(self.fake, response.read().decode())

    def test_new_server_starts_without_credentials(self):
        self.configure()
        other = DemoServer(('127.0.0.1', 0), self.directory.name)
        try:
            self.assertEqual(other.key, '')
        finally:
            other.server_close()


if __name__ == '__main__':
    unittest.main()
