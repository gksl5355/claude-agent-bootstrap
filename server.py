#!/usr/bin/env python3
import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

START_TIME = time.time()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            body = json.dumps({"status": "ok"}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(body))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == '/health':
            uptime = round(time.time() - START_TIME, 2)
            body = json.dumps({"status": "ok", "uptime": uptime}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(body))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # suppress request logs


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=None, help='Port to listen on')
    args = parser.parse_args()
    port = args.port if args.port is not None else int(os.environ.get('PORT', 8000))
    server = HTTPServer(('', port), Handler)
    print(f"Server running on port {port}")
    server.serve_forever()
