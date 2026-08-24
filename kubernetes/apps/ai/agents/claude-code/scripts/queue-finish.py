"""Close out one queue run: extract the result, update run metrics.

Reads the run artifacts for either runtime (claude stream-json transcript
or opencode plain-text output), prints the final result text to stdout
(redirected into the queue's .result.md by the loop), and folds the run's
cost/token/duration numbers into metrics.json for the intake /metrics
endpoint. Exit codes steer the loop: 42 means rate-limited (requeue with
backoff), 43 means the run asked for escalation (requeue on claude/fable),
anything else is terminal. A run with a nonzero exit or an empty result
counts as a failure and its result note carries the stderr tail, so silent
failures leave a visible trace instead of an empty file. OpenCode runs
report no token/cost numbers - the subscription is flat rate and opencode's
text output carries no usage data; runs are still counted.
"""
import json
import os
import sys
import time

task, out, runtime, rc, start = (
    sys.argv[1],
    sys.argv[2],
    sys.argv[3],
    int(sys.argv[4]),
    int(sys.argv[5]),
)
METRICS = "/nas/logs/guardian/metrics.json"

result_text = ""
cost = 0.0
tokens_in = 0
tokens_out = 0
rate_limited = False

if runtime == "claude":
    try:
        with open(out + ".jsonl") as f:
            for line in f:
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if d.get("type") == "rate_limit_event":
                    rate_limited = True
                if d.get("type") == "result":
                    result_text = d.get("result") or ""
                    cost = float(d.get("total_cost_usd") or 0)
                    usage = d.get("usage") or {}
                    tokens_in = int(usage.get("input_tokens") or 0)
                    tokens_out = int(usage.get("output_tokens") or 0)
    except OSError:
        pass
    if "session limit" in result_text.lower():
        rate_limited = True
else:
    try:
        result_text = open(out + ".txt").read().strip()
    except OSError:
        pass

failed = rc != 0 or not result_text.strip()
escalate = (
    not failed
    and runtime != "claude"
    and "ESCALATE" in result_text
)

try:
    with open(METRICS) as f:
        m = json.load(f)
except (OSError, ValueError):
    m = {}
m["runs_total"] = m.get("runs_total", 0) + 1
m["failures_total"] = m.get("failures_total", 0) + (1 if failed and not rate_limited else 0)
m["tokens_input_total"] = m.get("tokens_input_total", 0) + tokens_in
m["tokens_output_total"] = m.get("tokens_output_total", 0) + tokens_out
m["cost_usd_total"] = round(m.get("cost_usd_total", 0.0) + cost, 6)
m["last_run_timestamp"] = int(time.time())
m["last_run_duration_seconds"] = int(time.time()) - start
m[f"runs_{runtime}_total"] = m.get(f"runs_{runtime}_total", 0) + 1
tmp = METRICS + ".partial"
with open(tmp, "w") as f:
    json.dump(m, f)
os.rename(tmp, METRICS)

if failed and rate_limited:
    print(f"RATE LIMITED for {task}; requeued for retry after backoff")
    sys.exit(42)
if escalate:
    print(f"ESCALATED {task} to claude/fable")
    sys.exit(43)
if failed:
    print(f"QUEUE RUN FAILED (runtime {runtime}, exit {rc}) for {task}")
    print(f"Artifacts: {out}.*")
    try:
        with open(out + ".stderr") as f:
            tail = f.read()[-2000:]
        if tail.strip():
            print("\nstderr tail:\n")
            print(tail)
    except OSError:
        pass
else:
    print(result_text)
