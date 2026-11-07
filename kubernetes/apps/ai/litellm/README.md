# litellm

Eight models, each one in use. Add a model back only when a client needs it.

| Model                             | Plan        | When it fails                    | Used by                                      |
| --------------------------------- | ----------- | -------------------------------- | -------------------------------------------- |
| `minimax/MiniMax-M3.1-Flash`      | MiniMax     | limit error, no fallback         | kritika reviews, Jan's OpenCode              |
| `opencode-go/deepseek-v4.1-flash` | OpenCode Go | falls back to MiniMax M3.1 Flash | memini, kritika confidence, Open WebUI tasks |
| `m3pro/huihui-qwen3.8-27b`        | M3 Pro      | falls back to MiniMax M3.1 Flash | Jan's Pi                                     |
| `m3pro-local/huihui-qwen3.8-27b`  | M3 Pro      | fails, never leaves the LAN      | Jan's Pi, private material                   |
| `m3pro-local/qwen3.8-27b`         | M3 Pro      | fails, never leaves the LAN      | austerity-watcher, pi-sec                    |
| `m3pro-local/qwen3.6-35b-a3b`     | M3 Pro      | fails, never leaves the LAN      | austerity-watcher, pi-sec                    |
| `m3pro/lustify-v2`                | M3 Pro      | fails                            | image generation on request                  |
| `m3pro/noobai-xl-1.1`             | M3 Pro      | fails                            | image generation on request                  |

MiniMax M3.1 Flash has no fallback on purpose: a Go-hosted MiniMax is billed per token, and
MiniMax's overflow once emptied the Go month. The `m3pro-local/` aliases stay out of every
fallback list (`routerSettings.fallbacks`, `context_window_fallbacks`) because they carry
private material; keep `default_fallbacks` unset.

## Keys

Each client has its own virtual key (`LiteLLMVirtualKey`), so the dashboard's Per-Client row
shows who used what. The operator creates the keys through the admin API (`spec.apiAccess`)
and writes each one into a Secret in the client's namespace. The keys, teams and spend live
in the `litellm-postgres` CloudNativePG cluster (`../database`).

| Key alias           | Models                                 | Budget       | Secret                              |
| ------------------- | -------------------------------------- | ------------ | ----------------------------------- |
| `kritika`           | MiniMax M3.1 Flash                     | none         | `kritika-system/kritika-litellm`    |
| `kritika-go`        | Go DeepSeek, MiniMax M3.1 Flash        | $10 / 7 days | `kritika-system/kritika-litellm-go` |
| `memini`            | Go DeepSeek, MiniMax M3.1 Flash        | $10 / 7 days | `ai/memini-litellm`                 |
| `open-webui`        | Go DeepSeek, MiniMax, `m3pro/huihui`   | none         | `ai/open-webui-litellm`             |
| `austerity-watcher` | the two `m3pro-local/` Qwens           | none         | `ai/austerity-watcher-litellm`      |
| `jan-laptop`        | all, plus the MCP servers (team `jan`) | none         | 1Password `litellm-jan-laptop`      |

Budgets count LiteLLM's list prices. Only the Go model has one (set in its `info.extra`):
MiniMax M3.1 Flash and the M3 Pro record $0, so a budget caps Go spend alone, but a spent
budget blocks the whole key until it resets. That is why kritika has two keys. The master
key is for the operator and emergencies only.

## M3 Pro (`sisyphus`, `janpuc/mac-models`)

An always-on box behind llama-swap at `192.168.69.249`. It never unloads its default model
(Huihui Qwen3.8-27B), so a refused connection means something is wrong.

- One slot: requests are served one at a time, and llama-swap loads whichever model a request
  names. An image request unloads the LLM; the next chat waits about 10 s.
- About 9 tok/s writing and 70 tok/s prompt reading, so the aliases set 1800-3600 s timeouts
  instead of the router's 600 s, and none of them retries.
- Context: Huihui 32K (input ≤ 28672), Qwen3.8-27B 96K (input ≤ 86016), Qwen3.6-35B-A3B 128K
  (input ≤ 114688).
- Thinking is off server-side (`--reasoning-budget 0`).
