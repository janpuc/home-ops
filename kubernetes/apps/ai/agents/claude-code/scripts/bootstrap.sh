#!/bin/sh
set -eu
BIN="$HOME/.local/bin"
mkdir -p "$BIN" "$HOME/.npm-global"
installed="$("$BIN/claude" --version 2>/dev/null | cut -d" " -f1 || true)"
if [ "$installed" != "$CLAUDE_CODE_VERSION" ]; then
  curl -fsSL "https://downloads.claude.ai/claude-code-releases/${CLAUDE_CODE_VERSION}/linux-x64/claude" -o "$BIN/claude.partial"
  chmod 755 "$BIN/claude.partial"
  mv "$BIN/claude.partial" "$BIN/claude"
fi
if ! [ -x "$HOME/.npm-global/bin/t3" ]; then
  npm install --global --prefix "$HOME/.npm-global" t3@latest
fi
if ! [ "$("$HOME/.npm-global/bin/opencode" --version 2>/dev/null)" = "$OPENCODE_VERSION" ]; then
  npm install --global --prefix "$HOME/.npm-global" "opencode-ai@$OPENCODE_VERSION"
fi
if ! [ -f "$HOME/.config/opencode/opencode.json" ]; then
  mkdir -p "$HOME/.config/opencode"
  cat > "$HOME/.config/opencode/opencode.json" <<'OCCFG'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "litellm": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LiteLLM",
      "options": {
        "baseURL": "http://litellm.ai:4000/v1",
        "apiKey": "{env:LITELLM_API_KEY}"
      },
      "models": {
        "minimax/MiniMax-M3": {},
        "opencode-go/glm-5.2": {},
        "opencode-go/deepseek-v4-flash-vision-exp": {},
        "opencode-go/hy3": {}
      }
    }
  }
}
OCCFG
fi
ghinstalled="$("$BIN/gh" --version 2>/dev/null | head -1 | cut -d" " -f3 || true)"
if [ "$ghinstalled" != "$GH_CLI_VERSION" ]; then
  curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_CLI_VERSION}/gh_${GH_CLI_VERSION}_linux_amd64.tar.gz" | tar -xz -C /tmp
  install -m 755 "/tmp/gh_${GH_CLI_VERSION}_linux_amd64/bin/gh" "$BIN/gh"
  rm -rf "/tmp/gh_${GH_CLI_VERSION}_linux_amd64"
fi
if ! [ "$(cat "$BIN/.koment-version" 2>/dev/null)" = "$KOMENT_CLI_VERSION" ]; then
  curl -fsSL "https://github.com/koment-dev/koment/releases/download/v${KOMENT_CLI_VERSION}/koment_${KOMENT_CLI_VERSION}_linux_amd64.tar.gz" | tar -xz -C /tmp koment
  install -m 755 /tmp/koment "$BIN/koment"
  rm -f /tmp/koment
  printf %s "$KOMENT_CLI_VERSION" > "$BIN/.koment-version"
fi
if ! [ "$(cat "$BIN/.kubectl-version" 2>/dev/null)" = "$KUBECTL_VERSION" ]; then
  curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o "$BIN/kubectl.partial"
  chmod 755 "$BIN/kubectl.partial"
  mv "$BIN/kubectl.partial" "$BIN/kubectl"
  printf %s "$KUBECTL_VERSION" > "$BIN/.kubectl-version"
fi
if ! [ "$(cat "$BIN/.flux-version" 2>/dev/null)" = "$FLUX_CLI_VERSION" ]; then
  curl -fsSL "https://github.com/fluxcd/flux2/releases/download/v${FLUX_CLI_VERSION}/flux_${FLUX_CLI_VERSION}_linux_amd64.tar.gz" | tar -xz -C /tmp flux
  install -m 755 /tmp/flux "$BIN/flux"
  rm -f /tmp/flux
  printf %s "$FLUX_CLI_VERSION" > "$BIN/.flux-version"
fi
if ! [ "$(cat "$HOME/.local/.go-version" 2>/dev/null)" = "$GO_VERSION" ]; then
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tgz
  rm -rf "$HOME/.local/go"
  tar -xz -C "$HOME/.local" -f /tmp/go.tgz
  rm -f /tmp/go.tgz
  printf %s "$GO_VERSION" > "$HOME/.local/.go-version"
fi
git config --global user.name >/dev/null 2>&1 || git config --global user.name "janpuc"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "janpuc@proton.me"
git config --global credential.helper >/dev/null 2>&1 || git config --global credential.helper "!$BIN/gh auth git-credential"
if ! git config --global gpg.format >/dev/null 2>&1; then
  git config --global gpg.format ssh
  git config --global user.signingkey /etc/claude-code/signing/id_ed25519
  git config --global commit.gpgsign true
