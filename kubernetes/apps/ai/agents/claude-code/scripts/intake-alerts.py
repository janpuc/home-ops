"""Turn Alertmanager webhook posts into guardian queue tasks.

One task per Alertmanager GROUP, never per alert: the route groups by
alertname/cluster/job, and a single incident (like a storage wedge) can
fan out into 100+ alert fingerprints that all share one root cause.
Task identity is the hash of the groupKey, deduped across every queue
state, so a still-firing group never spawns a second task while the
first is anywhere in flight. Resolved-only notifications are ignored on
purpose. Fail-open HTTP 200 always - Alertmanager retries on non-2xx
and a poison payload must not wedge the receiver.
"""
import hashlib
import json
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer

QUEUE = "/nas/queue"
METRICS = "/nas/logs/guardian/metrics.json"
MAX_LISTED = 20


def render_metrics():
    lines = []
    for state, sub in (
        ("backlog", "backlog"),
        ("claimed", "claimed/coordinator"),
        ("review", "review"),
        ("done", "done"),
    ):
        root = os.path.join(QUEUE, sub)
        try:
            count = len([n for n in os.listdir(root) if n.endswith(".md")])
        except OSError:
            count = 0
        lines.append(f'agents_queue_tasks{{state="{state}"}} {count}')
    try:
        with open(METRICS) as f:
            m = json.load(f)
    except (OSError, ValueError):
        m = {}
    lines.append(f"agents_guardian_runs_total {m.get('runs_total', 0)}")
    lines.append(f"agents_guardian_failures_total {m.get('failures_total', 0)}")
    lines.append(
        f'agents_guardian_tokens_total{{type="input"}} {m.get("tokens_input_total", 0)}'
    )
    lines.append(
        f'agents_guardian_tokens_total{{type="output"}} {m.get("tokens_output_total", 0)}'
    )
    lines.append(f"agents_guardian_cost_usd_total {m.get('cost_usd_total', 0.0)}")
    lines.append(
        f"agents_guardian_last_run_timestamp_seconds {m.get('last_run_timestamp', 0)}"
    )
    lines.append(
        f"agents_guardian_last_run_duration_seconds {m.get('last_run_duration_seconds', 0)}"
    )
    for runtime in ("claude", "opencode"):
        lines.append(
            f'agents_queue_runs_total{{runtime="{runtime}"}} {m.get(f"runs_{runtime}_total", 0)}'
        )
    return "\n".join(lines) + "\n"


def seen(group_id):
    for state in ("backlog", "claimed/coordinator", "review", "done"):
        root = os.path.join(QUEUE, state)
        if not os.path.isdir(root):
            continue
        for name in os.listdir(root):
            if group_id in name:
                return True
    return False


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.rstrip("/") == "/metrics":
            body = render_metrics().encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        try:
            raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            payload = json.loads(raw)
            firing = [a for a in payload.get("alerts", []) if a.get("status") == "firing"]
            if not firing:
                raise ValueError("nothing firing")
            group_id = hashlib.sha256(
                payload.get("groupKey", "nokey").encode()
            ).hexdigest()[:12]
            if seen(group_id):
                raise ValueError("group already queued")
            name = payload.get("commonLabels", {}).get("alertname") or firing[0].get(
                "labels", {}
            ).get("alertname", "unknown")
            slug = re.sub(r"[^A-Za-z0-9_-]", "-", name)[:40]
            os.makedirs(os.path.join(QUEUE, "backlog"), exist_ok=True)
            path = os.path.join(QUEUE, "backlog", f"alert-{slug}-{group_id}.md")
            tmp = path + ".partial"
            severity = payload.get("commonLabels", {}).get("severity", "")
            with open(tmp, "w") as f:
                f.write(f"Alert group: {name} ({len(firing)} firing)\n\n")
                f.write("role: cluster-guardian\n")
                if severity == "critical":
                    f.write("model: fable\n")
                f.write("\nCommon labels:\n\n")
                for k, v in sorted(payload.get("commonLabels", {}).items()):
                    f.write(f"- {k}: {v}\n")
                f.write("\nCommon annotations:\n\n")
                for k, v in sorted(payload.get("commonAnnotations", {}).items()):
                    f.write(f"- {k}: {v}\n")
                f.write("\nMember alerts:\n\n")
                for alert in firing[:MAX_LISTED]:
                    labels = alert.get("labels", {})
                    detail = ", ".join(
                        f"{k}={v}"
                        for k, v in sorted(labels.items())
                        if k not in payload.get("commonLabels", {})
                    )
                    f.write(f"- {detail or 'identical to common labels'}\n")
                if len(firing) > MAX_LISTED:
                    f.write(f"- ... and {len(firing) - MAX_LISTED} more\n")
                f.write(f"\nstartsAt: {firing[0].get('startsAt', '')}\n")
            os.rename(tmp, path)
        except Exception:
            pass
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):
        pass


HTTPServer(("0.0.0.0", 9096), Handler).serve_forever()
