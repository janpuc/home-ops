"""Matrix bridge: Janek's guidance interface to the agents queue.

Commands in the room (anyone but the bot's own account):
  !g <text>    queue a cluster-guardian task
  !dev <text>  queue a miroir-dev task on fable
  !pr <text>   queue a pr-review task
  !fable <cmd> <text>  force fable for any of the above (!fable g ...)
  !queue       reply with queue state
Results are posted back to the room as they land in done/, truncated
with the full path for code-server. The since token and seen-results
state live on the NAS so pod restarts neither replay old commands nor
repost old results. Failures never crash the loop - the bridge is a
convenience, the queue files remain the source of truth.
"""
import json
import os
import re
import threading
import time
import urllib.parse
import urllib.request

HS = os.environ["MATRIX_HOMESERVER"].rstrip("/")
TOKEN = os.environ["MATRIX_ACCESS_TOKEN"]
ROOM = os.environ["AGENTS_ROOM"]
QUEUE = "/nas/queue"
STATE = "/nas/logs/bridge"
ROLES = {"g": ("cluster-guardian", None), "dev": ("miroir-dev", "fable"), "pr": ("pr-review", None)}


def api(path, data=None, method=None, timeout=40):
    req = urllib.request.Request(
        HS + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Authorization": "Bearer " + TOKEN, "Content-Type": "application/json"},
        method=method,
    )
    return json.loads(urllib.request.urlopen(req, timeout=timeout).read())


def send(text):
    try:
        txn = f"agents-{time.time_ns()}"
        api(
            f"/_matrix/client/v3/rooms/{urllib.parse.quote(ROOM)}/send/m.room.message/{txn}",
            {"msgtype": "m.notice", "body": text},
            method="PUT",
        )
    except Exception:
        pass


def queue_state():
    parts = []
    for state, sub in (("backlog", "backlog"), ("claimed", "claimed/coordinator"), ("done", "done")):
        try:
            names = sorted(n for n in os.listdir(os.path.join(QUEUE, sub)) if n.endswith(".md") and not n.endswith(".result.md"))
        except OSError:
            names = []
        parts.append(f"{state} ({len(names)}): " + (", ".join(names[:6]) or "-"))
    return "\n".join(parts)


def handle(body):
    m = re.match(r"!(fable\s+)?(g|dev|pr|queue)\s*(.*)", body, re.S)
    if not m:
        return
    force_fable, cmd, text = bool(m.group(1)), m.group(2), m.group(3).strip()
    if cmd == "queue":
        send(queue_state())
        return
    if not text:
        send(f"!{cmd} needs a task description")
        return
    role, model = ROLES[cmd]
    if force_fable:
        model = "fable"
    name = f"manual-mx-{time.strftime('%Y%m%dT%H%M%S')}.md"
    os.makedirs(os.path.join(QUEUE, "backlog"), exist_ok=True)
    path = os.path.join(QUEUE, "backlog", name)
    with open(path + ".partial", "w") as f:
        f.write(f"Task from Matrix\n\nrole: {role}\n")
        if model:
            f.write(f"model: {model}\n")
        f.write(f"\n{text}\n")
    os.rename(path + ".partial", path)
    send(f"queued {name} (role {role}{', model ' + model if model else ''})")


def results_watcher():
    os.makedirs(STATE, exist_ok=True)
    seen_path = os.path.join(STATE, "seen-results.txt")
    try:
        seen = set(open(seen_path).read().split())
    except OSError:
        seen = set()
    if not seen:
        try:
            seen = {n for n in os.listdir(os.path.join(QUEUE, "done")) if n.endswith(".result.md")}
            open(seen_path, "w").write("\n".join(sorted(seen)))
        except OSError:
            pass
    while True:
        try:
            for name in sorted(os.listdir(os.path.join(QUEUE, "done"))):
                if not name.endswith(".result.md") or name in seen:
                    continue
                body = open(os.path.join(QUEUE, "done", name)).read()
                head = body[:1500] + ("\n[...truncated]" if len(body) > 1500 else "")
                send(f"result: {name}\n\n{head}\n\nfull: /nas/queue/done/{name}")
                seen.add(name)
                open(seen_path, "w").write("\n".join(sorted(seen)))
        except Exception:
            pass
        time.sleep(30)


def main():
    me = api("/_matrix/client/v3/account/whoami")["user_id"]
    threading.Thread(target=results_watcher, daemon=True).start()
    os.makedirs(STATE, exist_ok=True)
    since_path = os.path.join(STATE, "since.txt")
    since = ""
    try:
        since = open(since_path).read().strip()
    except OSError:
        pass
    while True:
        try:
            qs = f"timeout=30000&filter=" + urllib.parse.quote(json.dumps({"room": {"rooms": [ROOM], "timeline": {"limit": 20}}}))
            if since:
                qs += "&since=" + urllib.parse.quote(since)
            resp = api("/_matrix/client/v3/sync?" + qs, timeout=60)
            new_since = resp.get("next_batch", "")
            first_sync = not since
            for ev in ((resp.get("rooms", {}).get("join", {}).get(ROOM, {}) or {}).get("timeline", {}) or {}).get("events", []):
                if first_sync or ev.get("sender") == me or ev.get("type") != "m.room.message":
                    continue
                body = (ev.get("content") or {}).get("body") or ""
                if body.startswith("!"):
                    handle(body)
            since = new_since
            open(since_path, "w").write(since)
        except Exception:
            time.sleep(10)


main()
