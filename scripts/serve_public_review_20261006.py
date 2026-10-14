"""Serve the existing Flutter build locally, with parallel browser connections."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
import os
ROOT = Path(__file__).resolve().parents[1] / 'build' / 'web'
os.chdir(ROOT)
class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        requested = ROOT / urlsplit(self.path).path.lstrip('/')
        if not requested.exists():
            self.path = '/index.html'
        super().do_GET()
    def log_message(self, format, *args):
        pass
ThreadingHTTPServer(('127.0.0.1', 8092), Handler).serve_forever()
