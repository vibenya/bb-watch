#!/usr/bin/env python3
"""Loopback-only synthetic sink. Not the plugin protocol; no auth, ASR or dispatch."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import argparse, hashlib, json, os, pathlib, tempfile, time, uuid
parser = argparse.ArgumentParser()
parser.add_argument('--root', type=pathlib.Path)
parser.add_argument('--hold-response', type=pathlib.Path)
args = parser.parse_args()
root = args.root or pathlib.Path(tempfile.mkdtemp(prefix='voiceprobe-http-'))
root.mkdir(parents=True, exist_ok=True)
class Sink(BaseHTTPRequestHandler):
    def do_PUT(self):
        try:
            op = str(uuid.UUID(self.headers.get('X-Probe-ID', '')))
            length = int(self.headers.get('Content-Length', '-1'))
            assert 0 <= length <= 1048576 and self.path == '/fixture'
        except (ValueError, AssertionError):
            self.send_error(400); return
        body = self.rfile.read(length)
        if body != b'voiceprobe-synthetic-fixture-v1':
            self.send_error(400); return
        target = root / (op + '.bin')
        if target.exists() and target.read_bytes() != body:
            self.send_error(409); return
        with target.open('wb') as f:
            f.write(body); f.flush(); os.fsync(f.fileno())
        with (root / 'requests.jsonl').open('a') as f:
            f.write(json.dumps(dict(request=op, bytes=len(body), sha256=hashlib.sha256(body).hexdigest(), at=time.time()))+'\n')
            f.flush(); os.fsync(f.fileno())
        if args.hold_response:
            deadline = time.monotonic() + 30
            while not args.hold_response.exists() and time.monotonic() < deadline: time.sleep(.05)
        response = json.dumps({'fixture_only': True, 'sha256': hashlib.sha256(body).hexdigest()}).encode()
        self.send_response(200); self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response))); self.end_headers()
        try: self.wfile.write(response)
        except (BrokenPipeError, ConnectionResetError): pass
    def log_message(self, *_): pass
server = ThreadingHTTPServer(('127.0.0.1', 0), Sink)
print(f'http://127.0.0.1:{server.server_port}/fixture', flush=True)
server.serve_forever()
