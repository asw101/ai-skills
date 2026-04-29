# Python component cookbook

`componentize-py` packages a Python application plus a CPython runtime into a single component. Components are large (typically 5–10 MB) because they embed CPython.

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
│   └── world.wit
└── app.py
```

### wit/world.wit

```wit
package local:my-component;

world my-component {
    export process: func(input: string) -> result<string, string>;
}
```

### Generate bindings

The canonical CLI specifies the WIT path with `-d` and the world with `-w`, **before** the subcommand.

```bash
# componentize-py has no --force flag; it errors if outputs already exist.
# Make the step idempotent by clearing previous outputs first.
rm -rf wit_world componentize_py_async_support \
       componentize_py_runtime.pyi componentize_py_types.py poll_loop.py
componentize-py -d wit -w my-component bindings .
```

> Without the `rm -rf`, re-running `bindings .` after editing your WIT trips `AssertionError: File exists (os error 17)`. Bake the cleanup into your `build-<name>-py` Justfile recipe.

This writes a `wit_world/` (or `<world_name>/`, depending on version) Python package with `__init__.py` and (if your WIT defines exports as an interface) one submodule per interface.

### app.py

If your world exports functions directly (the example above):

```python
import my_component

class MyComponent(my_component.MyComponent):
    def process(self, input: str) -> str:
        # Raise on error; the binding maps Python exceptions to the WIT result's err arm.
        return f"Processed: {input}"
```

If your world exports an interface (e.g. `export interface { ... }`), implement the class for the interface module instead (`my_component.exports.<interface>`).

### Build

```bash
componentize-py -d wit -w my-component componentize app -o ../bin/my-component.wasm
wasm-tools validate --features all ../bin/my-component.wasm
```

> `--features all` is required for components with `stream<>` / `future<>` / `async func` (i.e. all p3 components) and harmless for p2.

Useful flags:

- `--stub-wasi` — stub out WASI imports (use when the host doesn't provide them, e.g. for pure-library components).
- `-p <dir>` — additional module search path. Repeat to add several.

## Dependencies

`componentize-py` bundles pure-Python dependencies. C extensions are **not** supported under the current Python-on-Wasm runtime.

```bash
pip install --target ./deps requests-html  # pure Python only
componentize-py -d wit -w my-component componentize \
  -p . -p ./deps app -o ../bin/my-component.wasm
```

## Tips

- Always re-run `componentize-py … bindings .` after editing `wit/`.
- Keep the entry module flat — top-level imports must resolve at build time. Submodule imports done lazily inside functions can fail. (`componentize-py` issue #23.)
- Component size is dominated by CPython. `wasm-opt -Os` shaves a few hundred KB at most.
- `pyproject.toml` with `[tool.componentize-py]` is still supported but optional; explicit `-d`/`-w` flags are now canonical.
## WASI 0.3 RC

✅ Working today via `componentize-py` 0.23.0 (April 2026), which ships with [`cli-p3`](https://github.com/bytecodealliance/componentize-py/tree/main/examples/cli-p3), [`http-p3`](https://github.com/bytecodealliance/componentize-py/tree/main/examples/http-p3), and [`tcp-p3`](https://github.com/bytecodealliance/componentize-py/tree/main/examples/tcp-p3) examples pinned to `0.3.0-rc-2026-03-15`. After Rust, this is the most production-viable p3 path.

### Regenerated package layout

When your WIT imports `wasi:http@0.3.x`, the regenerated `wit_world/` looks like:

```
wit_world/
├── __init__.py                     # auto-generated future factory functions
├── client.py                       # wraps `await client.send(request)`
├── wasi_http_types.py              # Request, Response, Fields, Method_*, Scheme_*, ErrorCode, …
├── componentize_py_async_support/  # streams + futures runtime support
└── exports/
    └── api.py                      # your exported interface; methods are `async def`
```

The `__init__.py` exposes module-level helpers with mangled type names that you call to construct `future<>` writer/reader pairs:

```python
import wit_world

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

The `[1]` reader half is what `Request::new` / `Response::consume_body` want; the writer at `[0]` drops at end of scope and the future resolves with the default value.

### HTTP client pattern

```python
from wit_world import exports
from wit_world.imports import client
from wit_world.imports.wasi_http_types import (
    Request, Response, Fields, Method_Get, Scheme_Https, Ok,
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
        (body_rx, _trailers_rx) = Response.consume_body(response, _unit_future())

        chunks = bytearray()
        async with body_rx:
            while not body_rx.writer_dropped:
                chunks.extend(await body_rx.read(64 * 1024))
        return chunks.decode()
```

Subtle bits:

- The exported class subclasses `exports.<InterfaceName>` (or `wit_world.<World>` for inline exports). Methods declared `async def` map to `async func`.
- `body_rx` is a `ByteStreamReader`; use it as an `async with` context manager so resources release on exit.
- `body_rx.writer_dropped` is the EOF flag — the reader-side property. Loop until it's true.
- `await body_rx.read(N)` returns a `bytes` (possibly empty) of up to N bytes.

### Build & run

```bash
# wkg wit fetch is the same workflow as for Rust; regenerate bindings
# whenever you change wit/.
wkg wit fetch
rm -rf wit_world componentize_py_async_support componentize_py_runtime.pyi \
       componentize_py_types.py poll_loop.py
componentize-py -d wit -w my-component bindings .
componentize-py -d wit -w my-component componentize app -o ../bin/my-component.wasm
wasm-tools validate --features all ../bin/my-component.wasm

# Run (HTTP-importing components need -Shttp; see wasi-0.3.md):
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

## Troubleshooting

- **`componentize-py: command not found`** → `pip install componentize-py` (or `uv tool install componentize-py`).
- **`No module named 'wit_world'` / `'my_component'`** → run `componentize-py -d wit -w my-component bindings .` first.
- **`AssertionError: File exists (os error 17)`** when re-running `bindings .` → componentize-py has no `--force`. Clear previous outputs first: `rm -rf wit_world componentize_py_async_support componentize_py_runtime.pyi componentize_py_types.py poll_loop.py`.
- **`ImportError: ... C extension`** → swap for a pure-Python alternative; C extensions are not WASI-compatible.
- **`unable to find world`** → `-w` must match the `world <name>` in your `.wit` file exactly.
- **`wasm-tools validate`: `stream requires the component model async feature`** → re-run with `--features all`.
- **At runtime: `instance export 'fields' has the wrong type / resource implementation is missing`** → you forgot `-Shttp` alongside `-Sp3`. See [`wasi-0.3.md`](./wasi-0.3.md).
