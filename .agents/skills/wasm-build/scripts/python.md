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
componentize-py -d wit -w my-component bindings .
```

This writes a `my_component/` Python package with `__init__.py` and (if your WIT defines exports as an interface) one submodule per interface.

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
componentize-py -d wit -w my-component componentize app -o ../my-component.wasm
wasm-tools validate ../my-component.wasm
```

Useful flags:

- `--stub-wasi` — stub out WASI imports (use when the host doesn't provide them, e.g. for pure-library components).
- `-p <dir>` — additional module search path. Repeat to add several.

## Dependencies

`componentize-py` bundles pure-Python dependencies. C extensions are **not** supported under the current Python-on-Wasm runtime.

```bash
pip install --target ./deps requests-html  # pure Python only
componentize-py -d wit -w my-component componentize \
  -p . -p ./deps app -o ../my-component.wasm
```

## Tips

- Always re-run `componentize-py … bindings .` after editing `wit/`.
- Keep the entry module flat — top-level imports must resolve at build time. Submodule imports done lazily inside functions can fail. (`componentize-py` issue #23.)
- Component size is dominated by CPython. `wasm-opt -Os` shaves a few hundred KB at most.
- `pyproject.toml` with `[tool.componentize-py]` is still supported but optional; explicit `-d`/`-w` flags are now canonical.
- **WASI 0.3 RC:** ✅ Working today. `componentize-py` 0.23.0 ships with [`cli-p3`](https://github.com/bytecodealliance/componentize-py/tree/main/examples/cli-p3), [`http-p3`](https://github.com/bytecodealliance/componentize-py/tree/main/examples/http-p3), and [`tcp-p3`](https://github.com/bytecodealliance/componentize-py/tree/main/examples/tcp-p3) examples on `0.3.0-rc-2026-03-15`. Use `async def` for `async func` exports, and `componentize_py_async_support.streams` / `.futures` for `stream<>` / `future<>`. Run with `wasmtime run -Sp3 -Wcomponent-model-async`. See [`wasi-0.3.md`](./wasi-0.3.md).

  ```bash
  # 0.3 build & run (CLI world)
  componentize-py -d wit -w wasi:cli/command@0.3.0-rc-2026-03-15 \
    componentize app -o ../my-component.wasm
  wasmtime run -Sp3 -Wcomponent-model-async ../my-component.wasm
  ```

## Troubleshooting

- **`componentize-py: command not found`** → `pip install componentize-py` (or `uv tool install componentize-py`).
- **`No module named 'my_component'`** → run `componentize-py -d wit -w my-component bindings .` first.
- **`ImportError: ... C extension`** → swap for a pure-Python alternative; C extensions are not WASI-compatible.
- **`unable to find world`** → `-w` must match the `world <name>` in your `.wit` file exactly.
