# Python component cookbook

`componentize-py` packages a Python application plus a CPython runtime
into a single component. Components are large (typically 5–10 MB) because
they embed CPython.

**WASI 0.3 RC is the default** for new Python components in this repo —
`componentize-py` 0.23 ships first-class p3 support, with `cli-p3`,
`http-p3`, and `tcp-p3` examples upstream. `async def` exports map to
`async func`; `stream<>` and `future<>` are surfaced through generated
factory functions and `componentize_py_async_support`. WASI 0.2 is
documented in the [fallback section](#targeting-wasi-02-only) below.

## Prerequisites

```bash
# Python 3.10+
pip install "componentize-py==0.23.0"
# or with uv
uv tool install componentize-py
```

## Scaffold

```bash
cd components
mkdir my-component && cd my-component
mkdir wit
```

### Project layout

```
my-component/
├── pyproject.toml      # optional but recommended
├── wit/
│   └── world.wit       # default: wasi:* @ 0.3.0-rc-2026-03-15
└── app.py
```

### wit/world.wit (p3, default)

```wit
package local:my-component;

interface api {
    /// Async export — maps to `async def get_thing(...)` in app.py.
    get-thing: async func(name: string) -> result<string, string>;
}

world my-component {
    import wasi:http/client@0.3.0-rc-2026-03-15;
    import wasi:http/types@0.3.0-rc-2026-03-15;
    export api;
}
```

Run `wkg wit fetch` to populate `wit/deps/` for the `wasi:http@0.3.x`
imports.

### Generate bindings

The canonical CLI specifies the WIT path with `-d` and the world with
`-w`, **before** the subcommand.

```bash
# componentize-py has no --force flag; it errors if outputs already exist.
# Make the step idempotent by clearing previous outputs first.
rm -rf wit_world componentize_py_async_support \
       componentize_py_runtime.pyi componentize_py_types.py poll_loop.py
componentize-py -d wit -w my-component bindings .
```

> Without the `rm -rf`, re-running `bindings .` after editing your WIT trips `AssertionError: File exists (os error 17)`. Bake the cleanup into your `build-<name>-py` Justfile recipe.

This writes a `wit_world/` Python package with `__init__.py` (and, when
your WIT defines exports as an interface, one submodule per interface).

### app.py (p3, with HTTP client)

When your WIT imports `wasi:http@0.3.x`, the regenerated `wit_world/`
looks like:

```
wit_world/
├── __init__.py                     # auto-generated future factory functions
├── client.py                       # wraps `await client.send(request)`
├── wasi_http_types.py              # Request, Response, Fields, Method_*, Scheme_*, ErrorCode, …
├── componentize_py_async_support/  # streams + futures runtime support
└── exports/
    └── api.py                      # your exported interface; methods are `async def`
```

The `__init__.py` exposes module-level helpers with mangled type names
that you call to construct `future<>` writer/reader pairs:

```python
import wit_world
from componentize_py_types import Ok

# Build a "trivially-Ok" future<result<option<fields>, error-code>> for trailers.
def _trailers_future():
    (_writer, reader) = wit_world.result_option_wasi_http_types_fields_wasi_http_types_error_code_future(
        lambda: Ok(None)
    )
    return reader

# Build a "trivially-Ok" future<result<_, error-code>> for body completion.
def _unit_future():
    (_writer, reader) = wit_world.result_unit_wasi_http_types_error_code_future(
        lambda: Ok(None)
    )
    return reader
```

The `[1]` reader half is what `Request::new` / `Response::consume_body`
want; the writer at `[0]` drops at end of scope and the future resolves
with the default value.

The exported class subclasses `exports.<InterfaceName>`. Methods declared
`async def` map to `async func`:

```python
from componentize_py_types import Err
from wit_world import exports
from wit_world.imports import client
from wit_world.imports.wasi_http_types import (
    Request, Response, Fields, Method_Get, Scheme_Https,
)

class Api(exports.Api):
    async def get_thing(self, name: str) -> str:
        headers = Fields()
        headers.append("user-agent", b"my-component")

        # Request.new returns (request, send-progress-future). For GET: no body.
        (request, _send_progress) = Request.new(headers, None, _trailers_future(), None)
        request.set_method(Method_Get())
        request.set_scheme(Scheme_Https())
        request.set_authority("api.example.com")
        request.set_path_with_query(f"/thing/{name}")

        response: Response = await client.send(request)
        status = response.get_status_code()
        if not (200 <= status < 300):
            # Errors raised as Err(message) become the result::err arm.
            # Raising plain RuntimeError instead would trap with `wasm unreachable`.
            raise Err(f"upstream returned HTTP {status}")

        (body_rx, _trailers_rx) = Response.consume_body(response, _unit_future())
        chunks = bytearray()
        async with body_rx:
            while not body_rx.writer_dropped:
                chunks.extend(await body_rx.read(64 * 1024))
        return chunks.decode()
```

Subtle bits:

- `body_rx` is a `ByteStreamReader`; use it as an `async with` context manager so resources release on exit.
- `body_rx.writer_dropped` is the EOF flag — the reader-side property. Loop until it's true.
- `await body_rx.read(N)` returns a `bytes` (possibly empty) of up to N bytes.
- Errors **must** be raised as `componentize_py_types.Err(message)` — that's the dataclass-as-Exception that the runtime translates into the `result::err(string)` variant. Raising plain `RuntimeError` instead causes a `wasm unreachable` trap inside the async-lift.

### Returning a `stream<T>` from an export

When your WIT contains `stream<string>`, `componentize-py` auto-generates
a `wit_world.string_stream() -> (StreamWriter[str], StreamReader[str])`
factory (and `byte_stream()` for `stream<u8>`). The canonical pattern:
synchronously create the (writer, reader) pair, **`asyncio.create_task`**
a producer coroutine, and return the reader.

```python
import asyncio
import wit_world

async def chat(self, ...) -> StreamReader[str]:
    body_rx = await _send_request(...)            # the upstream stream<u8>
    out_writer, out_reader = wit_world.string_stream()
    asyncio.create_task(_pump_sse(body_rx, out_writer))
    return out_reader
```

See `components/copilot-py/app.py` for a full implementation (SSE-pump
that decodes upstream `stream<u8>` into `stream<string>`).

### Build & run

```bash
wkg wit fetch                                  # only if you import wasi:* / registry packages
rm -rf wit_world componentize_py_async_support componentize_py_runtime.pyi \
       componentize_py_types.py poll_loop.py
componentize-py -d wit -w my-component bindings .
componentize-py -d wit -w my-component componentize app -o ../bin/my-component.wasm
wasm-tools validate --features all ../bin/my-component.wasm

# p3 components need -Sp3 -Wcomponent-model-async; add -Shttp for HTTP imports.
wasmtime run -Sp3 -Shttp -Wcomponent-model-async \
    --invoke 'get-thing("foo")' ../bin/my-component.wasm
```

> See [`wasi-0.3.md`](./wasi-0.3.md) for the full host-flag explanation.

A non-HTTP CLI world is even simpler:

```bash
componentize-py -d wit -w wasi:cli/command@0.3.0-rc-2026-03-15 \
    componentize app -o ../bin/my-component.wasm
wasmtime run -Sp3 -Wcomponent-model-async ../bin/my-component.wasm
```

Useful flags for `componentize-py componentize`:

- `--stub-wasi` — stub out WASI imports (use when the host doesn't
  provide them, e.g. for pure-library components).
- `-p <dir>` — additional module search path. Repeat to add several.

## Targeting WASI 0.2 only

For older runtimes (or library components that don't need async), point
the WIT at `0.2.x` instead. Everything else (binding generation, build,
Justfile recipe) is identical.

```wit
package local:my-component;

world my-component {
    export process: func(input: string) -> result<string, string>;
}
```

```python
import my_component

class MyComponent(my_component.MyComponent):
    def process(self, input: str) -> str:
        # Raise on error; the binding maps Python exceptions to the WIT
        # result's err arm.
        return f"Processed: {input}"
```

`wasm-tools validate --features all` is harmless for p2; `wasmtime run`
needs no `-Sp3` / `-Shttp` / `-W` flags.

## Dependencies

`componentize-py` bundles pure-Python dependencies. C extensions are
**not** supported under the current Python-on-Wasm runtime.

```bash
pip install --target ./deps requests-html  # pure Python only
componentize-py -d wit -w my-component componentize \
  -p . -p ./deps app -o ../bin/my-component.wasm
```

## Tips

- Always re-run `componentize-py … bindings .` after editing `wit/` (and `rm -rf` the previous outputs first).
- Keep the entry module flat — top-level imports must resolve at build time. Submodule imports done lazily inside functions can fail. (`componentize-py` issue #23.)
- Component size is dominated by CPython. `wasm-opt -Os` shaves a few hundred KB at most.
- `pyproject.toml` with `[tool.componentize-py]` is still supported but optional; explicit `-d`/`-w` flags are now canonical.

## Real examples in this repo

- **[`components/copilot-py/`](../../../../components/copilot-py/)** — **WASI 0.3** with `wasi:http@0.3`. Async `chat` export returning `stream<string>` via `asyncio.create_task` SSE-pump, plus a `chat-buffered` sibling for CLI testing.
- **[`components/github-py/`](../../../../components/github-py/)** — **WASI 0.3** with `wasi:http@0.3`. Two simple async exports.

## Troubleshooting

- **`componentize-py: command not found`** → `pip install componentize-py` (or `uv tool install componentize-py`).
- **`No module named 'wit_world'` / `'my_component'`** → run `componentize-py -d wit -w my-component bindings .` first.
- **`AssertionError: File exists (os error 17)`** when re-running `bindings .` → componentize-py has no `--force`. Clear previous outputs first: `rm -rf wit_world componentize_py_async_support componentize_py_runtime.pyi componentize_py_types.py poll_loop.py`.
- **`wasm unreachable` trap inside `[callback][async-lift]`** → an async export raised a plain Python exception instead of `componentize_py_types.Err(message)`. Re-raise as `Err`; the runtime maps it to the `result::err(string)` variant.
- **`ImportError: ... C extension`** → swap for a pure-Python alternative; C extensions are not WASI-compatible.
- **`unable to find world`** → `-w` must match the `world <name>` in your `.wit` file exactly.
- **`wasm-tools validate`: `stream requires the component model async feature`** → re-run with `--features all`.
- **At runtime: `instance export 'fields' has the wrong type / resource implementation is missing`** → you forgot `-Shttp` alongside `-Sp3`. See [`wasi-0.3.md`](./wasi-0.3.md).
