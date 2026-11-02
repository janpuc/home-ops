# litellm

## M3 Pro (`sisyphus`, `janpuc/mac-models`)

An always-on worker for small delegated tasks: file reads, bash, edits. It never unloads its
model, so a refused connection means something is wrong. Address
`192.168.69.249`. Model: Qwen3.8-27B UD-IQ3_XXS, slow but strong.

| Alias                     | While the box is down              | Use for                                   |
| ------------------------- | ---------------------------------- | ----------------------------------------- |
| `m3pro/qwen3.8-27b`       | falls back to `minimax/MiniMax-M3` | ordinary worker tasks                     |
| `m3pro-local/qwen3.8-27b` | fails, never leaves the LAN        | infrastructure findings, private material |

- One slot: requests are served one at a time; bound orchestrator concurrency.
- 65536 context: keep input ≤ 57344 and output ≤ 8192.
- About 9 tok/s writing and 70 tok/s prompt reading: a fresh 57K-token prompt takes about 14 minutes, so both aliases set a 1800 s timeout instead of the router's 600 s.
- Thinking is off server-side (`--reasoning-budget 0`): at 9 tok/s it stalls tool turns for minutes.