fi
if [ -d /nas ]; then
  mkdir -p /nas/queue/backlog /nas/queue/claimed /nas/queue/review /nas/queue/done /nas/roles /nas/repos /nas/worktrees /nas/logs
  if [ -f /nas/roles/guardian-permissions.json ] && ! [ -f /nas/roles/claude-queue-settings.json ]; then
    cp /nas/roles/guardian-permissions.json /nas/roles/claude-queue-settings.json
  fi
  if ! [ -f /nas/roles/claude-queue-settings.json ]; then
    cat > /nas/roles/claude-queue-settings.json <<'PERMS'
{
  "permissions": {
    "allow": [
      "Bash(kubectl get:*)",
      "Bash(kubectl describe:*)",
      "Bash(kubectl logs:*)",
      "Bash(kubectl top:*)",
      "Bash(kubectl events:*)",
      "Bash(kubectl auth can-i:*)",
      "Bash(kubectl annotate:*)",
      "Bash(kubectl delete pod:*)",
      "Bash(kubectl rollout:*)",
      "Bash(flux get:*)",
      "Bash(flux reconcile:*)",
      "Bash(flux suspend:*)",
      "Bash(flux resume:*)",
      "Bash(kubectl version:*)",
      "Bash(kubectl api-resources:*)",
      "Bash(kubectl explain:*)",
      "Bash(flux stats:*)",
      "Bash(flux version:*)",
      "Bash(git:*)",
      "Bash(go build:*)",
      "Bash(go test:*)",
      "Bash(go vet:*)",
      "Bash(go mod:*)",
      "Bash(gofmt:*)",
      "Bash(gh repo clone:*)",
      "Bash(gh pr create:*)",
      "Bash(gh pr view:*)",
      "Bash(gh pr list:*)",
      "Bash(opencode:*)",
      "Edit",
      "Write"
    ],
    "additionalDirectories": ["/nas"]
  }
}
PERMS
  fi
  if ! [ -f /nas/roles/cluster-guardian.md ]; then
    cat > /nas/roles/cluster-guardian.md <<'ROLE'
Role: cluster-guardian

You are the cluster guardian for the home-ops Kubernetes cluster. An
Alertmanager alert triggered this run. Your job: triage it, resolve it if
that is safely within your power, and leave a clear result note.

Rules, in order:
1. Diagnose first with read-only commands (kubectl get/describe/logs,
   flux get). State the evidence before acting.
2. You may: delete stuck pods, patch workload annotations for rollout
   restarts, annotate Flux resources to reconcile or retry.
3. You must NEVER: remove node taints (miroir storage-wedged is
   protective), scale or delete stateful workloads during storage
   degradation, delete PVCs or Sandboxes (their PVCs cascade), or touch
   anything in the kopiur, miroir-system, or flux-system namespaces
   beyond reads and reconcile annotations.
4. A wedged-storage alert means: report and stop. The fix is a human
   hard power reset. Say so in the result.
5. If the root cause looks like a miroir bug, write an evidence pack
   (timestamps, log excerpts, resource states) suitable for a fork
   issue. Facts only, no drafted prose.
6. End the result with: what happened, what you did, what remains for
   the human.

Access note: kubectl and flux read commands in your allowlist run
without approval. Probe with kubectl get nodes, never kubectl version.
If a command is denied, say which exact command and proceed with the
allowed ones.

Model policy: routine runs use a cheap model. If this run hits the limit
of what you can untangle, or your findings recommend any destructive or
irreversible action, end the result with a single line containing the
word ESCALATE so a deeper run on a stronger model reviews it.
ROLE
  fi
  if ! [ -f /nas/roles/miroir-dev.md ]; then
    cat > /nas/roles/miroir-dev.md <<'ROLE'
Role: miroir-dev

You develop on Janek's miroir fork: github.com/janpuc/miroir. This
cluster runs that fork (chart oci://ghcr.io/janpuc/charts/miroir), so
every fix you land ships here through his pipeline.

Workflow:
1. Clone or fetch the fork under /nas/repos/miroir; create a worktree
   under /nas/worktrees/coordinator/<branch> and work there.
2. Branch names: fix/<short-topic>. Never commit to main, never push
   main. Commits are signed automatically by your git config.
3. Reproduce understanding before changing code: read the relevant
   reconciler paths, cite file:line evidence in your notes.
4. go build ./... and go test ./... must pass before you push. Go is
   at $HOME/.local/go/bin.
5. Push the branch to the fork and open a DRAFT pull request against
   the fork's main with gh pr create --draft --repo janpuc/miroir.
   The PR body: evidence first (timestamps, log excerpts, resource
   states), then the fix rationale. Janek reviews and merges.
6. Cluster interaction is read-only diagnosis. Never kubectl apply,
   never touch miroir-system beyond reads. Deployment is Janek's
   pipeline, not yours.
7. End the result with: branch name, PR URL, test output tail, and
   what remains for the human.
ROLE
  fi
  if ! [ -f /nas/roles/pr-review.md ]; then
    cat > /nas/roles/pr-review.md <<'ROLE'
Role: pr-review

You review pull requests on janpuc repositories (home-ops, koment, and
others). Produce a per-PR risk report with a recommended merge order.
You never merge, push, or approve - report only. For home-ops,
agent-coupled components (ai namespace bridges) always merge last.
ROLE
  fi
fi
if ! [ -d "$HOME/.claude/plugins/marketplaces/memini" ]; then
  "$BIN/claude" plugin marketplace add eleboucher/memini || echo "[bootstrap] memini marketplace add failed (non-fatal)"
fi
if ! grep -qs "memini@memini" "$HOME/.claude/plugins/installed_plugins.json"; then
  "$BIN/claude" plugin install memini@memini || echo "[bootstrap] memini plugin install failed (non-fatal)"
fi
"$BIN/claude" --version
