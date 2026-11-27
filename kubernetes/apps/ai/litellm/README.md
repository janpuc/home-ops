# litellm

Fourteen models. Add a model back only when a client needs it. The three Gemini models are a reserve pool nothing uses yet.

| Model                             | Plan               | When it fails                                  | Used by                                       |
| --------------------------------- | ------------------ | ---------------------------------------------- | --------------------------------------------- |
| `minimax/MiniMax-M3.1-Flash`      | MiniMax            | limit error, no fallback                       | kritika reviews, Jan's OpenCode               |
| `openai/gpt-6.2-sol`              | OpenAI API         | billed per token, no fallback                  | a capped virtual key, none holds it now       |
| `anthropic/claude-sonnet-5-5`     | Anthropic API      | billed per token, no fallback                  | a capped virtual key, none holds it now       |
| `anthropic/claude-haiku-5-5`      | Anthropic API      | falls back to Go, then MiniMax M3.1 Flash      | polyglot (tutor eval), no memini (work data)  |
| `gemini/gemini-4-neon`            | Gemini API prepaid | stops when the prepaid balance is gone         | `gemini-test` key only, reserve pool          |
| `gemini/gemini-4-hydrogen`        | Gemini API prepaid | stops when the prepaid balance is gone         | `gemini-test` key only, reserve pool          |
| `gemini/gemini-3.5-flash-lite`    | Gemini API prepaid | stops when the prepaid balance is gone         | `gemini-test` key only, reserve pool          |
| `opencode-go/deepseek-v4.1-flash` | OpenCode Go        | falls back to MiniMax M3.1 Flash               | memini, kritika confidence, Open WebUI tasks  |
| `alibaba/qwen3.8-max`             | Alibaba Token Plan | limit or `data_inspection_failed`, no fallback | Jan's Pi and OpenCode, interactive only       |
| `alibaba/qwen3.8-flash`           | Alibaba Token Plan | limit or `data_inspection_failed`, no fallback | Jan's Pi and OpenCode, interactive only       |
| `alibaba/deepseek-v4.1-flash`     | Alibaba Token Plan | limit or `data_inspection_failed`, no fallback | Jan's Pi and OpenCode, interactive only       |
| `alibaba/qwen-image-3.0-pro`      | Alibaba Token Plan | limit or `data_inspection_failed`, no fallback | image generation on request, interactive only |
| `alibaba/wan2.7-image-pro`        | Alibaba Token Plan | limit or `data_inspection_failed`, no fallback | image generation on request, interactive only |
| `alibaba/wan3.0-video`            | Alibaba Token Plan | limit or `data_inspection_failed`, no fallback | video generation on request, interactive only |

MiniMax M3.1 Flash has no fallback on purpose: a Go-hosted MiniMax is billed per token, and
MiniMax's overflow once emptied the Go month. Keep `default_fallbacks` unset. The `alibaba/`
aliases are absent from every fallback list for the plan's sake (see below).

## Keys

Each client has its own virtual key (`LiteLLMVirtualKey`), so the dashboard's Per-Client row
shows who used what. The operator creates the keys through the admin API (`spec.apiAccess`)
and writes each one into a Secret in the client's namespace. The keys, teams and spend live
in the `litellm-postgres` CloudNativePG cluster (`../database`).

| Key alias     | Models                                     | Budget        | Secret                              |
| ------------- | ------------------------------------------ | ------------- | ----------------------------------- |
| `kritika`     | MiniMax M3.1 Flash                         | $20 / 7 days  | `kritika-system/kritika-litellm`    |
| `kritika-go`  | Go DeepSeek, MiniMax M3.1 Flash            | $10 / 7 days  | `kritika-system/kritika-litellm-go` |
| `memini`      | Haiku 5.5, Go DeepSeek, MiniMax M3.1 Flash | $15 / 7 days  | `ai/memini-litellm`                 |
| `open-webui`  | Go DeepSeek, MiniMax M3.1 Flash            | $5 / 7 days   | `ai/open-webui-litellm`             |
| `gemini-test` | the three Gemini models                    | $3 / 7 days   | `ai/gemini-test-litellm`            |
| `jan-laptop`  | all, plus the MCP servers (team `jan`)     | $20 / 30 days | 1Password `litellm-jan-laptop`      |

Budgets count LiteLLM's list prices (MiniMax M3.1 Flash 0.15 in, 0.60 out, 0.015 cache read
per million tokens, from platform.minimax.io). For MiniMax that is a notional number: the plan
is flat. The OpenAI and Anthropic API keys bill per token. The M3 Pro records $0. A spent
budget blocks the whole key until it resets. That is why kritika has two keys. The master key is for the
operator and emergencies only.

## Alibaba Token Plan

Model Studio's Token Plan, Personal Standard: 80,000 credits a month. It bills credits, not
tokens, so the aliases record $0 instead of LiteLLM's DashScope list prices (the Alibaba
console's Usage page is the only honest meter). Its terms cover interactive use in tools
only, no scripts and no batch calls: that is why only the `jan` team (Jan's `jan-laptop`
key, Pi and OpenCode) holds the `alibaba/` aliases, and why none of them is in a fallback
list. A plan limit or Alibaba's content filter (`data_inspection_failed`) is returned to the
caller as-is.

- Chat uses the `openai/` prefix on the plan's `compatible-mode/v1` base, so thinking stays
  a request field instead of a DashScope translation.
- The image models use `qwencloud/` and a **full** native endpoint as `apiBase`: at
  v1.109.1 the DashScope image config replaces a `/compatible-mode/v1` base with
  dashscope-intl and reads a bare host as a path-less URL
  (`litellm/llms/dashscope/common_utils.py`). Output is a signed URL that expires, never
  `b64_json`; aspect goes through `size` (`1024x1024`, or `1K`/`2K`/`4K` on wan2.7).
- The video model uses the bare origin: LiteLLM submits to
  `/api/v1/services/aigc/video-generation/video-synthesis` and polls `/api/v1/tasks/{id}`,
  and the task id lives 24 h. Resolution, ratio and duration belong in a `parameters`
  object; `duration: -1` is rejected.
- Image and video carry no retries, and no `alibaba/` model is health-checked: every one of
  those calls is a billed generation.
