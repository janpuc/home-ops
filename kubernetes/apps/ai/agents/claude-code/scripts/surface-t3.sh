#!/bin/sh
set -u
PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export PATH
cd /workspace || exit 1
while true; do
  t3 serve --host 0.0.0.0 --port 7333 --no-browser --auto-bootstrap-project-from-cwd /workspace || true
  sleep 10
done
