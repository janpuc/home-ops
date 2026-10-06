# litellm

## BC250 (living-room box, `janpuc/BC250` `ai/`)

A gaming machine first: it lends its GPU to AI only while nobody plays. A game launch
stops the AI service within 2 s, and it comes back 5 min after the game ends. A refused
connection is the normal state, not an incident. Always use `192.168.69.250` (Ethernet).
`.251` (Wi-Fi) or `bc250.internal` mean the box is at the desk, in use.

### Text: two aliases on the same `llama-server`

| Alias                         | While the box is busy              | Use for                                   |
| ----------------------------- | ---------------------------------- | ----------------------------------------- |
| `bc250/qwen3.6-35b-a3b`       | falls back to `minimax/MiniMax-M3` | ordinary chat                             |
| `bc250-local/qwen3.6-35b-a3b` | fails, never leaves the LAN        | infrastructure findings, private material |

- One slot: requests are served one at a time; don't expect parallelism.
- Budget at least 60 s for the first token after 10 idle minutes, because the model reloads (~21 s).
- 32768 context: keep input ≤ 24576 and output ≤ 8192, including reasoning. Reasoning is capped at 2048 server-side.
- Vendor sampling for coding: `temperature 0.6`, `top_p 0.95`, `top_k 20`.

### Images: A1111 API on the LAN only, not behind LiteLLM

`sd-server` (stable-diffusion.cpp) at `http://192.168.69.250:8091`, `POST /sdapi/v1/txt2img`,
web UI at `/`. **No authentication; never expose it beyond the LAN.** It is not the OpenAI
images API. SDXL WAI-illustrious v16.0 (anime). Reference recipe: 1024×1344, `Euler a`,
30 steps, CFG 7, clip skip 2. Optional detail pass: `enable_hr`,
`RealESRGAN_x4plus_anime_6B`, `hr_scale 1.5`, `hr_steps 12`, `denoising_strength 0.4`.
About 160 s per image (385 s with the detail pass), one at a time: use a client timeout of
1800 s. `ai/image/generate.py` in the BC250 repo is a working client.

Image mode and text mode exclude each other (one model fits in memory). Anything that
drives image jobs switches through the mode API, never over SSH:

```text
GET  http://192.168.69.250:8092/api/ai                        -> state
POST http://192.168.69.250:8092/api/ai  {"mode": "image"}     (or "text", "off")
Authorization: Bearer <BC250_AI_API_TOKEN>                     (1Password item bc250)
```

1. `POST image`, then poll `GET` until `ready` (about 5 s).
2. Run the job.
3. `POST text` to hand the GPU back to the LLM. It's ready in about 25 s; poll for `ready`.

A `409` means a game is running, because games always win. Back off for minutes, not
seconds. Keep jobs serialised: there is one GPU and one model at a time.
