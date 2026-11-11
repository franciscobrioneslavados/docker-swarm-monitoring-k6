import json
import os
import threading
import time
from collections import defaultdict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


lock = threading.Lock()
request_counts = defaultdict(int)
request_duration = defaultdict(float)


def escape_label(value):
    return value.replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        started = time.perf_counter()
        parsed = urlparse(self.path)
        endpoint = parsed.path if parsed.path in ("/health", "/work", "/error") else "/other"
        query = parse_qs(parsed.query)
        delay_ms = min(max(int(query.get("delay_ms", ["0"])[0]), 0), 500)
        if delay_ms:
            time.sleep(delay_ms / 1000)

        if endpoint == "/health":
            status, body = 200, {"status": "ok"}
        elif endpoint == "/error":
            status, body = 500, {"status": "error", "message": "intentional test error"}
        elif endpoint == "/work":
            status, body = 200, {"status": "ok", "delay_ms": delay_ms, "node": os.uname().nodename}
        else:
            status, body = 404, {"status": "not_found"}

        duration = time.perf_counter() - started
        with lock:
            request_counts[(endpoint, status)] += 1
            request_duration[(endpoint, status)] += duration

        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)
        print(json.dumps({
            "event": "http_request",
            "method": "GET",
            "path": endpoint,
            "status": status,
            "duration_seconds": round(duration, 6),
            "node": os.uname().nodename,
        }), flush=True)

    def log_message(self, fmt, *args):
        return


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if urlparse(self.path).path != "/metrics":
            self.send_error(404)
            return

        lines = [
            "# HELP demo_http_requests_total HTTP requests handled by the demo.",
            "# TYPE demo_http_requests_total counter",
            "# HELP demo_http_request_duration_seconds_sum Total request duration in seconds.",
            "# TYPE demo_http_request_duration_seconds_sum counter",
        ]
        with lock:
            for (endpoint, status), count in sorted(request_counts.items()):
                labels = f'endpoint="{escape_label(endpoint)}",status="{status}"'
                lines.append(f"demo_http_requests_total{{{labels}}} {count}")
                lines.append(
                    f"demo_http_request_duration_seconds_sum{{{labels}}} "
                    f"{request_duration[(endpoint, status)]:.9f}"
                )
        payload = ("\n".join(lines) + "\n").encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        return


def serve(server):
    server.serve_forever()


application = ThreadingHTTPServer(("0.0.0.0", 8080), Handler)
metrics = ThreadingHTTPServer(("0.0.0.0", 8081), MetricsHandler)
threading.Thread(target=serve, args=(metrics,), daemon=True).start()
print("demo application listening on :8080 and metrics on :8081", flush=True)
serve(application)
