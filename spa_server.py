"""SPA-aware static file server for Flutter Web (go_router path-based routing).
Serves the actual file if it exists (JS, CSS, assets, images...), otherwise
falls back to index.html so client-side routing (/fr/livraison, /en/faq, etc.)
works correctly on direct load, bookmark, or page refresh.
"""
import http.server
import socketserver
import os

class SPARequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        super().end_headers()

    def do_GET(self):
        # Strip query string for file existence check
        path_only = self.path.split('?', 1)[0]
        fs_path = self.translate_path(path_only)
        if not os.path.exists(fs_path) or os.path.isdir(fs_path) and not os.path.exists(os.path.join(fs_path, 'index.html')):
            if not os.path.isdir(fs_path):
                self.path = '/index.html'
        super().do_GET()

with socketserver.TCPServer(('0.0.0.0', 5060), SPARequestHandler) as httpd:
    httpd.serve_forever()
