# copilot-py (Python, WASI 0.3)

Python implementation of the `local:copilot/api` component, sibling to
[`copilot-rs/`](../copilot-rs/). Both export the same WIT interface
(`list-models`, streaming `chat`, buffered `chat-buffered`) and hit
`api.githubcopilot.com` directly with `GH_TOKEN` as bearer.

See [`../copilot-rs/README.md`](../copilot-rs/README.md) for the full
WIT contract, auth headers, and runtime invocation.

## Build

```bash
just build-copilot-py       # componentize-py componentize
just validate-copilot       # validates rs and py
```

The build first regenerates bindings (`componentize-py … bindings .`) into
a fresh `wit_world/`, then runs `componentize-py … componentize app -o
bin/copilot-py.wasm`. The Justfile recipe deletes any previous
`wit_world` / `componentize_py_*` directory tree first so the bindings
step is idempotent (componentize-py refuses to overwrite a non-empty
generated tree).

## Run

```bash
just test-copilot py        # list-models then chat-buffered with default model
# → ok(["Hello", "!", " How", " are", " you", "?"])
```

## Implementation notes

- `componentize-py 0.23.x` generates a `wit_world.string_stream() ->
  (StreamWriter[str], StreamReader[str])` factory because the WIT contains
  `stream<string>`. The `chat` export uses it to construct the (writer,
  reader) pair, then `asyncio.create_task(...)` spawns the SSE-pump
  coroutine and returns the reader.
- `chat_buffered` shares the request-builder helper (`_send_chat_request`)
  with `chat`, then iterates the body stream inline and returns a
  `list[str]`.
- Errors in the synchronous path are raised as `componentize_py_types.Err(
  message)` — that is the dataclass-as-Exception that the runtime knows
  to translate into the `result::err(string)` variant. Raising plain
  `RuntimeError` instead would trap with `wasm unreachable`.
- Body bytes for the POST are delivered through a `byte_stream()` writer
  task that calls `body_writer.write_all(json_bytes)` then drops the
  writer.
- SSE parsing uses a `bytearray` buffer; on each `\n\n` it carves the
  event, decodes UTF-8, strips the `data:` prefix, JSON-parses, and pushes
  `choices[0].delta.content` (when non-empty) into the output writer with
  `await out_writer.write([content])`. `[DONE]` or `body_rx.writer_dropped`
  closes the loop.

## Limitations

Same as `copilot-rs/`: no tool/vision/thinking-token support; live calls
require `GH_TOKEN` with Copilot access plus the `-Sp3 -Shttp
-Wcomponent-model-async` wasmtime flags.
