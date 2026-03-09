#!/usr/bin/env python3
import json
import os
import subprocess
import time
import unittest
from http.client import HTTPConnection


class TestServer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """Start the server once for all tests."""
        cls.port = 8001
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cls.process = subprocess.Popen(
            ['python3', 'server.py'],
            env={**os.environ, 'PORT': str(cls.port)},
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=project_root
        )
        # Wait for server to start
        time.sleep(0.5)
        if cls.process.poll() is not None:
            raise RuntimeError("Server failed to start")

    @classmethod
    def tearDownClass(cls):
        """Stop the server after all tests."""
        cls.process.terminate()
        cls.process.wait(timeout=5)

    def _make_request(self, path):
        """Helper to make HTTP request and return response."""
        conn = HTTPConnection('localhost', self.port, timeout=5)
        conn.request('GET', path)
        response = conn.getresponse()
        body = response.read()
        conn.close()
        return response, body

    def test_get_root_returns_200(self):
        """Test: GET / returns HTTP 200"""
        response, _ = self._make_request('/')
        self.assertEqual(response.status, 200)

    def test_get_root_body_is_valid_json(self):
        """Test: GET / body is valid JSON {"status": "ok"}"""
        response, body = self._make_request('/')
        data = json.loads(body.decode())
        self.assertEqual(data, {"status": "ok"})

    def test_get_root_content_type_is_json(self):
        """Test: GET / Content-Type is application/json"""
        response, _ = self._make_request('/')
        self.assertEqual(response.headers['Content-Type'], 'application/json')

    def test_get_unknown_returns_404(self):
        """Test: GET /unknown returns HTTP 404"""
        response, _ = self._make_request('/unknown')
        self.assertEqual(response.status, 404)

    def test_get_health_returns_200(self):
        """Test: GET /health returns HTTP 200"""
        response, _ = self._make_request('/health')
        self.assertEqual(response.status, 200)

    def test_get_health_body_contains_status_ok(self):
        """Test: GET /health body contains "status": "ok" """
        response, body = self._make_request('/health')
        data = json.loads(body.decode())
        self.assertEqual(data['status'], 'ok')

    def test_get_health_body_contains_uptime_number(self):
        """Test: GET /health body contains "uptime" as a number (float or int)"""
        response, body = self._make_request('/health')
        data = json.loads(body.decode())
        self.assertIn('uptime', data)
        self.assertIsInstance(data['uptime'], (int, float))


if __name__ == '__main__':
    unittest.main()
