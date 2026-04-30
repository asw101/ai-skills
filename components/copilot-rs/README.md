# copilot-rs (Rust, WASI 0.3)

A WebAssembly component that exposes the **GitHub Copilot LLM API** —
`list-models` discovery and a **streaming** `chat` completion — as a sibling
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
}

world copilot {
    import wasi:http/client@0.3.0-rc-2026-03-15;
    import wasi:http/types@0.3.0-rc-2026-03-15;
    export api;
}
```

The `gh-token` parameter is a GitHub PAT (or OAuth/app token) that has
**Copilot access** on the user's account. It is exchanged internally by the
component for a short-lived Copilot session token (see "Auth flow" below).

If `chat-options.model` is `none` the component falls back to
`gpt-4o-mini` — a sensible GA default. To pick a specific model, call
`list-models` first and pass the returned `id`.

The single `chat` export works for **every model vendor** that the Copilot
proxy serves (OpenAI, Anthropic, Google, …) because
`api.githubcopilot.com/chat/completions` is an OpenAI-compatibility proxy.
**Thinking / reasoning tokens are not surfaced through this endpoint** — see
the parent [`README.md`](../README.md#copilot-thinking-tokens) for which
endpoints expose them.

## Auth flow (the two-step dance)

The Copilot LLM API does not accept a raw `GH_TOKEN`. Both exports do:

1. **`GET https://api.github.com/copilot_internal/v2/token`**
   - `Authorization: token <GH_TOKEN>`
   - `User-Agent`, `Editor-Version`, `Accept: application/json`
   - Response: `{ "token": "<copilot-session-token>", "expires_at": <unix>, ... }`

2. **`GET /models` or `POST /chat/completions` on `api.githubcopilot.com`**
   - `Authorization: Bearer <copilot-session-token>`
   - `Editor-Version: vscode/1.96.0`
   - `Editor-Plugin-Version: copilot-chat/0.20.0`
   - `Copilot-Integration-Id: vscode-chat`
   - `OpenAI-Intent: conversation-panel`

Tokens are short-lived (~30 minutes). v1 is **stateless** — it does the
exchange on every call. A future revision could cache the session token
inside the component until `expires_at`.

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

# Stream a chat (default model = gpt-4o-mini)
wasmtime run -Sp3 -Shttp -Wcomponent-model-async \
    --invoke 'chat("'"$GH_TOKEN"'", [{role: "user", content: "hello"}], none)' \
    bin/copilot-rs.wasm

# Justfile shorthand
just test-copilot rs       # both calls
just test-copilot py       # same on Python
just test-all-copilot      # rs then py
```

The `wasmtime run` invocation needs **all three** flags: `-Sp3` (enable WASI
0.3), `-Shttp` (allow outgoing HTTP — chat hits both `api.github.com` and
`api.githubcopilot.com`), and `-Wcomponent-model-async` (enable async
exports/streams).

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
- The spawned tasks live for the duration of the export's component-model
  async task, which stays alive while the host holds the returned reader.
  Pattern borrowed from `dicej/hello-wasip3-http`.
- `wasm-tools validate --features all` is required because the component
  contains a `stream<>` type that the default validator feature set rejects.

## Errors observed during development

- **HTTP 403 from `/copilot_internal/v2/token`** — the supplied `GH_TOKEN`
  is a fine-grained PAT (`github_pat_…`). Fine-grained PATs do **not** have
  access to Copilot's internal token-exchange endpoint. Use a classic PAT
  (`ghp_…`) issued by an account with active Copilot subscription, or an
  OAuth token issued by a Copilot-aware GitHub App (e.g. the VS Code
  Copilot extension). The component itself handles the 403 cleanly and
  surfaces the GitHub error body verbatim through the `result::err(string)`
  variant.

## Limitations

- **No CI runtime tests.** Live calls require `GH_TOKEN` with Copilot access
  plus the `-Shttp -Sp3 -Wcomponent-model-async` runtime flags.
- **WASI 0.3 is a release candidate** (`0.3.0-rc-2026-03-15`). Same caveat
  as `github-rs`.
- **No JavaScript or Go implementation.** Same blockers as
  `github-{js,go}` — `jco` lacks a p3-shim and TinyGo has no `wasip3`
  target. v1 is rs+py only.
- **No token caching.** Stateless; one exchange per call (~50ms overhead
  on cold path). Could cache `{token, expires_at}` in component state.
- **No tool calling, vision, or thinking tokens.** v1 only handles
  `messages` (text) and `delta.content` from `/chat/completions`. For
  thinking-token streaming, a v2 `chat-with-thinking` export would route
  to `/v1/messages` (Claude) or `/responses` (OpenAI reasoning) — see
  parent README.
