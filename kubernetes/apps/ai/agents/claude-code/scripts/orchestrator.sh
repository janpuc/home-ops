#!/bin/sh
set -u
PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/.npm-global/bin:$PATH"
export PATH
cd /workspace || exit 1
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=prometheus
while true; do
  claude remote-control || true
  sleep 30
done
