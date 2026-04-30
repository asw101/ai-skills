# WebAssembly Components

This directory contains WebAssembly components built using the Component Model and WASI Preview 2 / 3.

## Available Components

| Component | Language | Size | Description |
|-----------|----------|------|-------------|
| [csv-groupby](csv-groupby/README.md) | Rust | 147KB | SQL-like GROUP BY on CSV data (COUNT, SUM, AVG, MIN, MAX) |
| [stock-ticker](stock-ticker/README.md) | Go | 551KB | Stock price simulator for MSFT, AAPL, GOOGL, AMZN |
| [tech-ticker](tech-ticker/README.md) | Rust | 62KB | Health check and random string generation |
| [wasip3-demo](wasip3-demo/README.md) | Rust | 62KB | Minimal **WASI 0.3** example: sync + `async func` exports |
| github ([rs](github-rs/README.md) / [py](github-py/README.md) / [js](github-js/README.md) / [go](github-go/README.md)) | Rust + Python + JS + Go | 179KB / 19MB / 14MB / 1.2MB | GitHub API client (user / repo) — same WIT, four languages — **Rust + Python on WASI 0.3**, JS + Go still on 0.2; built with [wasm-build-multi](../.agents/skills/wasm-build-multi/SKILL.md) |
| copilot ([rs](copilot-rs/README.md) / [py](copilot-py/README.md)) | Rust + Python | 223KB / 21MB | GitHub Copilot LLM API client — `list-models` + **streaming** `chat` (returns `stream<string>` of token deltas) + buffered `chat-buffered` (returns `list<string>` for CLI testing). Sends `GH_TOKEN` directly as bearer to `api.githubcopilot.com` — same path Copilot CLI / Codespaces / Actions take. **WASI 0.3 only** (rs + py); see [Copilot thinking-token endpoints](#copilot-thinking-tokens) below |
| time-server | JavaScript | 11MB | Current UTC time (from `ghcr.io/microsoft/time-server-js`) |

## Directory Structure

```
components/
├── component-name/           # Source code directory
│   ├── src/                 # Source files
│   ├── wit/                 # WIT interface definitions
│   └── README.md            # Component documentation
└── bin/                     # Built .wasm artifacts
    └── component-name.wasm
```

## Further reading

See each component's `README.md` for usage examples. For build / run /
publish task → cookbook mapping see [`../docs/components.md`](../docs/components.md);
for skill-routing policy see [`../AGENTS.md`](../AGENTS.md).

## <a name="copilot-thinking-tokens"></a>Copilot thinking-token endpoints

The `copilot` component targets `POST /chat/completions` on
`api.githubcopilot.com` — universal across vendors (OpenAI / Anthropic /
Google), but the OpenAI-compatibility proxy **strips reasoning** even for
thinking-capable models. To see thinking tokens, use a different endpoint:

| Endpoint | Format | Thinking? | Models |
|---|---|---|---|
| `POST /chat/completions` | OpenAI-compat (universal) | ❌ stripped | All vendors — what `copilot` v1 uses |
| `POST /v1/messages` | Anthropic Messages | ✅ first-class | Claude reasoning models (3.7, sonnet-4, opus-4.x, opus-4.7) — request with `thinking: {"type":"adaptive"}` to get `thinking_delta` events |
| `POST /responses` | OpenAI Responses | ✅ first-class | OpenAI reasoning models (o1, o1-mini, o3, o3-mini, gpt-5.x thinking-mode) — emits `response.reasoning.delta` events |

A future `chat-with-thinking` export would route to `/v1/messages` or
`/responses` based on the model's vendor and return a richer
`stream<thinking-event>` where each event is tagged `thinking | answer |
tool-call | done`. Out of scope for v1.
