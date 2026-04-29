# JavaScript / TypeScript component cookbook

`jco` is the JS toolchain for components; `componentize-js` (which `jco componentize` invokes) embeds SpiderMonkey, so produced components are typically ~6–10 MB.

`jco` 1.x is stable. `componentize-js` itself still labels its componentization path experimental (subject to internal refactors), but the public CLI is reliable for production.

## Prerequisites

```bash
# Globally
npm install -g @bytecodealliance/jco@1.19.0 @bytecodealliance/componentize-js@0.20.0

# Or per-project (recommended for reproducibility)
npm install --save-dev @bytecodealliance/jco @bytecodealliance/componentize-js
```

## Scaffold

```bash
cd components
mkdir my-component && cd my-component
npm init -y
mkdir wit src
```

### Project layout

```
my-component/
├── package.json
├── wit/
│   └── world.wit
└── src/
    └── index.js
```

### package.json

```json
{
  "name": "my-component",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "build": "jco componentize src/index.js --wit wit -o ../my-component.wasm",
    "types": "jco types wit -o types"
  },
  "devDependencies": {
    "@bytecodealliance/componentize-js": "^0.20.0",
    "@bytecodealliance/jco": "^1.19.0"
  }
}
```

### wit/world.wit

```wit
package local:my-component;

world my-component {
  export process: func(input: string) -> result<string, string>;
}
```

### src/index.js

```javascript
export function process(input) {
  return { tag: 'ok', val: `Processed: ${input}` };
}
```

For a world that exports an interface, place each interface as a named export:

```javascript
export const cow = {
  say(text) { return `Hello, ${text}`; }
};
```

## Build

```bash
npm install
npm run build
wasm-tools validate ../my-component.wasm
```

If your component imports WASI interfaces beyond stdio, declare them with `-d`:

```bash
jco componentize src/index.js --wit wit \
  -d wasi:http/outgoing-handler@0.2.0 \
  -d wasi:cli/environment@0.2.0 \
  -o ../my-component.wasm
```

## TypeScript

```bash
# Generate .d.ts from your WIT
jco types wit -o types
```

Then:

```typescript
// src/index.ts
import type { MyComponent } from '../types/my-component.js';

export const process: MyComponent['process'] = (input) => ({ tag: 'ok', val: `Processed: ${input}` });
```

Compile with `tsc` to JS, then `jco componentize` the JS output. The TypeScript-direct path is via [`jco transpile`](https://bytecodealliance.github.io/jco/) but you cannot pass `.ts` to `componentize` directly today.

## Transpiling for host use

To call a component from Node or the browser:

```bash
jco transpile ../my-component.wasm -o transpiled
```

Produces `.js`, `.d.ts`, and `.core.wasm` files; import as ESM.

## Tips

- `"type": "module"` in `package.json` is required.
- Component size ~6–10 MB is dominated by SpiderMonkey; expected.
- `jco componentize --help` lists every flag (`--no-namespaced-aliases`, `--engine`, `--world-name`, etc.).
- AOT (Weval) optimization is currently disabled in `componentize-js`; size/perf are roughly fixed.
- **WASI 0.3 RC:** 🟡 Active development on jco `main` (futures, streams, p3-shim — last commit 2026-04-29) but **the released `jco@1.19.0` npm package contains no `p3`/`preview3`/`wasip3` code**. Track upstream until a 1.20-series release lands. See [`wasi-0.3.md`](./wasi-0.3.md).

## Troubleshooting

- **`jco: command not found`** → install globally or invoke via `npx jco`.
- **`Cannot find package '@bytecodealliance/componentize-js'`** → it's a peer of `jco`; install it explicitly.
- **`SyntaxError: Cannot use import statement outside a module`** → add `"type": "module"` to `package.json`.
- **Node 18 + `oxc-parser` errors** → `npm install oxc-parser --ignore-engines && npm install @oxc-parser/binding-linux-x64-gnu --ignore-engines` (per upstream README) or upgrade Node.
- **Imports not satisfied** → declare them with `-d <interface>` flags on `jco componentize`.
