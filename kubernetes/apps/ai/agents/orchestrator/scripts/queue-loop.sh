#!/bin/sh
set -u
PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/.npm-global/bin:$PATH"
export PATH
QUEUE=/nas/queue
LOGS=/nas/logs/guardian
mkdir -p "$QUEUE/backlog" "$QUEUE/claimed/coordinator" "$QUEUE/done" "$LOGS"
for stranded in "$QUEUE/claimed/coordinator"/*.md; do
  [ -f "$stranded" ] && mv "$stranded" "$QUEUE/backlog/" 2>/dev/null
done
cd /workspace || exit 1
while true; do
  task=$(find "$QUEUE/backlog" -maxdepth 1 -name "*.md" -printf "%f\n" 2>/dev/null | sort | head -1)
  if [ -n "$task" ]; then
    mv "$QUEUE/backlog/$task" "$QUEUE/claimed/coordinator/$task" 2>/dev/null || continue
    ts=$(date -u +%Y%m%dT%H%M%SZ)
    out="$LOGS/${task%.md}-$ts"
    start=$(date +%s)
    claimed="$QUEUE/claimed/coordinator/$task"
    model=$(sed -n "s/^model: //p" "$claimed" | head -1)
    rolename=$(sed -n "s/^role: //p" "$claimed" | head -1)
    runtime=$(sed -n "s/^runtime: //p" "$claimed" | head -1)
    ROLE="/nas/roles/${rolename:-cluster-guardian}.md"
    [ -f "$ROLE" ] || ROLE=/nas/roles/cluster-guardian.md
    if [ -z "$runtime" ]; then
      case "${model:-}" in
        fable|opus) runtime=claude ;;
        *) case "${rolename:-cluster-guardian}" in
             miroir-dev) runtime=claude ;;
             *) runtime=opencode ;;
           esac ;;
      esac
    fi
    if [ "$runtime" = "claude" ]; then
      {
        cat "$ROLE" 2>/dev/null
        printf "\n\nTask:\n\n"
        cat "$claimed"
      } | claude -p --verbose --output-format stream-json --model "${model:-opus}" --settings /nas/roles/claude-queue-settings.json > "$out.jsonl" 2> "$out.stderr"
      rc=$?
      cat "$out.jsonl"
    else
      {
        cat "$ROLE" 2>/dev/null
        printf "\n\nTask:\n\n"
        cat "$claimed"
      } | opencode run -m "litellm/${model:-minimax/MiniMax-M3}" > "$out.txt" 2> "$out.stderr"
      rc=$?
      cat "$out.txt"
    fi
    python3 /opt/agents/queue-finish.py "$task" "$out" "$runtime" "$rc" "$start" > "$QUEUE/done/${task%.md}.result.md"
    finishrc=$?
    if [ "$finishrc" = "42" ]; then
      rm -f "$QUEUE/done/${task%.md}.result.md"
      mv "$claimed" "$QUEUE/backlog/$task" 2>/dev/null || true
      sleep 1800
    elif [ "$finishrc" = "43" ]; then
      rm -f "$QUEUE/done/${task%.md}.result.md"
      {
        printf "runtime: claude\nmodel: fable\nescalated: true\n\n"
        cat "$claimed"
      } > "$QUEUE/backlog/$task"
      rm -f "$claimed"
    else
      mv "$claimed" "$QUEUE/done/$task" 2>/dev/null || true
    fi
  fi
  sleep 30
done
