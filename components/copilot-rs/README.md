# copilot-rs (Rust, WASI 0.3)

A WebAssembly component that exposes the **GitHub Copilot LLM API** —
`list-models` discovery and a **streaming** `chat` completion (plus a
`chat-buffered` variant for CLI / non-streaming hosts) — as a sibling
to `components/github-rs/`. Built on **WASI 0.3
(`0.3.0-rc-2026-03-15`)** so the chat export can return a real
`stream<string>` of token deltas.

`copilot-py/` is the Python sibling implementation; both export the same
`local:copilot/api` interface.

## Shared API surface (WIT)

```wit
package local:copilot;

interface api {
    record message      { role: string, content: string }
    record chat-options { model: option<string>, temperature: option<f64>, max-tokens: option<u32> }
    record model-info   { id: string, name: string, vendor: string, capabilities: list<string>, preview: bool }

    list-models: async func(gh-token: string) -> result<list<model-info>, string>;

    chat: async func(
        gh-token: string,
        messages: list<message>,
        options: option<chat-options>,
    ) -> result<stream<string>, string>;

    chat-buffered: async func(
        gh-token: string,
        messages: list<message>,
        options: option<chat-options>,
    ) -> result<list<string>, string>;
}

world copilot {
    import wasi:http/client@0.3.0-rc-2026-03-15;
    import wasi:http/types@0.3.0-rc-2026-03-15;
    export api;
}
```

The `gh-token` is sent as a `Bearer` to `api.githubcopilot.com`
directly — same path Copilot CLI / Codespaces / Actions take. Works
with the env-provided `GH_TOKEN` (including fine-grained PATs in
Copilot CLI), with Copilot-scoped classic PATs, and with OAuth tokens
from Copilot-aware apps. **No** `/copilot_internal/v2/token` exchange
is performed.

If `chat-options.model` is `none` the component falls back to
`gpt-4o-mini` — a sensible GA default. To pick a specific model, call
`list-models` first and pass the returned `id`.

The single `chat` export works for **every model vendor** that the Copilot
proxy serves (OpenAI, Anthropic, Google, …) because
`api.githubcopilot.com/chat/completions` is an OpenAI-compatibility proxy.
**Thinking / reasoning tokens are not surfaced through this endpoint** — see
the parent [`README.md`](../README.md#copilot-thinking-tokens) for which
endpoints expose them.

`chat` is the streaming primary; `chat-buffered` is the same wire call
with the SSE body collected into a `list<string>` and returned when the
stream ends. Use `chat` in production (incremental UI), `chat-buffered`
when you need a single result or want to test from `wasmtime run
--invoke` (which can't render `stream<string>` yet).

## Auth

```
POST/GET https://api.githubcopilot.com/{models, chat/completions}
  Authorization: Bearer <GH_TOKEN>
  Editor-Version: vscode/1.96.0
  Editor-Plugin-Version: copilot-chat/0.20.0
  Copilot-Integration-Id: vscode-chat
  OpenAI-Intent: conversation-panel
  User-Agent: copilot-wasm-rs/0.1
```

The required headers (`Editor-Version`, `Copilot-Integration-Id`, etc.)
are why a curl with just `Authorization: Bearer` may fail — Copilot
gates editor-equivalent traffic on these headers.

## Build

```bash
just build-copilot-rs       # cargo build --target wasm32-wasip2 (with -Wcomponent-model-async)
just build-copilot-py       # componentize-py componentize
just build-all-copilot      # both
just validate-copilot       # wasm-tools validate every bin/copilot-*.wasm
```

## Run (requires `GH_TOKEN` with Copilot access)

```bash
export GH_TOKEN="<your token>"

# Discover models the token can use
wasmtime run -Sp3 -Shttp -Wcomponent-model-async \
    --invoke 'list-models("'"$GH_TOKEN"'")' bin/copilot-rs.wasm

# Buffered chat (default model = gpt-4o-mini, prints a list<string>)
wasmtime run -Sp3 -Shttp -Wcomponent-model-async \
    --invoke 'chat-buffered("'"$GH_TOKEN"'", [{role: "user", content: "hello"}], none)' \
    bin/copilot-rs.wasm
# → ok(["Hello", ",", " how", " are", " you", "?"])

# Streaming chat (returns stream<string>; needs a host that consumes it —
# wasmtime --invoke doesn't render stream<> yet)
# wasmtime run -Sp3 -Shttp -Wcomponent-model-async \
#     --invoke 'chat("'"$GH_TOKEN"'", [{role: "user", content: "hello"}], none)' \
#     bin/copilot-rs.wasm

# Justfile shorthand (uses chat-buffered so output is renderable)
just test-copilot rs       # list-models + chat-buffered
just test-copilot py       # same on Python
just test-all-copilot      # rs then py
```

The `wasmtime run` invocation needs **all three** flags: `-Sp3` (enable WASI
0.3), `-Shttp` (allow outgoing HTTP to `api.githubcopilot.com`), and
`-Wcomponent-model-async` (enable async exports/streams).

## Implementation notes

- `wit_bindgen::generate!` 0.57.1 with
  `async: ["wasi:http/client@0.3.0-rc-2026-03-15#send"]`. The export's `chat`
  is `async fn` (auto-detected from the `async func` declaration in WIT).
- POST body is delivered as a `stream<u8>` to `Request::new`. We create the
  pair with `wit_stream::new::<u8>()` and spawn a writer task with
  `wit_bindgen::rt::async_support::spawn` (gated by the `async-spawn`
  Cargo feature) that calls `body_writer.write_all(json_bytes).await`.
- `chat()` returns `Ok(StreamReader<String>)` immediately after the response
  headers come back. A second spawned task pumps the SSE body into the
  `StreamWriter<String>`: read bytes, split on `\n\n`, strip `data: `,
  JSON-parse, push `choices[0].delta.content` to the writer. `[DONE]` or EOF
  closes the writer.
- `chat-buffered()` shares the request-builder helper with `chat()` but
  consumes the body inline — same parser, just collects to a `Vec<String>`
  and returns when `[DONE]` or EOF arrives.
- `wasm-tools validate --features all` is required because the component
  contains a `stream<>` type that the default validator feature set rejects.

## Limitations

- **No CI runtime tests.** Live calls require `GH_TOKEN` with Copilot
  access plus the `-Shttp -Sp3 -Wcomponent-model-async` runtime flags.
- **WASI 0.3 is a release candidate** (`0.3.0-rc-2026-03-15`). Same
  caveat as `github-rs`.
- **No JavaScript or Go implementation.** Same blockers as
  `github-{js,go}` — `jco` lacks a p3-shim and TinyGo has no `wasip3`
  target. v1 is rs+py only.
- **No tool calling, vision, or thinking tokens.** v1 only handles
  `messages` (text) and `delta.content` from `/chat/completions`. For
  thinking-token streaming, a v2 `chat-with-thinking` export would
  route to `/v1/messages` (Claude) or `/responses` (OpenAI reasoning)
  — see parent README.
