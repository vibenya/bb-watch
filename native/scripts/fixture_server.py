#!/usr/bin/env python3
"""Loopback-only synthetic sink. Not the plugin protocol; no auth, ASR or dispatch."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import hashlib, json, pathlib, tempfile, uuid
root = pathlib.Path(tempfile.mkdtemp(prefix="voiceprobe-http-"))
class Sink(BaseHTTPRequestHandler):
    def do_PUT(self):
        try:
            op = str(uuid.UUID(self.headers.get("X-Probe-ID", "")))
            length = int(self.headers.get("Content-Length", "-1"))
            assert 0 <= length <= 1048576 and self.path == "/fixture"
        except (ValueError, AssertionError):
            self.send_error(400); return
        body = self.rfile.read(length)
        if len(body) != length:
            self.send_error(400); return
        target = root / (op + ".bin")
        if target.exists() and target.read_bytes() != body:
            self.send_error(409); return
        target.write_bytes(body)
        response = json.dumps({"fixture_only": True, "sha256": hashlib.sha256(body).hexdigest()}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response))); self.end_headers(); self.wfile.write(response)
    def log_message(self, *_): pass
server = HTTPServer(("127.0.0.1", 0), Sink)
print(f"http://127.0.0.1:{server.server_port}/fixture", flush=True)
server.serve_forever()
